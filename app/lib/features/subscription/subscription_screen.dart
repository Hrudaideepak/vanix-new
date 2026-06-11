import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/vanix_colors.dart';
import '../../core/widgets/vanix_button.dart';
import '../../core/services/billing_service.dart';
import '../../core/providers/auth_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final BillingService _billingService = BillingService();
  bool _isBillingYearly = false;
  int _selectedPlanIndex = 1; // Default to Premium
  final PageController _pageController = PageController(viewportFraction: 0.8, initialPage: 1);
  double _currentPage = 1.0;
  
  final TextEditingController _couponController = TextEditingController();
  bool _isCouponApplied = false;
  double _discountAmount = 0.0;
  String _couponMessage = '';
  bool _isProcessing = false;

  // Plan tiers with custom gradient metadata
  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'vanix_mobile',
      'name': 'VANIX Mobile',
      'monthlyPrice': 149.0,
      'yearlyPrice': 999.0,
      'quality': '720p (HD)',
      'screens': 1,
      'downloads': 10,
      'ads': 'Ad-Supported',
      'dolby': false,
      'hdr': false,
      'isPopular': false,
      'badge': 'BASIC',
      'gradient': const [Color(0xFFE28743), Color(0xFF963D00)], // Bronze/Copper
      'glowColor': Color(0xFF963D00),
    },
    {
      'id': 'vanix_premium',
      'name': 'VANIX Premium',
      'monthlyPrice': 299.0,
      'yearlyPrice': 1999.0,
      'quality': '4K UHD + HDR',
      'screens': 4,
      'downloads': 100,
      'ads': 'Ad-Free',
      'dolby': true,
      'hdr': true,
      'isPopular': true,
      'badge': 'BEST VALUE',
      'gradient': const [Color(0xFFFFDF00), Color(0xFFB57C1E)], // Metallic Gold
      'glowColor': Color(0xFFB57C1E),
    },
    {
      'id': 'vanix_ultimate',
      'name': 'VANIX Ultimate',
      'monthlyPrice': 499.0,
      'yearlyPrice': 3499.0,
      'quality': '4K UHD + Dolby Vision',
      'screens': 6,
      'downloads': 500,
      'ads': 'Ad-Free',
      'dolby': true,
      'hdr': true,
      'isPopular': false,
      'badge': 'CINEMATIC',
      'gradient': const [Color(0xFFE5E4E2), Color(0xFF5A5D64)], // Platinum/Chrome
      'glowColor': Color(0xFF8A95A5),
    }
  ];

  @override
  void initState() {
    super.initState();
    
    // Listen to page changes to animate card scale
    _pageController.addListener(() {
      if (_pageController.position.haveDimensions) {
        setState(() {
          _currentPage = _pageController.page!;
        });
      }
    });

    // Initialize unified platform billing service
    _billingService.initialize(_handlePurchaseResponse);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  /// Verification callback for native or sandbox store transactions
  void _handlePurchaseResponse(bool success, String? message) {
    if (!mounted) return;
    
    setState(() {
      _isProcessing = false;
    });

    if (success) {
      // Refresh Auth State and navigate home
      ref.read(authProvider.notifier).setDemoUser(); // Mark as verified premium user for demo
      
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'SuccessDialog',
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
        transitionBuilder: (context, anim1, anim2, child) {
          final curve = CurvedAnimation(parent: anim1, curve: Curves.elasticOut);
          return ScaleTransition(
            scale: curve,
            child: AlertDialog(
              backgroundColor: VanixColors.bgElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFF2E2E3E), width: 1.5),
              ),
              title: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0x1F2ECC71),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2ECC71), size: 48),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TRANSACTION VERIFIED',
                    style: GoogleFonts.orbitron(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5),
                  ),
                ],
              ),
              content: Text(
                message ?? 'Your subscription status is now fully synced with your App Store profile. Welcome to VANIX Premium.',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                SizedBox(
                  width: 160,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/'); // Navigate back home
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Let\'s Stream', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Error dialogue
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? 'Payment failed, please try again.'),
          backgroundColor: VanixColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _applyCoupon() {
    final code = _couponController.text.trim().toUpperCase();
    if (code == 'VANIX50') {
      setState(() {
        _isCouponApplied = true;
        _discountAmount = 0.50; // 50% off
        _couponMessage = '🎉 50% PROMO DISCOUNT APPLIED!';
      });
    } else if (code == 'FIRSTFREE') {
      setState(() {
        _isCouponApplied = true;
        _discountAmount = 1.00; // 100% off
        _couponMessage = '🔥 FIRST MONTH FREE UNLOCKED!';
      });
    } else {
      setState(() {
        _isCouponApplied = false;
        _discountAmount = 0.0;
        _couponMessage = '❌ Invalid or expired coupon code';
      });
    }
  }

  void _restorePurchases() async {
    setState(() {
      _isProcessing = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contacting server to restore purchases...', style: GoogleFonts.poppins()),
        backgroundColor: VanixColors.vanixRed,
        duration: const Duration(seconds: 1),
      ),
    );
    await _billingService.restorePurchases();
    setState(() {
      _isProcessing = false;
    });
  }

  void _processPayment() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final selectedPlan = _plans[_selectedPlanIndex];
    final basePrice = _isBillingYearly ? selectedPlan['yearlyPrice'] : selectedPlan['monthlyPrice'];
    final finalPrice = basePrice * (1.0 - _discountAmount);
    
    // Choose appropriate product ID based on selection
    final intervalSuffix = _isBillingYearly ? '_yearly' : '_monthly';
    final storeProductId = '${selectedPlan['id']}$intervalSuffix';

    // Invoke platform-level purchase gateway
    await _billingService.purchasePlan(
      storeProductId,
      isYearly: _isBillingYearly,
      localPrice: finalPrice,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VanixColors.bgPrimary,
      appBar: AppBar(
        title: Text(
          'V A N I X',
          style: GoogleFonts.orbitron(
            fontSize: 20, 
            fontWeight: FontWeight.w900, 
            color: VanixColors.vanixRed, 
            letterSpacing: 4
          ),
        ),
        centerTitle: true,
        actions: [
          // Apple Compliance Restore button
          TextButton.icon(
            onPressed: _isProcessing ? null : _restorePurchases,
            icon: const Icon(Icons.restore_rounded, size: 16, color: Colors.white70),
            label: Text(
              'Restore',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header tagline
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Colors.white70, Colors.grey],
                          ).createShader(bounds),
                          child: Text(
                            'UNLIMITED STREAMING EXPERIENCE',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Select a premium plan that matches your screen setups.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: VanixColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Interactive Billing Toggle Slider
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    width: 280,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F1E),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFF1E1E2E)),
                    ),
                    child: Stack(
                      children: [
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.fastOutSlowIn,
                          alignment: _isBillingYearly ? Alignment.centerRight : Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: 0.5,
                            child: Container(
                              height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: [VanixColors.vanixRed, Color(0xFFB81D24)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: VanixColors.vanixRed.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isBillingYearly = false),
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  height: 32,
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Monthly',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: !_isBillingYearly ? Colors.white : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isBillingYearly = true),
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  height: 32,
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Yearly ',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _isBillingYearly ? Colors.white : Colors.grey,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade700,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '-40%',
                                          style: GoogleFonts.poppins(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 3D Scaling Card PageView Carousel
                SizedBox(
                  height: 320,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _plans.length,
                    onPageChanged: (index) {
                      setState(() {
                        _selectedPlanIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final plan = _plans[index];
                      
                      // Calculate card scale and translation based on page offset
                      double val = 1.0;
                      if (_currentPage >= 0) {
                        val = _currentPage - index;
                        val = (1 - (val.abs() * 0.15)).clamp(0.0, 1.0);
                      }
                      
                      final isSelected = _selectedPlanIndex == index;
                      final price = _isBillingYearly ? plan['yearlyPrice'] : plan['monthlyPrice'];
                      final gradientColors = plan['gradient'] as List<Color>;
                      final glowColor = plan['glowColor'] as Color;

                      return Transform.scale(
                        scale: val,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: glowColor.withOpacity(0.2),
                                blurRadius: 24,
                                spreadRadius: 2,
                                offset: const Offset(0, 6),
                              )
                            ] : [],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0x1AFFFFFF) : const Color(0x0AFFFFFF),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isSelected ? gradientColors[0] : const Color(0xFF1E1E2E),
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Custom Metallic badge
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: gradientColors),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            plan['badge']!,
                                            style: GoogleFonts.orbitron(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                        if (plan['isPopular'])
                                          const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Plan Title
                                    Text(
                                      plan['name']!,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),

                                    // Pricing display
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '₹${price.toStringAsFixed(0)}',
                                          style: GoogleFonts.orbitron(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          _isBillingYearly ? '/year' : '/month',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: VanixColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(color: Color(0xFF1E1E2E)),
                                    const SizedBox(height: 12),

                                    // Spec list
                                    _buildPlanFeature(Icons.hd_rounded, plan['quality']),
                                    _buildPlanFeature(Icons.devices_rounded, '${plan['screens']} simultanous screens'),
                                    _buildPlanFeature(Icons.download_done_rounded, '${plan['downloads']} offline downloads'),
                                    _buildPlanFeature(Icons.lock_rounded, plan['ads']),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Indicator Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_plans.length, (idx) {
                    final isActive = _selectedPlanIndex == idx;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      width: isActive ? 18 : 6,
                      decoration: BoxDecoration(
                        color: isActive ? VanixColors.vanixRed : const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // Promo code Expandable Card (Glassmorphic)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1E1E2E)),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text(
                          'Have a Promo Code?',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        leading: const Icon(Icons.local_offer_rounded, color: Colors.amber, size: 20),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _couponController,
                                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
                                        decoration: InputDecoration(
                                          hintText: 'Enter code (e.g. VANIX50)',
                                          filled: true,
                                          fillColor: const Color(0xFF0F0F1E),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: const BorderSide(color: Color(0xFF1E1E2E)),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: const BorderSide(color: VanixColors.vanixRed),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _applyCoupon,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E1E2E),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text('Apply', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                if (_couponMessage.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _couponMessage,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: _isCouponApplied ? const Color(0xFF2ECC71) : VanixColors.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Premium Feature Comparison Matrix
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detailed Feature Matrix',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0x07FFFFFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1E1E2E)),
                        ),
                        child: Table(
                          border: TableBorder.symmetric(inside: const BorderSide(color: Color(0xFF1E1E2E))),
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1.2),
                            2: FlexColumnWidth(1.2),
                          },
                          children: [
                            _buildTableHeader(),
                            _buildTableRow('Video Resolution', '720p', '4K UHD'),
                            _buildTableRow('Dolby Atmos Audio', '❌', '✅'),
                            _buildTableRow('HDR10+ / Vision', '❌', '✅'),
                            _buildTableRow('Offline Download cap', '10', 'Unlimited'),
                            _buildTableRow('Connected Screens', '1', '6'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 120), // Padding to avoid overlap with bottom navigation bar
              ],
            ),
          ),
          
          // Custom Loading blur overlay when processing payments
          if (_isProcessing)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: VanixColors.vanixRed),
                          const SizedBox(height: 16),
                          Text(
                            'CONTACTING APP STORE GATEWAY...',
                            style: GoogleFonts.orbitron(
                              color: Colors.white, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 12, 
                              letterSpacing: 2.0
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F1E),
          border: Border(top: BorderSide(color: Color(0xFF1E1E2E))),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL PAYMENT',
                    style: GoogleFonts.orbitron(fontSize: 8, color: VanixColors.textMuted, letterSpacing: 1.5),
                  ),
                  Text(
                    '₹${((_isBillingYearly ? _plans[_selectedPlanIndex]['yearlyPrice'] : _plans[_selectedPlanIndex]['monthlyPrice']) * (1.0 - _discountAmount)).toStringAsFixed(0)}',
                    style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ],
              ),
              SizedBox(
                width: 190,
                child: VanixButton(
                  text: _isBillingYearly ? 'Activate Yearly Access' : 'Activate Monthly Access',
                  onPressed: _isProcessing ? () {} : _processPayment,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: VanixColors.vanixRed, size: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0x0AFFFFFF)),
      children: [
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text('Specification', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text('Mobile', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text('Ultimate', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableRow(String spec, String v1, String v2) {
    return TableRow(
      children: [
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(spec, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
          ),
        ),
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(v1, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
          ),
        ),
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(v2, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
