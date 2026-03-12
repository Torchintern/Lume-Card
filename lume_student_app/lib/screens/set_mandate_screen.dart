import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class SetMandateScreen extends StatefulWidget {
  const SetMandateScreen({super.key});

  @override
  State<SetMandateScreen> createState() => _SetMandateScreenState();
}

class _SetMandateScreenState extends State<SetMandateScreen> {
  int _tabIndex = 0; // 0 for Frequency, 1 for Threshold
  String _frequency = 'Weekly';
  String _selectedDay = 'Monday';
  int _selectedDate = 1;

  bool _isProcessing = false;
  bool _needsRefresh = false; // Track if mandates were modified to refresh dashboard

  final TextEditingController _weeklyRechargeController = TextEditingController();
  final TextEditingController _thresholdController = TextEditingController();
  final TextEditingController _thresholdRechargeController = TextEditingController();

  // ================= HEADER CAROUSEL =================
  late PageController _headerPageController;
  Timer? _headerAutoScrollTimer;
  int _currentHeaderPage = 0;

  // ================= SCROLL & FOCUS =================
  final ScrollController _scrollController = ScrollController();
  final FocusNode _weeklyFocusNode = FocusNode();
  final FocusNode _thresholdFocusNode = FocusNode();
  final FocusNode _thresholdRechargeFocusNode = FocusNode();

  final List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _weeklyRechargeController.addListener(_evalButtonState);
    _thresholdController.addListener(_evalButtonState);
    _thresholdRechargeController.addListener(_evalButtonState);
    _headerPageController = PageController(initialPage: 400);
    _startHeaderAutoScroll();

