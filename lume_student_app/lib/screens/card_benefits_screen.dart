import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart'; // To reuse painters

class CardBenefitsScreen extends StatefulWidget {
  const CardBenefitsScreen({super.key});

  @override
  State<CardBenefitsScreen> createState() => _CardBenefitsScreenState();
}

class _CardBenefitsScreenState extends State<CardBenefitsScreen> with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0; // 0 for Features, 1 for Fees
  bool _isLoading = true;

  // Animation for flip card
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isFlipped = false;

  // Profile Data
  String _userName = "";
  String _userRegNo = "";
  String _userDept = "";
  String _userInstitute = "";
  String _userBloodGroup = "";
  String _userBatch = "";
  String _userPhone = "";
  String? _profileImageUrl;

  // Card Data
  bool _isCardLocked = false;
  bool _isCardBlocked = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");
      if (token == null) return;

      // 1. Fetch Profile
      final profileRes = await ApiService.getProfile(token);
      if (profileRes["error"] == null && profileRes["student"] != null) {
        final student = profileRes["student"];
        _userName = student["full_name"] ?? "";
        _userRegNo = student["reg_no"] ?? "";
        _userDept = student["department"] ?? "";
        _userInstitute = student["institute_name"] ?? "";
        _userBloodGroup = student["blood_group"] ?? "";
        _userPhone = student["mobile"] ?? "";
        _profileImageUrl = student["profile_image"];
        
        final batchStart = student["batch_start_year"]?.toString() ?? "";
        final batchEnd = student["batch_end_year"]?.toString() ?? "";
        if (batchStart.isNotEmpty && batchEnd.isNotEmpty) {
          _userBatch = "$batchStart - $batchEnd";
        } else if (batchStart.isNotEmpty) {
          _userBatch = batchStart;
        }
      }

      // 2. Fetch Card Details
      final cardRes = await ApiService.getCardDetails(token);
      if (cardRes.isNotEmpty) {
        final String lockStatus = (cardRes["card_lock"] ?? "").toString().toUpperCase();
        final String cardState = (cardRes["card_state"] ?? "").toString().toUpperCase();
        
        _isCardLocked = lockStatus == "LOCKED" || cardRes["card_lock"] == true;
        _isCardBlocked = lockStatus == "BLOCKED" || cardState == "BLOCKED";
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _flipCard() {
    if (_isFlipped) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
    _isFlipped = !_isFlipped;
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "U";
    List<String> parts = name.trim().split(" ");
    if (parts.length > 1) {
      return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    }
    return name.substring(0, min(2, name.length)).toUpperCase();
  }

  Widget _buildCardDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: Color(0xFF6B7280)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E)),
        ),
      ],
    );
  }

  Widget _buildRuPayLogo({double fontSize = 18}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Image.asset(
        "assets/logos/rupay.png",
        height: fontSize + 6,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildSimpleDivider() {
    return Container(
      height: 1.5,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C3AED).withOpacity(0.4), // Metallic Purple
            const Color(0xFF7C3AED).withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildCardFront(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: 260,
      height: 410,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1F2937), // Dark grey
            Color(0xFF374151), // Medium grey
            Color(0xFF111827), // Deep grey/black
            Color(0xFF1F2937), // Back to dark grey
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.4, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 25,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Brushed Metal Texture
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(
                painter: BrushedMetalPainter(),
              ),
            ),
          ),
          
          // Subtle Metallic Highlight
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          
          Positioned(
            right: -20,
            bottom: 30,
            child: Opacity(
              opacity: 0.1,
              child: Image.asset("assets/logo.png", height: 200, color: Colors.white10),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Section - Chip and Contactless Icon
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 25),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Premium Chip Design (Vertical)
                        Container(
                          width: 38,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFDE68A),
                                Color(0xFFF59E0B),
                                Color(0xFFD97706),
                                Color(0xFFFDE68A),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black54, width: 0.5),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(painter: ChipLinesPainter()),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.contactless_outlined, color: Colors.white70, size: 28),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                const Spacer(),
                
                // Central Logo - LUME
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "🄻🅄🄼🄴",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "STUDENT EXCLUSIVE",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 2),
                
                // Bottom Section - RuPay and Prepaid
                Align(
                  alignment: Alignment.bottomRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildRuPayLogo(fontSize: 18),
                      const SizedBox(height: 4),
                      const Text(
                        "PREPAID",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isCardLocked || _isCardBlocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isCardBlocked ? Icons.block_rounded : Icons.lock_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _isCardBlocked ? "BLOCKED" : "LOCKED",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardBack(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: 260,
      height: 410,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 25,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            children: [
              // Decorative left strip
              Container(
                width: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.7),
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset("assets/logos/university.png", height: 35, errorBuilder: (c,e,s) => const Icon(Icons.school)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _userInstitute.isEmpty ? "UNIVERSITY NAME" : _userInstitute,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A1A2E),
                                height: 1.1,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildSimpleDivider(),
                      const SizedBox(height: 8),
                      Text(
                        _userName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1A2E),
                          letterSpacing: 0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (_userDept.isNotEmpty)
                        Text(
                          _userDept.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A2E).withOpacity(0.7),
                            letterSpacing: 0.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 75,
                            height: 95,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                              image: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage("${ApiService.baseUrl}/uploads/profile_pics/$_profileImageUrl"),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                                ? Center(
                                    child: Text(
                                      _getInitials(_userName),
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCardDetailRow("STUDENT ID", _userRegNo.isEmpty ? "-" : _userRegNo),
                                const SizedBox(height: 5),
                                _buildCardDetailRow("BATCH", _userBatch.isEmpty ? "-" : _userBatch),
                                const SizedBox(height: 5),
                                _buildCardDetailRow("PHONE", _userPhone.isEmpty ? "-" : _userPhone),
                                const SizedBox(height: 5),
                                _buildCardDetailRow("BLOOD GR", _userBloodGroup.isEmpty ? "-" : _userBloodGroup),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 70,
                                height: 20,
                                child: CustomPaint(painter: SignaturePainter()),
                              ),
                              Container(
                                width: 70,
                                height: 1,
                                color: const Color(0xFFD1D5DB),
                                margin: const EdgeInsets.symmetric(vertical: 2),
                              ),
                              const Text(
                                "REGISTRAR",
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: QrImageView(
                              data: _userRegNo.isEmpty ? "LUME_STUDENT" : _userRegNo,
                              version: QrVersions.auto,
                              size: 60.0,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "This card is valid in India only.",
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontSize: 6.5, 
                          color: Color(0xFF9CA3AF),
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isCardLocked || _isCardBlocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isCardBlocked ? Icons.block_rounded : Icons.lock_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _isCardBlocked ? "BLOCKED" : "LOCKED",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFlippingCard(BuildContext context, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: GestureDetector(
            onTap: _flipCard,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final angle = _animation.value * pi;
                final isFront = angle <= pi / 2;

                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
                  alignment: Alignment.center,
                  child: isFront
                      ? _buildCardFront(context, colorScheme)
                      : Transform(
                          transform: Matrix4.identity()..rotateY(pi),
                          alignment: Alignment.center,
                          child: _buildCardBack(context, colorScheme),
                        ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "Tap card to flip",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitTile(String title, String subtitle, {IconData? icon, String? explicitRightText}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (explicitRightText != null)
            Text(
              explicitRightText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text("Card benefits", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Card benefits",
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          children: [
            _buildFlippingCard(context, colorScheme),
            
            const SizedBox(height: 32),
            
            // Custom Segmented Control
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 0 ? colorScheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Features",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _selectedTabIndex == 0 ? Colors.white : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 1 ? colorScheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Fees & charges",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _selectedTabIndex == 1 ? Colors.white : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            if (_selectedTabIndex == 0) ...[
              // Features Tab
              _buildBenefitTile("Transact digitally", "Use your card virtually through the app", icon: Icons.smartphone_rounded),
              _buildBenefitTile("Enhanced security", "Chip-enabled protection for safe transactions", icon: Icons.security_rounded),
              _buildBenefitTile("Instant lock control", "Lock or unlock your card anytime", icon: Icons.lock_outline_rounded),
              _buildBenefitTile("Exclusive discounts", "Get deals at partner cafes and stores", icon: Icons.local_offer_outlined),
            ] else ...[
              // Fees & charges Tab
              _buildBenefitTile("Card issuance fee", "", explicitRightText: "No Charge"),
              _buildBenefitTile("Annual maintenance", "", explicitRightText: "No Charge"),
              _buildBenefitTile("Card replacement", "", explicitRightText: "₹199 + GST"),
              _buildBenefitTile("ATM withdrawal", "", explicitRightText: "₹29 Per txn(3 free/month)"),
              _buildBenefitTile("Forex markup", "International transactions", explicitRightText: "3.5% + GST"),
            ]
          ],
        ),
      ),
    );
  }
}
