import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/vanix_colors.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/models/models.dart';

class ProfileSelectScreen extends ConsumerStatefulWidget {
  const ProfileSelectScreen({super.key});

  @override
  ConsumerState<ProfileSelectScreen> createState() => _ProfileSelectScreenState();
}

class _ProfileSelectScreenState extends ConsumerState<ProfileSelectScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _addNewProfile() {
    final TextEditingController nameController = TextEditingController();
    bool isKids = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: VanixColors.bgElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: VanixColors.borderColor),
          ),
          title: Text(
            'Add Profile',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Profile Name',
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Text(
                  'Kids Profile?',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  'Only show family-friendly content',
                  style: GoogleFonts.poppins(color: VanixColors.textSecondary, fontSize: 11),
                ),
                value: isKids,
                activeColor: VanixColors.vanixRed,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setDialogState(() {
                    isKids = val ?? false;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: VanixColors.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final randomId = DateTime.now().millisecondsSinceEpoch.toString();
                  // Default avatars: Kids avatar vs generic avatar
                  final avatar = isKids
                      ? 'https://images.unsplash.com/photo-1607990283143-e81e7a2c93ab?w=100'
                      : 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=100';

                  final newProfile = Profile(
                    id: randomId,
                    name: name,
                    avatarUrl: avatar,
                    isKids: isKids,
                  );

                  ref.read(profilesProvider.notifier).update((state) => [...state, newProfile]);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: VanixColors.vanixRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Add', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);

    return Scaffold(
      backgroundColor: VanixColors.bgPrimary,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing VANIX text logo at top
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/vanix_logo.png',
                      width: 30,
                      height: 30,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'VANIX',
                      style: GoogleFonts.orbitron(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 8,
                        shadows: [
                          Shadow(
                            color: VanixColors.vanixRed.withOpacity(0.5),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),

                // Main Title "Who's Watching?"
                Text(
                  "Who's Watching?",
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),

                // Staggered grid/row of profiles
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  alignment: WrapAlignment.center,
                  children: [
                    for (int i = 0; i < profiles.length; i++)
                      _buildStaggeredProfileItem(profiles[i], i),
                    
                    // Add new profile button
                    _buildStaggeredAddButton(profiles.length),
                  ],
                ),
                const SizedBox(height: 60),

                // Manage Profiles outline button
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Manage profiles is available inside your Profile settings tab'),
                        backgroundColor: VanixColors.bgElevated,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: Text(
                    'MANAGE PROFILES',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaggeredProfileItem(Profile profile, int index) {
    final animation = CurvedAnimation(
      parent: _entryController,
      curve: Interval(
        (index * 0.12).clamp(0.0, 0.9),
        (index * 0.12 + 0.6).clamp(0.0, 1.0),
        curve: Curves.easeOutBack,
      ),
    );

    return ScaleTransition(
      scale: animation,
      child: FadeTransition(
        opacity: animation,
        child: _ProfileCard(
          profile: profile,
          onTap: () {
            ref.read(selectedProfileProvider.notifier).state = profile;
          },
        ),
      ),
    );
  }

  Widget _buildStaggeredAddButton(int count) {
    final animation = CurvedAnimation(
      parent: _entryController,
      curve: Interval(
        (count * 0.12).clamp(0.0, 0.9),
        (count * 0.12 + 0.6).clamp(0.0, 1.0),
        curve: Curves.easeOutBack,
      ),
    );

    return ScaleTransition(
      scale: animation,
      child: FadeTransition(
        opacity: animation,
        child: Column(
          children: [
            _HoverableAddCard(onTap: _addNewProfile),
            const SizedBox(height: 12),
            Text(
              'Add Profile',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: VanixColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatefulWidget {
  final Profile profile;
  final VoidCallback onTap;

  const _ProfileCard({required this.profile, required this.onTap});

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: _isHovered ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isHovered ? Colors.white : Colors.transparent,
                    width: 3.0,
                  ),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.15),
                            blurRadius: 15,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                  image: DecorationImage(
                    image: NetworkImage(widget.profile.avatarUrl ??
                        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.profile.name,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: _isHovered ? FontWeight.bold : FontWeight.normal,
                color: _isHovered ? Colors.white : VanixColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverableAddCard extends StatefulWidget {
  final VoidCallback onTap;

  const _HoverableAddCard({required this.onTap});

  @override
  State<_HoverableAddCard> createState() => _HoverableAddCardState();
}

class _HoverableAddCardState extends State<_HoverableAddCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _isHovered ? Colors.white.withOpacity(0.08) : VanixColors.bgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered ? Colors.white54 : VanixColors.borderColor,
                width: 2.0,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.add_circle_outline_rounded,
                color: Colors.white70,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
