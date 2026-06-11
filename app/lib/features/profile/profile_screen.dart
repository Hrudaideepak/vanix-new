import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/vanix_colors.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/models.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Mock states
  bool _notificationsEnabled = true;
  String _videoQuality = 'Auto (Best Quality)';
  String _downloadQuality = 'Standard (Saves Storage)';
  String _language = 'English';

  void _addProfile() {
    TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VanixColors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: VanixColors.borderColor),
        ),
        title: Text(
          'Create Profile',
          style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameController,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Profile Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: VanixColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final newProfile = Profile(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  avatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=100',
                );
                ref.read(profilesProvider.notifier).update((state) => [...state, newProfile]);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VanixColors.vanixRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _selectVideoQuality() {
    showModalBottomSheet(
      context: context,
      backgroundColor: VanixColors.bgElevated,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Streaming Video Quality', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            const Divider(),
            _buildQualityListTile('Auto (Best Quality)'),
            _buildQualityListTile('Data Saver (480p)'),
            _buildQualityListTile('Standard (720p)'),
            _buildQualityListTile('High Definition (1080p)'),
            _buildQualityListTile('Ultra HD (4K)'),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityListTile(String val) {
    return ListTile(
      title: Text(val, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
      trailing: _videoQuality == val ? const Icon(Icons.check, color: VanixColors.vanixRed) : null,
      onTap: () {
        setState(() {
          _videoQuality = val;
        });
        Navigator.pop(context);
      },
    );
  }

  void _selectDownloadQuality() {
    showModalBottomSheet(
      context: context,
      backgroundColor: VanixColors.bgElevated,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Offline Download Quality', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            const Divider(),
            ListTile(
              title: Text('Standard (Saves Storage)', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
              trailing: _downloadQuality.contains('Standard') ? const Icon(Icons.check, color: VanixColors.vanixRed) : null,
              onTap: () {
                setState(() => _downloadQuality = 'Standard (Saves Storage)');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('High (Uses More Storage)', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
              trailing: _downloadQuality.contains('High') ? const Icon(Icons.check, color: VanixColors.vanixRed) : null,
              onTap: () {
                setState(() => _downloadQuality = 'High (Uses More Storage)');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VanixColors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: VanixColors.borderColor),
        ),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to log out of your VANIX account?',
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: VanixColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              ref.read(authProvider.notifier).logout();
              ref.read(selectedProfileProvider.notifier).state = null;
            },
            style: ElevatedButton.styleFrom(backgroundColor: VanixColors.vanixRed),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    final activeProfile = ref.watch(selectedProfileProvider);

    return Scaffold(
      backgroundColor: VanixColors.bgPrimary,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/vanix_logo.png',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'MY ACCOUNT',
              style: GoogleFonts.orbitron(letterSpacing: 2, fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // Profile Switcher (Netflix style)
            Text(
              'Switch Profile',
              style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: profiles.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  if (index == profiles.length) {
                    // "Add Profile" button
                    return Column(
                      children: [
                        GestureDetector(
                          onTap: _addProfile,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: VanixColors.bgSecondary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: VanixColors.borderColor, style: BorderStyle.solid),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add New',
                          style: GoogleFonts.poppins(fontSize: 10, color: VanixColors.textMuted),
                        ),
                      ],
                    );
                  }

                  final prof = profiles[index];
                  final isActive = activeProfile?.id == prof.id;

                  return Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          ref.read(selectedProfileProvider.notifier).state = prof;
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive ? VanixColors.vanixRed : Colors.transparent,
                              width: 2.5,
                            ),
                            image: DecorationImage(
                              image: NetworkImage(prof.avatarUrl ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        prof.name,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? Colors.white : VanixColors.textSecondary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Account details card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VanixColors.bgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VanixColors.borderColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: activeProfile?.isKids == true ? Colors.orange : VanixColors.vanixRed,
                    backgroundImage: activeProfile?.avatarUrl != null ? NetworkImage(activeProfile!.avatarUrl!) : null,
                    child: activeProfile?.avatarUrl == null
                        ? Text(
                            activeProfile?.name.isNotEmpty == true ? activeProfile!.name[0].toUpperCase() : 'U',
                            style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeProfile?.name ?? 'Alex Harrison',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                        ),
                        Text(
                          'alex.harrison@gmail.com',
                          style: GoogleFonts.poppins(fontSize: 12, color: VanixColors.textSecondary),
                        ),
                        Text(
                          '+91 98765 43210',
                          style: GoogleFonts.poppins(fontSize: 12, color: VanixColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                    onPressed: () {
                      // Edit details popup mock
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Edit Profile details feature is locked in demo mode')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Subscriptions billing widget
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF230303), Color(0xFF0F0000)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VanixColors.vanixRed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VANIX Premium Active',
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        Text(
                          'Renews on 09 July 2026',
                          style: GoogleFonts.poppins(fontSize: 11, color: VanixColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/subscription'),
                    child: Text(
                      'Manage',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Settings Section Group
            Text(
              'App Settings',
              style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            _buildSettingTile(
              icon: Icons.video_settings,
              title: 'Streaming Video Quality',
              subtitle: _videoQuality,
              onTap: _selectVideoQuality,
            ),
            _buildSettingTile(
              icon: Icons.downloading_rounded,
              title: 'Offline Download Quality',
              subtitle: _downloadQuality,
              onTap: _selectDownloadQuality,
            ),
            _buildSettingTile(
              icon: Icons.translate,
              title: 'Preferred Language',
              subtitle: _language,
              onTap: () {
                // Language sheet mock
                setState(() {
                  _language = _language == 'English' ? 'Hindi' : 'English';
                });
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              secondary: const Icon(Icons.notifications_none_rounded, color: Colors.white70),
              title: Text('Push Notifications', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
              subtitle: Text('Get notified of new drops & custom suggestions', style: GoogleFonts.poppins(fontSize: 11, color: VanixColors.textMuted)),
              activeColor: VanixColors.vanixRed,
              value: _notificationsEnabled,
              onChanged: (bool value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
            const Divider(height: 30),

            // App info
            Text(
              'App Info & Agreements',
              style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            _buildSimpleTile('Terms of Service', () {}),
            _buildSimpleTile('Privacy Policy', () {}),
            _buildSimpleTile('Contact Support & Help Desk', () {}),

            const SizedBox(height: 32),

            // Logout Button
            Center(
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: VanixColors.vanixRed),
                    foregroundColor: VanixColors.vanixRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Log Out Account',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Danger Zone Expandable
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  'Danger Zone',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade400, fontWeight: FontWeight.bold),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Permanently delete your account along with all watch history, profiles, billing receipts, and list recommendations.',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Account deletion is locked for demonstration')),
                            );
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
                          child: const Text('Delete Account Permanently'),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
      subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: VanixColors.textMuted)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
      onTap: onTap,
    );
  }

  Widget _buildSimpleTile(String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 12),
      onTap: onTap,
    );
  }
}
