import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/vanix_colors.dart';
import '../../core/models/models.dart';
import '../downloads/providers/download_provider.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String contentId;

  const VideoPlayerScreen({
    super.key,
    required this.contentId,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  File? _tempPlaybackFile;
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;
  String _errorMessage = '';

  // Player overlay states
  bool _showSkipIntro = false;
  bool _showNextEpisode = false;
  String _selectedQuality = '1080p';
  String _selectedSubtitle = 'Off';

  // Timers
  Timer? _progressSyncTimer;

  // Mock settings options
  final List<String> _qualities = ['Auto', '4K (2160p)', 'Full HD (1080p)', 'HD (720p)', 'SD (480p)'];
  final List<String> _subtitles = ['Off', 'English', 'Spanish', 'Hindi', 'Japanese'];

  // Mock HLS / MP4 URLs
  // Using a stable, public Big Buck Bunny MP4 stream for reliable playback
  static const String _defaultVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  @override
  void initState() {
    super.initState();
    // 1. Force landscape orientation for immersive playback
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initializePlayer();
    _startProgressSync();
  }

  Future<String> _prepareLocalVideo(String originalPath) async {
    try {
      final file = File(originalPath);
      if (!await file.exists()) return originalPath;

      final bytes = await file.readAsBytes();
      if (bytes.length < 1024) return originalPath;

      final mutableBytes = List<int>.from(bytes);
      final len = mutableBytes.length < 1024 ? mutableBytes.length : 1024;
      for (var i = 0; i < len; i++) {
        mutableBytes[i] = mutableBytes[i] ^ 0x5A;
      }

      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/temp_playback_${DateTime.now().millisecondsSinceEpoch}.mp4');
      await tempFile.writeAsBytes(mutableBytes);

      _tempPlaybackFile = tempFile;
      debugPrint('[VideoPlayerScreen] Prepared temporary decrypted file: ${tempFile.path}');
      return tempFile.path;
    } catch (e) {
      debugPrint('[VideoPlayerScreen] Failed to prepare local video: $e');
      return originalPath;
    }
  }

  Future<void> _initializePlayer() async {
    try {
      final downloads = ref.read(downloadProvider);
      final downloadItem = downloads.firstWhere(
        (item) => item.id == widget.contentId && item.status == 'COMPLETED',
        orElse: () => const DownloadItem(id: '', title: '', videoUrl: ''),
      );

      String? playUrl;
      if (downloadItem.id.isNotEmpty && downloadItem.localPath != null) {
        final localPath = downloadItem.localPath!;
        playUrl = await _prepareLocalVideo(localPath);
      }

      if (playUrl != null) {
        _videoPlayerController = VideoPlayerController.file(
          File(playUrl),
        );
      } else {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(_defaultVideoUrl),
        );
      }

      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        autoPlay: true,
        looping: false,
        allowedScreenSleep: false,
        showControls: true,
        isLive: false,
        // Customized Material controls themed for VANIX
        materialProgressColors: ChewieProgressColors(
          playedColor: VanixColors.vanixRed,
          handleColor: VanixColors.vanixRed,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: VanixColors.vanixRed),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: VanixColors.vanixRed, size: 42),
                const SizedBox(height: 10),
                Text(
                  _errorMessage.isNotEmpty ? _errorMessage : 'Error playing video',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      // Listen to position changes for overlay triggers
      _videoPlayerController.addListener(_playerListener);
      setState(() {});
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _playerListener() {
    if (!mounted) return;
    final position = _videoPlayerController.value.position;
    final duration = _videoPlayerController.value.duration;

    // Show Skip Intro between 5 and 20 seconds
    final shouldShowSkipIntro = position.inSeconds >= 5 && position.inSeconds <= 20;
    if (shouldShowSkipIntro != _showSkipIntro) {
      setState(() {
        _showSkipIntro = shouldShowSkipIntro;
      });
    }

    // Show Next Episode button when video is past 90% and it's a series
    final isSeries = widget.contentId.contains('s1e');
    final isNearEnd = duration.inSeconds > 0 && 
                      (position.inSeconds / duration.inSeconds) >= 0.90;
    final shouldShowNextEpisode = isSeries && isNearEnd;
    if (shouldShowNextEpisode != _showNextEpisode) {
      setState(() {
        _showNextEpisode = shouldShowNextEpisode;
      });
    }
  }

  void _startProgressSync() {
    // Sync progress to backend API mock every 15 seconds
    _progressSyncTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_videoPlayerController.value.isInitialized) {
        final currentSec = _videoPlayerController.value.position.inSeconds;
        debugPrint('[VANIX API] POST /api/v1/streaming/progress - contentId: ${widget.contentId}, position: ${currentSec}s');
      }
    });
  }

  void _skipIntro() {
    if (_videoPlayerController.value.isInitialized) {
      _videoPlayerController.seekTo(const Duration(seconds: 25));
      setState(() {
        _showSkipIntro = false;
      });
    }
  }

  void _playNextEpisode() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing Next Episode...', style: GoogleFonts.poppins()),
        backgroundColor: VanixColors.vanixRed,
      ),
    );
    // Reload player with next episode ID
    context.pushReplacement('/player/${widget.contentId.replaceAll('e5', 'e6')}');
  }

  void _showQualitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: VanixColors.bgElevated,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Video Quality',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const Divider(),
              ..._qualities.map((q) => ListTile(
                title: Text(
                  q,
                  style: GoogleFonts.poppins(
                    color: _selectedQuality == q ? VanixColors.vanixRed : Colors.white,
                    fontWeight: _selectedQuality == q ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: _selectedQuality == q ? const Icon(Icons.check, color: VanixColors.vanixRed) : null,
                onTap: () {
                  setState(() {
                    _selectedQuality = q;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Quality changed to $q')),
                  );
                },
              )),
            ],
          ),
        );
      },
    );
  }

  void _showSubtitleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: VanixColors.bgElevated,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Subtitles / Audio',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const Divider(),
              ..._subtitles.map((sub) => ListTile(
                title: Text(
                  sub,
                  style: GoogleFonts.poppins(
                    color: _selectedSubtitle == sub ? VanixColors.vanixRed : Colors.white,
                    fontWeight: _selectedSubtitle == sub ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: _selectedSubtitle == sub ? const Icon(Icons.check, color: VanixColors.vanixRed) : null,
                onTap: () {
                  setState(() {
                    _selectedSubtitle = sub;
                  });
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    // 2. Revert back to portrait when leaving the player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);

    _progressSyncTimer?.cancel();
    _videoPlayerController.removeListener(_playerListener);
    _videoPlayerController.dispose();
    _chewieController?.dispose();

    if (_tempPlaybackFile != null && _tempPlaybackFile!.existsSync()) {
      try {
        _tempPlaybackFile!.deleteSync();
        debugPrint('[VideoPlayerScreen] Deleted temporary decrypted playback file: ${_tempPlaybackFile!.path}');
      } catch (e) {
        debugPrint('[VideoPlayerScreen] Failed to clean up temporary video file: $e');
      }
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPlayer = _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Immersive Video Frame
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: VanixColors.vanixRed, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to initialize media player',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _initializePlayer(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (!hasPlayer)
            const Center(
              child: CircularProgressIndicator(color: VanixColors.vanixRed),
            )
          else
            Center(
              child: AspectRatio(
                aspectRatio: _videoPlayerController.value.aspectRatio,
                child: Chewie(controller: _chewieController!),
              ),
            ),

          // 2. Floating Overlays (Skip Intro / Next Episode)
          if (hasPlayer) ...[
            // Skip Intro overlay button
            if (_showSkipIntro)
              Positioned(
                bottom: 80,
                right: 24,
                child: GestureDetector(
                  onTap: _skipIntro,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: VanixColors.borderColor, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.skip_next_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'SKIP INTRO',
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Next Episode overlay button
            if (_showNextEpisode)
              Positioned(
                bottom: 80,
                right: 24,
                child: GestureDetector(
                  onTap: _playNextEpisode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: VanixColors.vanixRed.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: VanixColors.vanixRed.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'NEXT EPISODE',
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Settings gears and options overlay (positioned top right)
            Positioned(
              top: 20,
              right: 20,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.subtitles_rounded, color: Colors.white70, size: 24),
                    onPressed: _showSubtitleSelector,
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 24),
                    onPressed: _showQualitySelector,
                  ),
                ],
              ),
            ),
          ],

          // 3. Immersive Back Button overlay
          Positioned(
            top: 20,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  // Exit landscape mode and pop
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                  ]);
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
                  context.pop();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
