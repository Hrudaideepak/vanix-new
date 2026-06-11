import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/vanix_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _zoomAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // Phase 1: Elastic Logo Pop-out (0.0 to 45% of time)
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
      ),
    );

    // Phase 2: Glow Pulse (35% to 75% of time)
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.75, curve: Curves.easeInOutSine),
      ),
    );

    // Phase 3: Netflix Zoom-in to screen (75% to 100% of time)
    _zoomAnimation = Tween<double>(begin: 1.0, end: 35.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 1.0, curve: Curves.easeInExpo),
      ),
    );

    // Phase 3: Fade-out during zoom (80% to 100% of time)
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.80, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) {
      if (mounted) {
        // GoRouter will redirect to home, login, or profile select automatically based on auth state
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double currentScale = _zoomAnimation.value > 1.0 
              ? _zoomAnimation.value 
              : _scaleAnimation.value;
          final double opacity = _opacityAnimation.value;
          final double glow = _glowAnimation.value;

          return Center(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: currentScale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glowing logo container
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft glow behind logo
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: VanixColors.vanixRed.withOpacity(0.35 * glow),
                                blurRadius: 40 * glow,
                                spreadRadius: 10 * glow,
                              ),
                            ],
                          ),
                        ),
                        // Logo image
                        Image.asset(
                          'assets/images/vanix_logo.png',
                          width: 100,
                          height: 100,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Pulsing Brand Name Text
                    Text(
                      'VANIX',
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        shadows: [
                          Shadow(
                            color: VanixColors.vanixRed.withOpacity(0.6 * glow),
                            blurRadius: 15 * glow,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
