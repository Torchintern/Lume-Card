import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class CardReissueScreen extends StatefulWidget {
  const CardReissueScreen({super.key});

  @override
  State<CardReissueScreen> createState() => _CardReissueScreenState();
}

class _CardReissueScreenState extends State<CardReissueScreen> {
  String? _selectedReason;
  final TextEditingController _otherReasonController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isFetchingPincode = false;
  bool _isLoading = false;
  String? _authToken;

  final double _replacementFee = 199.0;
  final double _gstPercentage = 0.18;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _authToken = prefs.getString('auth_token'));
  }

  bool _isFormValid() {
    bool reasonOk = _selectedReason != null;
    if (_selectedReason == "Other") {
      reasonOk = _otherReasonController.text.trim().isNotEmpty;
    }
    return reasonOk &&
        _addressController.text.trim().isNotEmpty &&
        _pincodeController.text.trim().length == 6 &&
        _cityController.text.trim().isNotEmpty &&
        _stateController.text.trim().isNotEmpty &&
        _phoneController.text.trim().isNotEmpty;
  }

  void _checkPincode(String value) async {
    if (value.length == 6) {
      setState(() => _isFetchingPincode = true);
      try {
        final data = await ApiService.getPincodeDetails(value);
        if (data != null && data is List && data.isNotEmpty) {
          final status = data[0]["Status"];
          if (status == "Success") {
            final postOffice = data[0]["PostOffice"][0];
            setState(() {
              _cityController.text = postOffice["District"];
              _stateController.text = postOffice["State"];
            });
          }
        }
      } catch (_) {}
      if (mounted) {
        setState(() => _isFetchingPincode = false);
      }
    }
  }

  String get _effectiveReason {
    if (_selectedReason == "Other") {
      return "Other: ${_otherReasonController.text.trim()}";
    }
    return _selectedReason ?? "";
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final double gstAmount = _replacementFee * _gstPercentage;
    final double totalAmount = _replacementFee + gstAmount;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          "Request Reissue",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- REASON SECTION --
            _buildSectionHeader(context, "REASON FOR REISSUE"),
            const SizedBox(height: 12),
            _buildReasonOption(context, "Damaged"),
            _buildReasonOption(context, "Loss"),
            _buildReasonOption(context, "Stolen"),
            _buildReasonOption(context, "Other"),
            if (_selectedReason == "Other") ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otherReasonController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "Describe the reason...",
                  filled: true,
                  fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                maxLines: 2,
              ),
            ],

            const SizedBox(height: 32),

            // -- ADDRESS SECTION --
            _buildSectionHeader(context, "DELIVERY ADDRESS"),
            const SizedBox(height: 16),
            _buildTextField(
              context,
              "Permanent Address",
              Icons.home_rounded,
              _addressController,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    context,
                    "Pincode",
                    Icons.pin_drop_rounded,
                    _pincodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    onChanged: _checkPincode,
                    suffix: _isFetchingPincode
                        ? Transform.scale(
                            scale: 0.4,
                            child: const CircularProgressIndicator(
                                strokeWidth: 3),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    context,
                    "Phone Number",
                    Icons.phone_android_rounded,
                    _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    context,
                    "City",
                    Icons.location_city_rounded,
                    _cityController,
                    isReadOnly: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    context,
                    "State",
                    Icons.map_rounded,
                    _stateController,
                    isReadOnly: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // -- PAYMENT SECTION --
            _buildSectionHeader(context, "PAYMENT SUMMARY"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: colorScheme.primary.withOpacity(0.12)),
              ),
              child: Column(
                children: [
                  _buildPaymentRow(
                    "Replacement Fee",
                    "₹${_replacementFee.toStringAsFixed(0)}",
                    colorScheme,
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentRow(
                    "GST (18%)",
                    "₹${gstAmount.toStringAsFixed(2)}",
                    colorScheme,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),
                  _buildPaymentRow(
                    "Total Payable",
                    "₹${totalAmount.toStringAsFixed(2)}",
                    colorScheme,
                    isTotal: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // -- T&C and PRIVACY --
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                   Text(
                    "By proceeding, you agree to our ",
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, "/terms"),
                    child: Text(
                      "Terms & Conditions",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Text(
                    " and ",
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, "/privacy"),
                    child: Text(
                      "Privacy Policy",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // -- BUTTON --
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: (_isFormValid() && !_isLoading)
                    ? _handlePaymentConfirm
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      colorScheme.primary.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Pay and Confirm",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildReasonOption(BuildContext context, String reason) {
    return RadioListTile<String>(
      title: Text(reason, style: const TextStyle(fontWeight: FontWeight.w600)),
      value: reason,
      groupValue: _selectedReason,
      onChanged: (val) => setState(() => _selectedReason = val),
      activeColor: Theme.of(context).colorScheme.primary,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildTextField(
    BuildContext context,
    String label,
    IconData icon,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool isReadOnly = false,
    Function(String)? onChanged,
    Widget? suffix,
    int? maxLength,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: isReadOnly,
          maxLength: maxLength,
          onChanged: (val) {
            setState(() {});
            if (onChanged != null) onChanged(val);
          },
          decoration: InputDecoration(
            labelText: label,
            counterText: "",
            prefixIcon: Icon(icon, color: colorScheme.primary, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: isReadOnly
                ? colorScheme.surfaceVariant.withOpacity(0.1)
                : colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPaymentRow(String label, String value, ColorScheme colorScheme,
      {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
            color: isTotal
                ? colorScheme.onSurface
                : colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 14,
            fontWeight: FontWeight.w900,
            color: isTotal ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  void _handlePaymentConfirm() async {
    if (_authToken == null) {
      _showError("Not authenticated. Please log in again.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Simulate payment gateway — treat as success
      await Future.delayed(const Duration(seconds: 2));

      final res = await ApiService.requestReissue(_authToken!, {
        "reason": _effectiveReason,
        "payment_success": true,
        "address": _addressController.text.trim(),
        "city": _cityController.text.trim(),
        "state": _stateController.text.trim(),
        "pincode": _pincodeController.text.trim(),
        "phone": _phoneController.text.trim(),
      });

      if (mounted) {
        setState(() => _isLoading = false);
        if (res["success"] == true) {
          HapticFeedback.heavyImpact();
          _showSuccessDialog();
        } else {
          _showError(res["error"] ?? "Reissue request failed.");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError("Could not connect to server.");
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSuccessDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          backgroundColor: colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 48),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Request Submitted!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Text(
                  "Your card reissue request has been placed successfully. A new card will be dispatched to your verified address shortly.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // close dialog
                      Navigator.pop(context); // back to Card Center
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Done",
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
