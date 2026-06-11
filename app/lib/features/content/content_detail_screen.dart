import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/vanix_colors.dart';
import '../../core/widgets/vanix_button.dart';
import '../../core/widgets/content_card.dart';
import '../downloads/providers/download_provider.dart';
import '../../core/models/models.dart';

class ContentDetailScreen extends ConsumerStatefulWidget {
  final String contentId;

  const ContentDetailScreen({
    super.key,
    required this.contentId,
  });

  @override
  ConsumerState<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends ConsumerState<ContentDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedSeasonIndex = 0;
  bool _isWatchlisted = false;

  // Mock content details
  late final bool isSeries;
  late final String title;
  late final String year;
  late final String rating;
  late final String durationOrSeasons;
  late final String synopsis;
  late final String mainGenre;
  late final List<String> genres;
  late final List<Map<String, String>> cast;
  late final List<Map<String, String>> episodes;
  late final List<Map<String, dynamic>> relatedContent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize mock data based on contentId
    isSeries = widget.contentId.toLowerCase().contains('series') || 
               widget.contentId.toLowerCase().contains('cyberpunk') || 
               widget.contentId.toLowerCase().contains('realm') ||
               widget.contentId.isEmpty; // Default to series for demo if empty

    if (isSeries) {
      title = widget.contentId.contains('realm') ? 'Shadow Realm' : 'Cyberpunk Nights';
      year = '2024';
      rating = 'U/A 16+';
      durationOrSeasons = '2 Seasons';
      mainGenre = 'Sci-Fi Action';
      genres = ['Sci-Fi', 'Cyberpunk', 'Action', 'Thriller'];
      synopsis = 'In a city where memories are traded like currency, a rogue detective uncovers a deep corporate conspiracy that threatens to rewrite the history of humanity itself. With the city on the brink of rebellion, he must decide whose memory is worth protecting.';
      cast = [
        {'name': 'Kenji Sato', 'role': 'Kaelen Vance', 'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150'},
        {'name': 'Elena Rostova', 'role': 'Iris Thorne', 'image': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150'},
        {'name': 'Marcus Vance', 'role': 'Director Sterling', 'image': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150'},
        {'name': 'Aya Tanaka', 'role': 'Nyx', 'image': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150'},
      ];
      episodes = [
        {'number': '1', 'title': 'The Memory Trader', 'runtime': '48m', 'desc': 'Kaelen is hired to track down a high-profile memory leak, leading him into the dangerous underbelly of Sector 7.', 'progress': '1.0'},
        {'number': '2', 'title': 'Neon Shadows', 'runtime': '42m', 'desc': 'Iris Thorne offers an alliance, revealing that the stolen memory belongs to the Chief Executive of Obsidian Corp.', 'progress': '1.0'},
        {'number': '3', 'title': 'Ghosts in the Machine', 'runtime': '45m', 'desc': 'A ghost hacker starts targeting Kaelen\'s neural implants, forcing him to seek help from a rogue bio-hacker.', 'progress': '0.8'},
        {'number': '4', 'title': 'The Obsidian Tower', 'runtime': '51m', 'desc': 'Kaelen and Iris stage a daring break-in to the Obsidian archives, but an unexpected betrayal awaits them.', 'progress': '0.0'},
        {'number': '5', 'title': 'Rewriting Reality', 'runtime': '55m', 'desc': 'With the city on lockdown, Kaelen must make the ultimate choice regarding the core memory banks.', 'progress': '0.0'},
      ];
    } else {
      title = widget.contentId.contains('dune') ? 'Dune: Part Two' : 'Neon Genesis';
      year = '2024';
      rating = 'U/A 13+';
      durationOrSeasons = '2h 46m';
      mainGenre = 'Sci-Fi Drama';
      genres = ['Sci-Fi', 'Space Opera', 'Adventure', 'Drama'];
      synopsis = 'Paul Atreides unites with Chani and the Fremen while seeking revenge against the conspirators who destroyed his family. Facing a choice between the love of his life and the fate of the universe, he endeavors to prevent a terrible future only he can foresee.';
      cast = [
        {'name': 'Timothée C.', 'role': 'Paul Atreides', 'image': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150'},
        {'name': 'Zendaya', 'role': 'Chani', 'image': 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150'},
        {'name': 'Rebecca F.', 'role': 'Lady Jessica', 'image': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150'},
        {'name': 'Austin Butler', 'role': 'Feyd-Rautha', 'image': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150'},
      ];
      episodes = [];
    }

    relatedContent = [
      {'title': 'Dune: Part Two', 'rating': 9.2, 'image': 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=300'},
      {'title': 'Cyberpunk Nights', 'rating': 9.1, 'image': 'https://images.unsplash.com/photo-1578894381163-e72c17f2d45f?w=300'},
      {'title': 'Neon Genesis', 'rating': 8.9, 'image': 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=300'},
      {'title': 'The Void', 'rating': 8.7, 'image': 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=300'},
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleWatchlist() {
    setState(() {
      _isWatchlisted = !_isWatchlisted;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isWatchlisted ? 'Added to Watchlist' : 'Removed from Watchlist',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startDownload(DownloadItem? downloadItem) {
    if (downloadItem != null && downloadItem.status == 'COMPLETED') {
      ref.read(downloadProvider.notifier).removeDownload(widget.contentId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download removed')),
      );
      return;
    }

    if (downloadItem != null && downloadItem.status == 'DOWNLOADING') {
      ref.read(downloadProvider.notifier).pauseDownload(widget.contentId);
      return;
    }

    if (downloadItem != null && downloadItem.status == 'PAUSED') {
      ref.read(downloadProvider.notifier).resumeDownload(widget.contentId);
      return;
    }

    ref.read(downloadProvider.notifier).startDownload(
      id: widget.contentId,
      title: title,
      thumbnailUrl: isSeries
          ? 'https://images.unsplash.com/photo-1578894381163-e72c17f2d45f?w=200'
          : 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=200',
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      quality: '1080p',
    );
  }

  void _shareContent() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sharing link to $title...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(downloadProvider);
    final downloadItemIndex = downloads.indexWhere((item) => item.id == widget.contentId);
    final downloadItem = downloadItemIndex != -1 ? downloads[downloadItemIndex] : null;

    final isDownloaded = downloadItem?.status == 'COMPLETED';
    final isDownloading = downloadItem?.status == 'DOWNLOADING';
    final isPaused = downloadItem?.status == 'PAUSED';
    final progress = downloadItem?.progress ?? 0.0;

    return Scaffold(
      backgroundColor: VanixColors.bgPrimary,
      body: CustomScrollView(
        slivers: [
          // Sliver Hero Backdrop
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            leading: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.5),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
            backgroundColor: VanixColors.bgPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Backdrop image
                  Image.network(
                    isSeries 
                      ? 'https://images.unsplash.com/photo-1578894381163-e72c17f2d45f?w=600'
                      : 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: VanixColors.bgSecondary),
                  ),
                  // Dark gradients to overlay text
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black54,
                          Colors.transparent,
                          VanixColors.bgPrimary,
                        ],
                        stops: [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                  // Centered play floating icon
                  Center(
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: VanixColors.vanixRed.withOpacity(0.85),
                      child: IconButton(
                        icon: const Icon(Icons.play_arrow_rounded, size: 38, color: Colors.white),
                        onPressed: () {
                          // Play trailer or content
                          context.push('/player/${widget.contentId}');
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Header Details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Metadata Badges (Year, rating, duration)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: VanixColors.bgTertiary,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: VanixColors.borderColor),
                        ),
                        child: Text(
                          year,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: VanixColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: VanixColors.bgTertiary,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: VanixColors.borderColor),
                        ),
                        child: Text(
                          rating,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: VanixColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        durationOrSeasons,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: VanixColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Ultra HD/Dolby Atmos tags
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: VanixColors.vanixRedGlow,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          '4K UHD',
                          style: GoogleFonts.orbitron(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: VanixColors.vanixRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Play Button (Immersive/Dynamic CTA)
                  VanixButton(
                    text: 'Watch Now',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () {
                      context.push('/player/${widget.contentId}');
                    },
                  ),
                  const SizedBox(height: 16),

                  // Actions row (Watchlist, Download, Share)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionItem(
                        icon: _isWatchlisted ? Icons.check : Icons.add,
                        label: 'My List',
                        color: _isWatchlisted ? VanixColors.vanixRed : Colors.white,
                        onTap: _toggleWatchlist,
                      ),
                      _buildActionItem(
                        icon: isDownloading 
                            ? Icons.pause
                            : (isPaused 
                                ? Icons.play_arrow 
                                : (isDownloaded ? Icons.download_done : Icons.download)),
                        label: isDownloading 
                            ? '${(progress * 100).toStringAsFixed(0)}%' 
                            : (isPaused ? 'Paused' : (isDownloaded ? 'Downloaded' : 'Download')),
                        color: isDownloaded 
                            ? VanixColors.success 
                            : (isDownloading || isPaused ? VanixColors.vanixRed : Colors.white),
                        onTap: () => _startDownload(downloadItem),
                      ),
                      _buildActionItem(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: _shareContent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Synopsis
                  Text(
                    synopsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: VanixColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Tabs for Episodes (if Series), More Like This, and Details
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: VanixColors.vanixRed,
                  labelColor: Colors.white,
                  unselectedLabelColor: VanixColors.textMuted,
                  labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: [
                    if (isSeries) const Tab(text: 'EPISODES') else const Tab(text: 'TRAILERS'),
                    const Tab(text: 'MORE LIKE THIS'),
                    const Tab(text: 'DETAILS'),
                  ],
                ),
                Container(
                  height: isSeries ? 420 : 320,
                  padding: const EdgeInsets.all(16.0),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Episodes (Series) / Trailers (Movie)
                      if (isSeries)
                        _buildEpisodesTab()
                      else
                        _buildTrailersTab(),

                      // Tab 2: More Like This
                      _buildRelatedTab(),

                      // Tab 3: Details (Cast, Crew, Syn)
                      _buildDetailsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: VanixColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Season dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: VanixColors.bgTertiary,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: VanixColors.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedSeasonIndex,
              dropdownColor: VanixColors.bgElevated,
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Season 1')),
                DropdownMenuItem(value: 1, child: Text('Season 2')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedSeasonIndex = val;
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Episode List
        Expanded(
          child: ListView.separated(
            itemCount: episodes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final ep = episodes[index];
              final double progress = double.tryParse(ep['progress'] ?? '0.0') ?? 0.0;
              final isWatched = progress >= 0.95;

              return InkWell(
                onTap: () {
                  context.push('/player/${widget.contentId}_s1e${ep['number']}');
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Episode thumbnail with progress bar
                    Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: VanixColors.bgSecondary,
                            image: const DecorationImage(
                              image: NetworkImage('https://images.unsplash.com/photo-1542204172-e7052809564d?w=200'),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Center(
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.black.withOpacity(0.6),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                        if (progress > 0.0 && !isWatched)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 3,
                              color: VanixColors.vanixRed,
                              backgroundColor: Colors.grey.withOpacity(0.5),
                            ),
                          ),
                        if (isWatched)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: VanixColors.success,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                'WATCHED',
                                style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Episode Title & Description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${ep['number']}. ${ep['title']}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ep['runtime']!,
                            style: GoogleFonts.poppins(fontSize: 10, color: VanixColors.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ep['desc']!,
                            style: GoogleFonts.poppins(fontSize: 10, color: VanixColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrailersTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _buildTrailerCard('Official Trailer 1', '2m 14s'),
        const SizedBox(height: 12),
        _buildTrailerCard('Teaser Trailer', '1m 05s'),
        const SizedBox(height: 12),
        _buildTrailerCard('Behind The Scenes', '8m 40s'),
      ],
    );
  }

  Widget _buildTrailerCard(String name, String length) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: VanixColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VanixColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 50,
            decoration: BoxDecoration(
              color: VanixColors.bgSecondary,
              borderRadius: BorderRadius.circular(4),
              image: const DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=150'),
                fit: BoxFit.cover,
              ),
            ),
            child: const Center(
              child: Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
                ),
                Text(
                  length,
                  style: GoogleFonts.poppins(fontSize: 10, color: VanixColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedTab() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.68,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: relatedContent.length,
      itemBuilder: (context, index) {
        final item = relatedContent[index];
        return ContentCard(
          title: item['title']!,
          rating: item['rating'] as double,
          imageUrl: item['image'] as String,
          width: 90,
          height: 140,
          onTap: () {
            // Push replacement to load new content
            context.pushReplacement('/content/${item['title'].toLowerCase().replaceAll(' ', '_')}');
          },
        );
      },
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Genres tags
          Text(
            'Genres',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: genres.map((g) => Chip(
              label: Text(g),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )).toList(),
          ),
          const SizedBox(height: 16),

          // Cast list
          Text(
            'Cast & Crew',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cast.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final actor = cast[index];
                return Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: NetworkImage(actor['image']!),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      actor['name']!,
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      actor['role']!,
                      style: GoogleFonts.poppins(fontSize: 9, color: VanixColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Director: Jordan Roberts',
            style: GoogleFonts.poppins(fontSize: 11, color: VanixColors.textSecondary),
          ),
          Text(
            'Studio: VANIX Studios',
            style: GoogleFonts.poppins(fontSize: 11, color: VanixColors.textSecondary),
          ),
        ],
      ),
    );
  }
}