    // Auto-scroll on focus
    _weeklyFocusNode.addListener(() => _scrollToField(_weeklyFocusNode));
    _thresholdFocusNode.addListener(() => _scrollToField(_thresholdFocusNode));
    _thresholdRechargeFocusNode
        .addListener(() => _scrollToField(_thresholdRechargeFocusNode));
  }

  void _scrollToField(FocusNode node) {
    if (node.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  void _startHeaderAutoScroll() {
    _headerAutoScrollTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (_headerPageController.hasClients) {
        _headerPageController.nextPage(
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _evalButtonState() {
    setState(() {}); // Still rebuilds but only when needed or just rely on the controller. Actually, to remove full screen rebuilds:
  }

  @override
  void dispose() {
    _headerAutoScrollTimer?.cancel();
    _headerPageController.dispose();
    _weeklyRechargeController.removeListener(_evalButtonState);
    _thresholdController.removeListener(_evalButtonState);
    _thresholdRechargeController.removeListener(_evalButtonState);
    _weeklyRechargeController.dispose();
    _thresholdController.dispose();
    _thresholdRechargeController.dispose();

    _scrollController.dispose();
    _weeklyFocusNode.dispose();
    _thresholdFocusNode.dispose();
    _thresholdRechargeFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedTabColor = isDark ? colorScheme.primary : const Color(0xFF6366F1); // Dashboard Indigo
    final unselectedTabBg = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9);
    final unselectedTabTextColor = isDark ? Colors.white54 : const Color(0xFF94A3B8);

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Dynamic Premium Header
          SliverAppBar(
            expandedHeight: size.height * 0.35,
            pinned: true,
            stretch: true,
            backgroundColor: colorScheme.primary,
            elevation: 0,
            leadingWidth: 70,
            leading: Center(
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () => Navigator.pop(context, _needsRefresh),
              ),
            ),
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: InkWell(
                    onTap: () async {
                      final refresh =
                          await Navigator.pushNamed(context, '/mandates');
                      if (refresh == true) {
                        setState(() => _needsRefresh = true);
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        "History",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              expandedTitleScale: 1.0,
              titlePadding: EdgeInsets.zero,
              title: LayoutBuilder(
                builder: (context, constraints) {
                  final double top = constraints.biggest.height;
                  final double expandedHeight = size.height * 0.35;
                  final double collapsedHeight =
                      MediaQuery.of(context).padding.top + kToolbarHeight;
                  final double delta = expandedHeight - collapsedHeight;
                  final double progress =
                      ((top - collapsedHeight) / delta).clamp(0.0, 1.0);

                  final double fontSize = 18 + (14 * progress);

                  return Container(
                    padding: EdgeInsets.only(
                      left: 25 * progress,
                      bottom: 25 * progress,
                    ),
                    alignment: Alignment.lerp(
                      Alignment.center,
                      Alignment.bottomLeft,
                      progress,
                    ),
                    child: Text(
                      "Mandate Setup",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5 * progress,
                      ),
                    ),
                  );
                },
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Dynamic Animated Background
                  PageView.builder(
                    controller: _headerPageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentHeaderPage = index % 3;
                      });
                    },
                    itemBuilder: (context, index) {
                      final int realIndex = index % 3;
                      return _buildHeaderSlide(realIndex, colorScheme);
                    },
                  ),

                  // Overlay Gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.35),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),

                  // Indicators
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 25,
                    right: 25,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(left: 4),
                          height: 4,
                          width: _currentHeaderPage == index ? 12 : 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                                _currentHeaderPage == index ? 0.9 : 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(20),
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
              ),
            ),
          ),

          // Content Area
          SliverToBoxAdapter(
            child: Container(
              color: colorScheme.surface,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Segmented Control
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: unselectedTabBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _tabIndex = 0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _tabIndex == 0
                                          ? selectedTabColor
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      "Frequency",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: _tabIndex == 0
                                            ? Colors.white
                                            : unselectedTabTextColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _tabIndex = 1),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _tabIndex == 1
                                          ? selectedTabColor
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      "Threshold",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: _tabIndex == 1
                                            ? Colors.white
                                            : unselectedTabTextColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        if (_tabIndex == 0)
                          _buildFrequencyTab(isDark, selectedTabColor,
                              unselectedTabBg, unselectedTabTextColor)
                        else
                          _buildThresholdTab(isDark, colorScheme),

                        const SizedBox(height: 120), // Spacer for bottom button
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ListenableBuilder(
            listenable: Listenable.merge([
              _weeklyRechargeController,
              _thresholdController,
              _thresholdRechargeController
            ]),
            builder: (context, _) {
              final canSubmit = _canSubmit();
              return ElevatedButton(
                onPressed:
                    (_isProcessing || !canSubmit) ? null : _submitMandate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_isProcessing || !canSubmit)
                      ? (isDark ? Colors.white12 : const Color(0xFFD1D5DB))
                      : colorScheme.primary,
                  foregroundColor: (_isProcessing || !canSubmit)
                      ? (isDark ? Colors.white38 : const Color(0xFF6B7280))
                      : colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        "Continue",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  bool _canSubmit() {
    if (_tabIndex == 0) {
      return _weeklyRechargeController.text.isNotEmpty;
    } else {
      return _thresholdController.text.isNotEmpty && _thresholdRechargeController.text.isNotEmpty;
    }
  }

  Future<void> _submitMandate() async {
    setState(() => _isProcessing = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        _showErrorDialog("Error", "Authentication token missing.");
        return;
      }

      final payload = {
        "mandate_type": _tabIndex == 0 ? "Frequency" : "Threshold",
        "frequency": _tabIndex == 0 ? _frequency : null,
        "day_of_week": (_tabIndex == 0 && _frequency == 'Weekly') ? _selectedDay : null,
        "date_of_month": (_tabIndex == 0 && _frequency == 'Monthly') ? _selectedDate : null,
        "amount": _tabIndex == 0 ? double.tryParse(_weeklyRechargeController.text.replaceAll(',', '')) : null,
        "threshold_amount": _tabIndex == 1 ? double.tryParse(_thresholdController.text.replaceAll(',', '')) : null,
        "recharge_amount": _tabIndex == 1 ? double.tryParse(_thresholdRechargeController.text.replaceAll(',', '')) : null,
      };

      if (_tabIndex == 1) {
        payload["amount"] = double.tryParse(_thresholdRechargeController.text.replaceAll(',', ''));
      }

      final res = await ApiService.createMandate(token, payload);

      if (res['success'] == true) {
        final double? newBalance = (res['new_balance'] as num?)?.toDouble();
        _showSuccessDialog(newBalance: newBalance);
      } else {
        _showErrorDialog("Failed", res['error'] ?? "Failed to set mandate. Please try again.");
      }
    } catch (e) {
      _showErrorDialog("Error", "An unexpected error occurred. Please try again later.");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog({double? newBalance}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (dialogContext, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    blurRadius: 60,
                    offset: const Offset(0, 20),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 72,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "Setup Successful!",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Your Auto Top-Up mandate has been configured successfully.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  if (newBalance != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, size: 18, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Text(
                            "New Balance: ₹${newBalance.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext); // close dialog
                        if (mounted) {
                          // Return both refresh signal and new balance
                          Navigator.pop(context, {"refresh": true, "newBalance": newBalance});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Done",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (dialogContext, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(isDark ? 0.2 : 0.1),
                    blurRadius: 60,
                    offset: const Offset(0, 20),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.redAccent,
                      size: 72,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext); // Close dialog
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                        foregroundColor: colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Try Again",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrequencyTab(bool isDark, Color selectedColor, Color unselectedBg, Color unselectedTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _frequency = 'Weekly'),
          child: Row(
            children: [
              Radio<String>(
                value: 'Weekly',
                groupValue: _frequency,
                onChanged: (val) => setState(() => _frequency = val!),
                activeColor: selectedColor,
                fillColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return selectedColor;
                  }
                  return isDark ? Colors.white54 : Colors.black87;
                }),
              ),
              Text(
                "Weekly",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
        
        if (_frequency == 'Weekly') ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 12,
              children: _days.map((day) {
                final isSelected = _selectedDay == day;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? selectedColor : unselectedBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : unselectedTextColor),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => setState(() => _frequency = 'Monthly'),
          child: Row(
            children: [
              Radio<String>(
                value: 'Monthly',
                groupValue: _frequency,
                onChanged: (val) => setState(() => _frequency = val!),
                activeColor: selectedColor,
                fillColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return selectedColor;
                  }
                  return isDark ? Colors.white54 : Colors.black87;
                }),
              ),
              Text(
                "Monthly",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),

        if (_frequency == 'Monthly') ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? [] : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 12,
                crossAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: 28,
              itemBuilder: (context, index) {
                final date = index + 1;
                final isSelected = _selectedDate == date;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? selectedColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      date.toString(),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 8),
        _buildTextField(
            "This amount will be added to your card", _weeklyRechargeController, isDark, _weeklyFocusNode),
      ],
    );
  }

  Widget _buildThresholdTab(bool isDark, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Threshold amount",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        _buildTextField("", _thresholdController, isDark, _thresholdFocusNode),

        const SizedBox(height: 24),
        Text(
          "Recharge amount",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        _buildTextField("This amount will be added to your card", _thresholdRechargeController, isDark, _thresholdRechargeFocusNode),

        const SizedBox(height: 24),
        ListenableBuilder(
          listenable: Listenable.merge([_thresholdController, _thresholdRechargeController]),
          builder: (context, _) {
            String thresholdAmt = _thresholdController.text.isEmpty ? "₹0.00" : "₹${_thresholdController.text}";
            String rechargeAmt = _thresholdRechargeController.text.isEmpty ? "₹0.00" : "₹${_thresholdRechargeController.text}";
            return Text(
              "When amount will be less than $thresholdAmt then $rechargeAmt will be automatically debited from your UPI and added to prepaid wallet.",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : const Color(0xFF4B5563),
                height: 1.5,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller,
      bool isDark, FocusNode focusNode) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      scrollPadding: const EdgeInsets.only(bottom: 200),
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF6366F1),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
  Widget _buildHeaderSlide(int index, ColorScheme colorScheme) {
    switch (index) {
      case 0:
        return _buildSlideBase(
          color1: colorScheme.primary,
          color2: colorScheme.secondary,
          icon: Icons.auto_mode_rounded,
          title: "Auto Top-Up",
          subtitle: "Set it once and never worry about low balance again.",
        );
      case 1:
        return _buildSlideBase(
          color1: const Color(0xFF1E1B4B),
          color2: const Color(0xFF4338CA),
          icon: Icons.timer_rounded,
          title: "Flexible Rules",
          subtitle: "Choose between scheduled frequency or balance thresholds.",
        );
      case 2:
        return _buildSlideBase(
          color1: const Color(0xFF0F172A),
          color2: const Color(0xFF334155),
          icon: Icons.security_rounded,
          title: "Safe & Secure",
          subtitle: "Manage your mandates with full control and transparency.",
        );
      default:
        return Container(color: colorScheme.primary);
    }
  }

  Widget _buildSlideBase({
    required Color color1,
    required Color color2,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(icon, size: 180, color: Colors.white.withOpacity(0.08)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(25, 60, 25, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white.withOpacity(0.9), size: 32),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 220,
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
