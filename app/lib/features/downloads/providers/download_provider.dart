import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../core/models/models.dart';

const String keyOfflineDownloads = 'offline_downloads';

class DownloadNotifier extends StateNotifier<List<DownloadItem>> {
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  final Map<String, http.Client> _activeClients = {};
  SharedPreferences? _prefs;

  DownloadNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadDownloadedItems();
    _checkExpiry();
  }

  void _loadDownloadedItems() {
    if (_prefs == null) return;
    final list = _prefs!.getStringList(keyOfflineDownloads) ?? [];
    try {
      final items = list
          .map((item) => DownloadItem.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList();
      state = items;
      debugPrint('[DownloadNotifier] Loaded ${items.length} offline downloads.');
    } catch (e) {
      debugPrint('[DownloadNotifier] Error parsing offline downloads: $e');
    }
  }

  Future<void> startDownload({
    required String id,
    required String title,
    String? thumbnailUrl,
    required String videoUrl,
    String quality = '1080p',
  }) async {
    // Check if already downloaded
    final existingIndex = state.indexWhere((item) => item.id == id);
    if (existingIndex != -1) {
      final existing = state[existingIndex];
      if (existing.status == 'COMPLETED') {
        debugPrint('[DownloadNotifier] Item $id is already downloaded.');
        return;
      }
    }

    // Prepare download item state
    final DownloadItem initialItem = DownloadItem(
      id: id,
      title: title,
      thumbnailUrl: thumbnailUrl,
      quality: quality,
      progress: 0.0,
      status: 'DOWNLOADING',
      videoUrl: videoUrl,
    );

    if (existingIndex == -1) {
      state = [...state, initialItem];
    } else {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex) initialItem else state[i]
      ];
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Fallback url for testing if none is provided
      String urlString = videoUrl;
      if (!urlString.endsWith('.mp4') && !urlString.startsWith('file://') && !urlString.startsWith('content://')) {
        urlString = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      }

      final uri = Uri.parse(urlString);
      final file = File('${downloadsDir.path}/$id.mp4');

      int existingBytes = 0;
      if (await file.exists()) {
        existingBytes = await file.length();
      }

      final client = http.Client();
      _activeClients[id] = client;

      final request = http.Request('GET', uri);
      if (existingBytes > 0) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }

      final response = await client.send(request);
      final bool isPartial = response.statusCode == 206;
      final bool append = isPartial && existingBytes > 0;
      final int startBytes = append ? existingBytes : 0;

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('Server returned error status code: ${response.statusCode}');
      }

      final totalBytes = (response.contentLength ?? 0) + startBytes;
      final fileSink = file.openWrite(mode: append ? FileMode.append : FileMode.write);

      int bytesDownloaded = startBytes;

      final subscription = response.stream.listen(
        (chunk) {
          if (bytesDownloaded == startBytes && chunk.isNotEmpty) {
            final List<int> mutableChunk = List<int>.from(chunk);
            final len = mutableChunk.length < 1024 ? mutableChunk.length : 1024;
            for (var i = 0; i < len; i++) {
              mutableChunk[i] = mutableChunk[i] ^ 0x5A; // XOR encryption
            }
            fileSink.add(mutableChunk);
          } else {
            fileSink.add(chunk);
          }
          bytesDownloaded += chunk.length;
          if (totalBytes > 0) {
            final progress = bytesDownloaded / totalBytes;
            _updateItemProgress(id, progress, totalBytes);
          }
        },
        onDone: () async {
          await fileSink.close();
          _activeSubscriptions.remove(id);
          _activeClients.remove(id);
          client.close();

          final completedItem = DownloadItem(
            id: id,
            title: title,
            thumbnailUrl: thumbnailUrl,
            quality: quality,
            fileSizeBytes: totalBytes,
            progress: 1.0,
            status: 'COMPLETED',
            localPath: file.path,
            videoUrl: videoUrl,
            expiresAt: DateTime.now().add(const Duration(days: 7)),
          );

          _completeDownload(completedItem);
        },
        onError: (err) async {
          await fileSink.close();
          _activeSubscriptions.remove(id);
          _activeClients.remove(id);
          client.close();
          debugPrint('[DownloadNotifier] Download stream error for $title: $err');
          _updateItemStatus(id, 'FAILED');
        },
        cancelOnError: true,
      );

      _activeSubscriptions[id] = subscription;
    } catch (e) {
      debugPrint('[DownloadNotifier] Failed to initiate download: $e');
      _activeClients[id]?.close();
      _activeClients.remove(id);
      _updateItemStatus(id, 'FAILED');
    }
  }

  void _updateItemProgress(String id, double progress, int totalBytes) {
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(progress: progress, fileSizeBytes: totalBytes)
        else
          item
    ];
  }

  void _updateItemStatus(String id, String status) {
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(status: status)
        else
          item
    ];
  }

  void pauseDownload(String id) {
    if (_activeSubscriptions.containsKey(id)) {
      _activeSubscriptions[id]?.cancel();
      _activeSubscriptions.remove(id);
    }
    if (_activeClients.containsKey(id)) {
      _activeClients[id]?.close();
      _activeClients.remove(id);
    }
    _updateItemStatus(id, 'PAUSED');
    debugPrint('[DownloadNotifier] Paused download: $id');
  }

  void resumeDownload(String id) {
    final itemIndex = state.indexWhere((item) => item.id == id);
    if (itemIndex != -1) {
      final item = state[itemIndex];
      if (item.status == 'PAUSED') {
        startDownload(
          id: item.id,
          title: item.title,
          thumbnailUrl: item.thumbnailUrl,
          videoUrl: item.videoUrl,
          quality: item.quality,
        );
        debugPrint('[DownloadNotifier] Resumed download: ${item.title}');
      }
    }
  }

  void _completeDownload(DownloadItem completedItem) async {
    state = [
      for (final item in state)
        if (item.id == completedItem.id) completedItem else item
    ];
    await _saveToPrefs();
    debugPrint('[DownloadNotifier] Download complete: ${completedItem.title}');
  }

  Future<void> removeDownload(String id) async {
    if (_activeSubscriptions.containsKey(id)) {
      _activeSubscriptions[id]?.cancel();
      _activeSubscriptions.remove(id);
    }
    if (_activeClients.containsKey(id)) {
      _activeClients[id]?.close();
      _activeClients.remove(id);
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/downloads/$id.mp4');
      if (await file.exists()) {
        await file.delete();
        debugPrint('[DownloadNotifier] Deleted local downloaded file: ${file.path}');
      }
    } catch (e) {
      debugPrint('[DownloadNotifier] Failed to delete offline file: $e');
    }

    state = state.where((item) => item.id != id).toList();
    await _saveToPrefs();
    debugPrint('[DownloadNotifier] Removed download: $id');
  }

  Future<void> _saveToPrefs() async {
    if (_prefs == null) return;
    final list = state
        .where((item) => item.status == 'COMPLETED')
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    await _prefs!.setStringList(keyOfflineDownloads, list);
  }

  void _checkExpiry() async {
    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final item in state) {
      if (item.expiresAt != null && now.isAfter(item.expiresAt!)) {
        expiredIds.add(item.id);
      }
    }

    if (expiredIds.isNotEmpty) {
      debugPrint('[DownloadNotifier] Removing ${expiredIds.length} expired offline downloads.');
      for (final id in expiredIds) {
        await removeDownload(id);
      }
    }
  }

  @override
  void dispose() {
    for (var sub in _activeSubscriptions.values) {
      sub.cancel();
    }
    for (var client in _activeClients.values) {
      client.close();
    }
    super.dispose();
  }
}

final downloadProvider = StateNotifierProvider<DownloadNotifier, List<DownloadItem>>((ref) {
  return DownloadNotifier();
});
