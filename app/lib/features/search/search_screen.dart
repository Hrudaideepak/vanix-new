import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/vanix_colors.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  final List<String> trendingSearches = ['Cyberpunk 2077', 'Dune Part Two', 'The Last of Us', 'Oppenheimer'];
  final List<Map<String, String>> genres = [
    {'name': 'Action', 'label': 'EXPLORE'},
    {'name': 'Sci-Fi', 'label': 'DISCOVER'},
    {'name': 'Anime', 'label': 'EXPERIENCE'},
    {'name': 'Horror', 'label': 'INTENSE'},
    {'name': 'Comedy', 'label': 'ENJOY'},
    {'name': 'Drama', 'label': 'FEEL'},
  ];
  final List<Map<String, String>> results = [
    {'title': 'Neon Genesis', 'year': '2024', 'genre': 'Sci-Fi Action'},
    {'title': 'A.I. Uprising', 'year': '2023', 'genre': 'Thriller'},
    {'title': 'The Void', 'year': '2024', 'genre': 'Fantasy'},
    {'title': 'Cinema Classic', 'year': '2024', 'genre': 'Variety • Special'},
    {'title': 'Ronin Red', 'year': '2022', 'genre': 'Anime'},
    {'title': 'Global Vision', 'year': '2024', 'genre': 'Documentary'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VanixColors.bgPrimary,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/vanix_logo.png',
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 8),
                        Text('VANIX', style: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 3)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: VanixColors.bgTertiary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _isSearching ? VanixColors.vanixRed : VanixColors.borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: VanixColors.textMuted, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) => setState(() => _isSearching = value.isNotEmpty),
                              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search movies, actors, or genre...',
                                hintStyle: GoogleFonts.poppins(fontSize: 14, color: VanixColors.textMuted),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.mic, color: VanixColors.vanixRed, size: 22),
                            onPressed: () {},
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Trending tags
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTag('TRENDING', true),
                        ...trendingSearches.map((s) => _buildTag(s, false)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Browse by Genre
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Browse by Genre',
                      style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Genre grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.6,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final genre = genres[index];
                    return _buildGenreCard(genre['name']!, genre['label']!);
                  },
                  childCount: genres.length,
                ),
              ),
            ),

            // Search Results
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Search Results',
                      style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('Showing ${results.length} matches',
                      style: GoogleFonts.poppins(fontSize: 12, color: VanixColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),

            // Results grid
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = results[index];
                    return _buildResultCard(item, index);
                  },
                  childCount: results.length,
                ),
              ),
            ),

            // FAB space
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),

      // Filter FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: VanixColors.vanixRed,
        icon: const Icon(Icons.tune, size: 18),
        label: Text('FILTER', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
      ),
    );
  }

  Widget _buildTag(String text, bool isHighlighted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isHighlighted ? VanixColors.vanixRed : VanixColors.bgTertiary,
        borderRadius: BorderRadius.circular(20),
        border: isHighlighted ? null : Border.all(color: VanixColors.borderColor),
      ),
      child: Text(text,
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400, color: Colors.white),
      ),
    );
  }

  Widget _buildGenreCard(String name, String label) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [VanixColors.bgTertiary, VanixColors.bgCard],
        ),
        border: Border.all(color: VanixColors.borderColor.withOpacity(0.5)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 12,
            child: Text(label,
              style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.w700, color: VanixColors.vanixRed.withOpacity(0.6), letterSpacing: 2),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            child: Text(name,
              style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, String> item, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: VanixColors.bgCard,
        border: Border.all(color: VanixColors.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    HSLColor.fromAHSL(1, (index * 60.0) % 360, 0.3, 0.15).toColor(),
                    VanixColors.bgCard,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Center(child: Icon(Icons.movie_creation_outlined, size: 40, color: Colors.white12)),
                  if (index == 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: VanixColors.vanixRed, borderRadius: BorderRadius.circular(4)),
                        child: Text('4K HDR', style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title']!, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 3),
                Text('${item['year']} • ${item['genre']}', style: GoogleFonts.poppins(fontSize: 10, color: VanixColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
