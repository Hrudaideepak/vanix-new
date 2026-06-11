/// VANIX — Core Data Models
/// Matches the backend Prisma schema responses.

class User {
  final String id;
  final String? email;
  final String? phone;
  final String? name;
  final String? avatarUrl;
  final bool isVerified;
  final List<Profile> profiles;
  final Subscription? activeSubscription;

  const User({
    required this.id,
    this.email,
    this.phone,
    this.name,
    this.avatarUrl,
    this.isVerified = false,
    this.profiles = const [],
    this.activeSubscription,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      profiles: (json['profiles'] as List<dynamic>?)
              ?.map((p) => Profile.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      activeSubscription: json['subscriptions'] != null &&
              (json['subscriptions'] as List).isNotEmpty
          ? Subscription.fromJson(
              (json['subscriptions'] as List).first as Map<String, dynamic>)
          : null,
    );
  }
}

class Profile {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isKids;
  final String maturityRating;
  final String language;

  const Profile({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isKids = false,
    this.maturityRating = 'U',
    this.language = 'en',
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      isKids: json['isKids'] as bool? ?? false,
      maturityRating: json['maturityRating'] as String? ?? 'U',
      language: json['language'] as String? ?? 'en',
    );
  }
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;

  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }
}

class Movie {
  final String id;
  final String title;
  final String slug;
  final String? description;
  final String? synopsis;
  final DateTime? releaseDate;
  final int? runtime;
  final String? maturityRating;
  final String language;
  final String? posterUrl;
  final String? backdropUrl;
  final String? trailerUrl;
  final String? videoUrl;
  final String? hlsUrl;
  final List<String> quality;
  final List<String> audioTracks;
  final List<String> subtitleTracks;
  final double avgRating;
  final int totalRatings;
  final int viewCount;
  final bool isFeatured;
  final bool isOriginal;
  final int? skipIntroStart;
  final int? skipIntroEnd;
  final List<Genre> genres;
  final List<CastInfo> cast;
  final List<CrewInfo> crew;

  const Movie({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    this.synopsis,
    this.releaseDate,
    this.runtime,
    this.maturityRating,
    this.language = 'en',
    this.posterUrl,
    this.backdropUrl,
    this.trailerUrl,
    this.videoUrl,
    this.hlsUrl,
    this.quality = const ['720p', '1080p'],
    this.audioTracks = const ['en'],
    this.subtitleTracks = const [],
    this.avgRating = 0,
    this.totalRatings = 0,
    this.viewCount = 0,
    this.isFeatured = false,
    this.isOriginal = false,
    this.skipIntroStart,
    this.skipIntroEnd,
    this.genres = const [],
    this.cast = const [],
    this.crew = const [],
  });

