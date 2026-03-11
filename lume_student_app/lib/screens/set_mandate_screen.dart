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
  }

  void _evalButtonState() {
    setState(() {}); // Still rebuilds but only when needed or just rely on the controller. Actually, to remove full screen rebuilds:
  }

  @override
  void dispose() {
    _weeklyRechargeController.removeListener(_evalButtonState);
    _thresholdController.removeListener(_evalButtonState);
    _thresholdRechargeController.removeListener(_evalButtonState);
    _weeklyRechargeController.dispose();
    _thresholdController.dispose();
    _thresholdRechargeController.dispose();
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
      body: Column(
        children: [
          // Fixed Premium Header
          Container(
            height: size.height * 0.25,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                SafeArea(
                  bottom: false,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 10,
                        left: 12,
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
                      Positioned(
                        top: 10,
                        right: 12,
                        child: TextButton(
                          onPressed: () async {
                            final refresh = await Navigator.pushNamed(context, '/mandates');
                            if (refresh == true) {
                              setState(() => _needsRefresh = true);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              "View Mandates",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        bottom: 50,
                        left: 20,
                        child: Text(
                          "Mandate Setup",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content Area with rounded top
          Expanded(
            child: Container(
              width: double.infinity,
              transform: Matrix4.translationValues(0, -25, 0),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      physics: const BouncingScrollPhysics(),
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
                                        color: _tabIndex == 0 ? selectedTabColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Frequency",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: _tabIndex == 0 ? Colors.white : unselectedTabTextColor,
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
                                        color: _tabIndex == 1 ? selectedTabColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "Threshold",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: _tabIndex == 1 ? Colors.white : unselectedTabTextColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          if (_tabIndex == 0) _buildFrequencyTab(isDark, selectedTabColor, unselectedTabBg, unselectedTabTextColor)
                          else _buildThresholdTab(isDark, colorScheme),
                          
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Continue Button
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 24),
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
                            onPressed: (_isProcessing || !canSubmit) ? null : _submitMandate,
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
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                  )
                ],
              ),
            ),
          ),
        ],
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

        const SizedBox(height: 32),
        Text(
          "Recharge amount",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        _buildTextField("This amount will be added to your card", _weeklyRechargeController, isDark),
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
        _buildTextField("", _thresholdController, isDark),

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
        _buildTextField("This amount will be added to your card", _thresholdRechargeController, isDark),

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

  Widget _buildTextField(String hint, TextEditingController controller, bool isDark) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
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
}
