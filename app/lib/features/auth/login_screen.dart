import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../core/theme/vanix_colors.dart';
import '../../core/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  bool _isPhone = true;
  bool _showOtp = false;
  bool _isLoading = false;
  String _otp = '';
  int _resendTimer = 0;
  Timer? _timer;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Slightly longer for the elastic bounce to be satisfying
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.1, 0.9, curve: Curves.elasticOut),
      ),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fadeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendOtp() async {
    final identifier = _isPhone
        ? _phoneController.text.trim()
        : _emailController.text.trim();

    if (identifier.isEmpty) {
      _showSnackBar(_isPhone ? 'Enter your phone number' : 'Enter your email');
      return;
    }

    setState(() => _isLoading = true);

    // Simulate OTP sending (in real app, calls authProvider.sendOtp)
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _showOtp = true;
    });
    _startResendTimer();
    _showSnackBar('OTP sent! Use 123456 for demo', isSuccess: true);
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) {
      _showSnackBar('Enter complete 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);

    // Demo: accept 123456 as valid OTP
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    if (_otp == '123456') {
      ref.read(authProvider.notifier).setDemoUser();
      if (mounted) context.go('/');
    } else {
      setState(() => _isLoading = false);
      _showSnackBar('Invalid OTP. Use 123456 for demo.');
    }
  }

  void _skipLogin() {
    ref.read(authProvider.notifier).setDemoUser();
    context.go('/');
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? VanixColors.success : VanixColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VanixColors.bgPrimary,
      body: Stack(
        children: [
          // Animated background pattern
          _buildBackground(),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    _buildLogo(),
                    const SizedBox(height: 48),
                    _buildWelcomeText(),
                    const SizedBox(height: 40),

                    if (!_showOtp) ...[
                      _buildAuthToggle(),
                      const SizedBox(height: 24),
                      _buildInputField(),
                      const SizedBox(height: 24),
                      _buildSendOtpButton(),
                      const SizedBox(height: 32),
                      _buildDivider(),
                      const SizedBox(height: 24),
                      _buildGoogleButton(),
                    ] else ...[
                      _buildOtpSection(),
                    ],

                    const SizedBox(height: 32),
                    _buildSkipButton(),
                    const SizedBox(height: 24),
                    _buildTerms(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Back button (from OTP)
          if (_showOtp)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                onPressed: () => setState(() {
                  _showOtp = false;
                  _otp = '';
                  _otpController.clear();
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Top right glow
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      VanixColors.vanixRed.withOpacity(0.08 * _glowAnimation.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Bottom left glow
            Positioned(
              bottom: -150,
              left: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      VanixColors.vanixRed.withOpacity(0.05 * _glowAnimation.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Grid pattern overlay
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(opacity: 0.03),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: VanixColors.vanixRed.withOpacity(0.25 * _glowAnimation.value),
                  blurRadius: 35,
                  spreadRadius: 5,
                ),
              ],
            ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/vanix_logo.png',
                width: 54,
                height: 54,
              ),
              const SizedBox(width: 14),
              Text(
                'VANIX',
                style: GoogleFonts.orbitron(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: VanixColors.textPrimary,
                  letterSpacing: 8,
                  shadows: [
                    Shadow(
                      color: VanixColors.vanixRed.withOpacity(0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          _showOtp ? 'Verify OTP' : 'Welcome Back',
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: VanixColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _showOtp
              ? 'Enter the 6-digit code sent to your ${_isPhone ? 'phone' : 'email'}'
              : 'Sign in to continue your cinematic journey',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: VanixColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAuthToggle() {
    return Container(
      decoration: BoxDecoration(
        color: VanixColors.bgTertiary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VanixColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isPhone = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isPhone ? VanixColors.vanixRed : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(
                    'Phone',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _isPhone
                          ? Colors.white
                          : VanixColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isPhone = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isPhone ? VanixColors.vanixRed : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(
                    'Email',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: !_isPhone
                          ? Colors.white
                          : VanixColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: VanixColors.bgTertiary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VanixColors.borderColor),
      ),
      child: Row(
        children: [
          if (_isPhone) ...[
            Text(
              '🇮🇳 +91',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: VanixColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 1,
              height: 24,
              color: VanixColors.borderColor,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: _isPhone ? _phoneController : _emailController,
              keyboardType: _isPhone
                  ? TextInputType.phone
                  : TextInputType.emailAddress,
              inputFormatters: _isPhone
                  ? [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ]
                  : null,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: _isPhone ? 'Enter phone number' : 'Enter your email',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: VanixColors.textMuted,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendOtpButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _sendOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: VanixColors.vanixRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: VanixColors.vanixRedDark.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                'Send OTP',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: VanixColors.borderColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: VanixColors.textMuted,
            ),
          ),
        ),
        const Expanded(child: Divider(color: VanixColors.borderColor)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          // In production: trigger Google Sign-In
          _showSnackBar('Google Sign-In requires Firebase setup');
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: VanixColors.borderLight),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google "G" icon
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  'G',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: VanixColors.vanixRed,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpSection() {
    return Column(
      children: [
        // OTP display indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: VanixColors.bgTertiary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: VanixColors.borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isPhone ? Icons.phone_android : Icons.email_outlined,
                size: 18,
                color: VanixColors.vanixRed,
              ),
              const SizedBox(width: 8),
              Text(
                _isPhone
                    ? '+91 ${_phoneController.text}'
                    : _emailController.text,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: VanixColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // PIN code input
        PinCodeTextField(
          appContext: context,
          length: 6,
          controller: _otpController,
          onChanged: (value) => setState(() => _otp = value),
          onCompleted: (_) => _verifyOtp(),
          animationType: AnimationType.fade,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textStyle: GoogleFonts.orbitron(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(10),
            fieldHeight: 56,
            fieldWidth: 48,
            activeColor: VanixColors.vanixRed,
            inactiveColor: VanixColors.borderColor,
            selectedColor: VanixColors.vanixRedHover,
            activeFillColor: VanixColors.bgTertiary,
            inactiveFillColor: VanixColors.bgTertiary,
            selectedFillColor: VanixColors.vanixRed.withOpacity(0.1),
          ),
          enableActiveFill: true,
          cursorColor: VanixColors.vanixRed,
          animationDuration: const Duration(milliseconds: 200),
        ),
        const SizedBox(height: 24),

        // Verify button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: VanixColors.vanixRed,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  VanixColors.vanixRedDark.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    'Verify & Continue',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Resend timer
        _resendTimer > 0
            ? Text(
                'Resend OTP in ${_resendTimer}s',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: VanixColors.textMuted,
                ),
              )
            : TextButton(
                onPressed: _sendOtp,
                child: Text(
                  'Resend OTP',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: VanixColors.vanixRed,
                  ),
                ),
              ),

        const SizedBox(height: 8),
        Text(
          'Demo OTP: 123456',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: VanixColors.vanixRed.withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildSkipButton() {
    return TextButton(
      onPressed: _skipLogin,
      child: Text(
        'Skip for now →',
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: VanixColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTerms() {
    return Text.rich(
      TextSpan(
        text: 'By continuing, you agree to our ',
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: VanixColors.textMuted,
        ),
        children: [
          TextSpan(
            text: 'Terms of Service',
            style: TextStyle(color: VanixColors.vanixRed),
          ),
          const TextSpan(text: ' & '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(color: VanixColors.vanixRed),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Subtle grid pattern painter for background
class _GridPainter extends CustomPainter {
  final double opacity;
  _GridPainter({this.opacity = 0.05});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 0.5;

    const spacing = 40.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