  String get year => releaseDate?.year.toString() ?? '';
  String get runtimeFormatted {
    if (runtime == null) return '';
    final h = runtime! ~/ 60;
    final m = runtime! % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      synopsis: json['synopsis'] as String?,
      releaseDate: json['releaseDate'] != null
          ? DateTime.tryParse(json['releaseDate'] as String)
          : null,
      runtime: json['runtime'] as int?,
      maturityRating: json['maturityRating'] as String?,
      language: json['language'] as String? ?? 'en',
      posterUrl: json['posterUrl'] as String?,
      backdropUrl: json['backdropUrl'] as String?,
      trailerUrl: json['trailerUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      hlsUrl: json['hlsUrl'] as String?,
      quality: (json['quality'] as List<dynamic>?)?.cast<String>() ??
          ['720p', '1080p'],
      audioTracks:
          (json['audioTracks'] as List<dynamic>?)?.cast<String>() ?? ['en'],
      subtitleTracks:
          (json['subtitleTracks'] as List<dynamic>?)?.cast<String>() ?? [],
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0,
      totalRatings: json['totalRatings'] as int? ?? 0,
      viewCount: json['viewCount'] as int? ?? 0,
      isFeatured: json['isFeatured'] as bool? ?? false,
      isOriginal: json['isOriginal'] as bool? ?? false,
      skipIntroStart: json['skipIntroStart'] as int?,
      skipIntroEnd: json['skipIntroEnd'] as int?,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((g) => Genre.fromJson(
                  (g['genre'] ?? g) as Map<String, dynamic>))
              .toList() ??
          [],
      cast: (json['castMembers'] as List<dynamic>?)
              ?.map((c) => CastInfo.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      crew: (json['crewMembers'] as List<dynamic>?)
              ?.map((c) => CrewInfo.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Series {
  final String id;
  final String title;
  final String slug;
  final String? description;
  final String? synopsis;
  final String? posterUrl;
  final String? backdropUrl;
  final String? trailerUrl;
  final int totalSeasons;
  final int totalEpisodes;
  final double avgRating;
  final int totalRatings;
  final int viewCount;
  final bool isFeatured;
  final bool isOriginal;
  final String? maturityRating;
  final List<Genre> genres;
  final List<Season> seasons;

  const Series({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    this.synopsis,
    this.posterUrl,
    this.backdropUrl,
    this.trailerUrl,
    this.totalSeasons = 0,
    this.totalEpisodes = 0,
    this.avgRating = 0,
    this.totalRatings = 0,
    this.viewCount = 0,
    this.isFeatured = false,
    this.isOriginal = false,
    this.maturityRating,
    this.genres = const [],
    this.seasons = const [],
  });

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: json['id'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      synopsis: json['synopsis'] as String?,
      posterUrl: json['posterUrl'] as String?,
      backdropUrl: json['backdropUrl'] as String?,
      trailerUrl: json['trailerUrl'] as String?,
      totalSeasons: json['totalSeasons'] as int? ?? 0,
      totalEpisodes: json['totalEpisodes'] as int? ?? 0,
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0,
      totalRatings: json['totalRatings'] as int? ?? 0,
      viewCount: json['viewCount'] as int? ?? 0,
      isFeatured: json['isFeatured'] as bool? ?? false,
      isOriginal: json['isOriginal'] as bool? ?? false,
      maturityRating: json['maturityRating'] as String?,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((g) => Genre.fromJson(
                  (g['genre'] ?? g) as Map<String, dynamic>))
              .toList() ??
          [],
      seasons: (json['seasons'] as List<dynamic>?)
              ?.map((s) => Season.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Season {
  final String id;
  final int seasonNumber;
  final String? title;
  final String? description;
  final String? posterUrl;
  final int totalEpisodes;
  final List<Episode> episodes;

  const Season({
    required this.id,
    required this.seasonNumber,
    this.title,
    this.description,
    this.posterUrl,
    this.totalEpisodes = 0,
    this.episodes = const [],
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'] as String,
      seasonNumber: json['seasonNumber'] as int,
      title: json['title'] as String?,
      description: json['description'] as String?,
      posterUrl: json['posterUrl'] as String?,
      totalEpisodes: json['totalEpisodes'] as int? ?? 0,
      episodes: (json['episodes'] as List<dynamic>?)
              ?.map((e) => Episode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Episode {
  final String id;
  final int episodeNumber;
  final String title;
  final String? description;
  final int? runtime;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? hlsUrl;
  final List<String> quality;
  final int? skipIntroStart;
  final int? skipIntroEnd;
  final int? skipRecapStart;
  final int? skipRecapEnd;

  const Episode({
    required this.id,
    required this.episodeNumber,
    required this.title,
    this.description,
    this.runtime,
    this.thumbnailUrl,
    this.videoUrl,
    this.hlsUrl,
    this.quality = const ['720p', '1080p'],
    this.skipIntroStart,
    this.skipIntroEnd,
    this.skipRecapStart,
    this.skipRecapEnd,
  });

  String get runtimeFormatted {
    if (runtime == null) return '';
    final m = runtime!;
    return '${m}m';
  }

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'] as String,
      episodeNumber: json['episodeNumber'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      runtime: json['runtime'] as int?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      hlsUrl: json['hlsUrl'] as String?,
      quality: (json['quality'] as List<dynamic>?)?.cast<String>() ??
          ['720p', '1080p'],
      skipIntroStart: json['skipIntroStart'] as int?,
      skipIntroEnd: json['skipIntroEnd'] as int?,
      skipRecapStart: json['skipRecapStart'] as int?,
      skipRecapEnd: json['skipRecapEnd'] as int?,
    );
  }
}

class Genre {
  final String id;
  final String name;
  final String slug;

  const Genre({required this.id, required this.name, required this.slug});

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
    );
  }
}

class CastInfo {
  final String name;
  final String? photoUrl;
  final String? characterName;

  const CastInfo({required this.name, this.photoUrl, this.characterName});

  factory CastInfo.fromJson(Map<String, dynamic> json) {
    final member = json['castMember'] as Map<String, dynamic>?;
    return CastInfo(
      name: member?['name'] as String? ?? json['name'] as String? ?? '',
      photoUrl: member?['photoUrl'] as String? ?? json['photoUrl'] as String?,
      characterName: json['characterName'] as String?,
    );
  }
}

class CrewInfo {
  final String name;
  final String? photoUrl;
  final String role;

  const CrewInfo({required this.name, this.photoUrl, required this.role});

  factory CrewInfo.fromJson(Map<String, dynamic> json) {
    final member = json['crewMember'] as Map<String, dynamic>?;
    return CrewInfo(
      name: member?['name'] as String? ?? json['name'] as String? ?? '',
      photoUrl: member?['photoUrl'] as String? ?? json['photoUrl'] as String?,
      role: json['role'] as String? ?? '',
    );
  }
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final int priceMonthly;
  final int? priceYearly;
  final int maxScreens;
  final int maxDownloads;
  final int maxProfiles;
  final String videoQuality;
  final bool hasAds;
  final bool hasDolbyAtmos;
  final bool hasSpatialAudio;
  final bool hasHDR;
  final bool isPopular;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.priceMonthly,
    this.priceYearly,
    this.maxScreens = 1,
    this.maxDownloads = 0,
    this.maxProfiles = 1,
    this.videoQuality = '720p',
    this.hasAds = true,
    this.hasDolbyAtmos = false,
    this.hasSpatialAudio = false,
    this.hasHDR = false,
    this.isPopular = false,
  });

  String get priceFormatted => '₹${(priceMonthly / 100).toStringAsFixed(0)}';
  String get yearlyFormatted =>
      priceYearly != null ? '₹${(priceYearly! / 100).toStringAsFixed(0)}' : '';

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      priceMonthly: json['priceMonthly'] as int,
      priceYearly: json['priceYearly'] as int?,
      maxScreens: json['maxScreens'] as int? ?? 1,
      maxDownloads: json['maxDownloads'] as int? ?? 0,
      maxProfiles: json['maxProfiles'] as int? ?? 1,
      videoQuality: json['videoQuality'] as String? ?? '720p',
      hasAds: json['hasAds'] as bool? ?? true,
      hasDolbyAtmos: json['hasDolbyAtmos'] as bool? ?? false,
      hasSpatialAudio: json['hasSpatialAudio'] as bool? ?? false,
      hasHDR: json['hasHDR'] as bool? ?? false,
      isPopular: json['isPopular'] as bool? ?? false,
    );
  }
}

class Subscription {
  final String id;
  final SubscriptionPlan? plan;
  final String status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;

  const Subscription({
    required this.id,
    this.plan,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
  });

  int get daysRemaining {
    final remaining = currentPeriodEnd.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  bool get isExpired => currentPeriodEnd.isBefore(DateTime.now());

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      plan: json['plan'] != null
          ? SubscriptionPlan.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
      status: json['status'] as String,
      currentPeriodStart:
          DateTime.parse(json['currentPeriodStart'] as String),
      currentPeriodEnd:
          DateTime.parse(json['currentPeriodEnd'] as String),
    );
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      imageUrl: json['imageUrl'] as String?,
      type: json['type'] as String,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class DownloadItem {
  final String id;
  final String title;
  final String? thumbnailUrl;
  final String quality;
  final int? fileSizeBytes;
  final double progress;
  final String status; // PENDING, DOWNLOADING, COMPLETED, FAILED, EXPIRED, PAUSED
  final String? localPath;
  final String videoUrl;
  final DateTime? expiresAt;

  const DownloadItem({
    required this.id,
    required this.title,
    this.thumbnailUrl,
    this.quality = '720p',
    this.fileSizeBytes,
    this.progress = 0,
    this.status = 'COMPLETED',
    this.localPath,
    required this.videoUrl,
    this.expiresAt,
  });

  String get fileSizeFormatted {
    if (fileSizeBytes == null) return '';
    final mb = fileSizeBytes! / (1024 * 1024);
    if (mb > 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '${mb.toStringAsFixed(0)} MB';
  }

  DownloadItem copyWith({
    String? id,
    String? title,
    String? thumbnailUrl,
    String? quality,
    int? fileSizeBytes,
    double? progress,
    String? status,
    String? localPath,
    String? videoUrl,
    DateTime? expiresAt,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      quality: quality ?? this.quality,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      videoUrl: videoUrl ?? this.videoUrl,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'quality': quality,
      'fileSizeBytes': fileSizeBytes,
      'progress': progress,
      'status': status,
      'localPath': localPath,
      'videoUrl': videoUrl,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      quality: json['quality'] as String? ?? '720p',
      fileSizeBytes: json['fileSizeBytes'] as int?,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'COMPLETED',
      localPath: json['localPath'] as String?,
      videoUrl: json['videoUrl'] as String? ?? '',
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt'] as String) : null,
    );
  }
}
