import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class CardCenterScreen extends StatefulWidget {
  const CardCenterScreen({super.key});

  @override
  State<CardCenterScreen> createState() => _CardCenterScreenState();
}

class _CardCenterScreenState extends State<CardCenterScreen> {
  bool ncmcEnabled = false;
  bool tapPayEnabled = false;
  bool isPinSet = false;
  bool isLocked = false;
  bool isBlocked = false;
  bool isFreezed = false;
  String _maskedCardNumber = "**** **** **** ****";
  bool _isLoading = true;
  String? _authToken;
  String? _orderStatus;

  @override
  void initState() {
    super.initState();
    _fetchCardDetails();
  }

  Future<void> _fetchCardDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");
      _authToken = token;

      if (token == null) {
        setState(() => _isLoading = false);
        return;
      }

      final res = await ApiService.getCardDetails(token);

      if (res.isNotEmpty) {
        final String fullNumber = (res["card_number"] ?? "").toString();
        final String lockStatus = (res["card_lock"] ?? "")
            .toString()
            .toUpperCase();
        final String cardState = (res["card_state"] ?? "")
            .toString()
            .toUpperCase();

        setState(() {
          if (fullNumber.length >= 4) {
            _maskedCardNumber =
                "**** **** **** ${fullNumber.substring(fullNumber.length - 4)}";
          }
          ncmcEnabled = res["ncmc_enabled"] == true;
          tapPayEnabled = res["tap_and_pay_enabled"] == true;
          isPinSet = res["is_pin_set"] == true;
          isLocked = lockStatus == "LOCKED" || res["card_lock"] == true;
          isBlocked = lockStatus == "BLOCKED" || cardState == "BLOCKED";
          isFreezed = res["is_freezed"] == true;
          _orderStatus = (res["order_status"] ?? "").toString().toUpperCase();
          _isLoading = false;
        });

        if (fullNumber.isNotEmpty) {
          await prefs.setString("card_number", fullNumber);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching card details: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePinAction() async {
    if (_authToken == null) return;
    if (_orderStatus != "RECEIVED") {
      _showErrorSnackBar("Physical card must be delivered to manage PIN.");
      return;
    }

    if (!isPinSet) {
      // Direct Set PIN flow
      _showPinEntrySheet(
        title: "Set Card PIN",
        subtitle: "Enter a new 4-digit PIN for your transactions",
      );
    } else {
      // Change PIN flow - requires OTP
      _showOtpVerificationSheet();
    }
  }

  void _showOtpVerificationSheet({VoidCallback? onSuccess}) async {
    if (_authToken == null) return;

    // Send initial OTP
    try {
      final res = await ApiService.cardSendOtp(_authToken!);
      if (res["success"] != true) {
        _showErrorSnackBar("Failed to send OTP. Please try again.");
        return;
      }
      final devOtp = res["dev_otp"];
      if (devOtp != null) debugPrint("DEBUG OTP: $devOtp");
    } catch (e) {
      _showErrorSnackBar("Connectivity error. Try again.");
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OtpVerificationSheet(
        authToken: _authToken!,
        onVerified: () {
          Navigator.pop(context);
          if (onSuccess != null) {
            onSuccess();
          } else {
            _showPinEntrySheet(
              title: "Change Card PIN",
              subtitle: "Enter your new 4-digit transaction PIN",
            );
          }
        },
        onError: (msg) => _showErrorSnackBar(msg),
      ),
    );
  }

  void _showPinEntrySheet({required String title, required String subtitle}) {
    final colorScheme = Theme.of(context).colorScheme;
    final TextEditingController pinController = TextEditingController();
    final TextEditingController confirmPinController = TextEditingController();
    bool isSaving = false;
    bool isConfirmStage = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),
                Icon(
                  isConfirmStage
                      ? Icons.lock_reset_rounded
                      : Icons.lock_outline_rounded,
                  size: 48,
                  color: const Color(0xFF6366F1),
                ),
                const SizedBox(height: 16),
                Text(
                  isConfirmStage ? "Confirm Your PIN" : title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isConfirmStage
                      ? "Re-enter the 4-digit PIN to confirm"
                      : subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: isConfirmStage
                      ? confirmPinController
                      : pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: "* * * *",
                    counterText: "",
                    filled: true,
                    fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 20,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (!isConfirmStage) {
                              if (pinController.text.length != 4) return;
                              setSheetState(() => isConfirmStage = true);
                            } else {
                              if (confirmPinController.text !=
                                  pinController.text) {
                                _showErrorSnackBar("PINs do not match");
                                return;
                              }
                              setSheetState(() => isSaving = true);
                              try {
                                final res = await ApiService.setCardPin(
                                  _authToken!,
                                  pinController.text,
                                );
                                if (res["success"] == true) {
                                  Navigator.pop(context);
                                  setState(() => isPinSet = true);
                                  _showStatusDialog(
                                    "Success",
                                    "Your Card PIN has been successfully updated.",
                                    Icons.check_circle_rounded,
                                  );
                                } else {
                                  _showErrorSnackBar(res["error"]);
                                  setSheetState(() => isSaving = false);
                                }
                              } catch (e) {
                                setSheetState(() => isSaving = false);
                                _showErrorSnackBar("Failed to set PIN");
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            isConfirmStage ? "Finalize PIN" : "Continue",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBlockCardSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isTermsAccepted = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Mini Card Preview in Sheet
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isDark
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFFEEF2FF))
                              .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Image.asset("assets/logos/rupay.png", height: 20),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Prepaid Card",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _maskedCardNumber,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  Text(
                    isBlocked ? "Replace Card" : "Block & Replace",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isBlocked
                        ? "Your card is permanently blocked. Choose 'Replace Card' to issue a new one."
                        : "Permanent loss or theft of card? Choose 'Block Card' to deactivate it forever.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // "Freeze/Unfreeze Card" Button - Only show if not already blocked
                  if (!isBlocked) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _executeToggleFreeze();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: colorScheme.primary.withOpacity(0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          isFreezed ? "Unfreeze Card" : "Freeze Card",
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isFreezed
                          ? "Your card is currently frozen."
                          : "Temporarily freeze your card if you misplaced it.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (isBlocked) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: isTermsAccepted,
                            onChanged: (val) {
                              setSheetState(() {
                                isTermsAccepted = val ?? false;
                              });
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            activeColor: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            children: [
                              Text(
                                "I agree to the ",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(context, '/terms');
                                },
                                  child: Text(
                                    "terms & conditions",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                Text(
                                  " and ",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(context, '/privacy');
                                  },
                                  child: Text(
                                    "privacy policy",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              Text(
                                ".",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // "Block Card" or "Replace Card" Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (isBlocked && !isTermsAccepted)
                          ? null
                          : () async {
                              Navigator.pop(context);
                              if (isBlocked) {
                                await Navigator.pushNamed(context, "/card-reissue");
                                setState(() => _isLoading = true);
                                _fetchCardDetails();
                              } else {
                                _showBlockConfirmationSheet();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBlocked
                            ? colorScheme.primary
                            : Colors.redAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            colorScheme.surfaceContainerHighest,
                        disabledForegroundColor: colorScheme.onSurfaceVariant,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        isBlocked ? "Replace Card" : "Block Card",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showBlockConfirmationSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withOpacity(0.9)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Block Card Permanently?",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "This action cannot be undone. Your card will be permanently deactivated and cannot be used again.",
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showBlockPinVerificationSheet();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Block Card",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBlockPinVerificationSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController _pinController = TextEditingController();
    bool _isLoading = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 44,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Enter PIN to Block Card",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Please enter your 4-digit PIN to confirm permanent card blocking.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      hintText: "••••",
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      counterText: "",
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: colorScheme.outlineVariant.withOpacity(
                                  0.5,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    if (_pinController.text.length != 4) {
                                      _showErrorSnackBar(
                                        "Please enter a 4-digit PIN.",
                                      );
                                      return;
                                    }
                                    setState(() {
                                      _isLoading = true;
                                    });

                                    // Verification logic would go here
                                    // For now, we proceed to call the blocking API
                                    await Future.delayed(
                                      const Duration(milliseconds: 800),
                                    );

                                    if (mounted) {
                                      Navigator.pop(context); // Close PIN sheet
                                      await _blockCardLogic(
                                        _pinController.text,
                                      ); // Call the actual blocking logic
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "Confirm Block",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _blockCardLogic(String pin) async {
    if (_authToken == null) return;
    try {
      final res = await ApiService.blockCard(_authToken!, pin);
      if (res["success"] == true) {
        setState(() {
          isBlocked = true;
        });
        _showStatusDialog(
          "Card Blocked",
          "Your card has been permanently blocked.",
          Icons.block_rounded,
        );
      } else {
        _showErrorSnackBar(res["error"] ?? "Failed to block card");
      }
    } catch (e) {
      _showErrorSnackBar("Error connecting to server");
    }
  }

  Future<void> _executeToggleFreeze() async {
    if (_authToken == null) return;
    final bool targetFreezeStatus = !isFreezed;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = targetFreezeStatus
          ? await ApiService.freezeCard(_authToken!)
          : await ApiService.unfreezeCard(_authToken!);

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (res["success"] == true) {
        setState(() => isFreezed = targetFreezeStatus);
        _showStatusDialog(
          targetFreezeStatus ? "Card Frozen" : "Card Unfrozen",
          targetFreezeStatus
              ? "Your card has been temporarily frozen successfully."
              : "Your card is now unfrozen and active.",
          targetFreezeStatus
              ? Icons.ac_unit_rounded
              : Icons.local_fire_department_rounded,
        );
      } else {
        _showErrorSnackBar("Failed to update card status");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar("Connectivity error. Try again.");
    }
  }

  Future<void> _executeToggleLock() async {
    if (_authToken == null) return;
    final bool targetLockStatus = !isLocked;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = targetLockStatus
          ? await ApiService.lockCard(_authToken!)
          : await ApiService.unlockCard(_authToken!);

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (res["success"] == true) {
        setState(() => isLocked = targetLockStatus);
        _showStatusDialog(
          targetLockStatus ? "Card Locked" : "Card Unlocked",
          targetLockStatus
              ? "Your card has been temporarily locked successfully."
              : "Your card is now active and ready for transactions.",
          targetLockStatus ? Icons.lock_rounded : Icons.lock_open_rounded,
        );
      } else {
        _showErrorSnackBar("Failed to update card status");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar("Connectivity error. Try again.");
    }
  }

  void _showLockCardSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  size: 44,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isLocked ? "Unlock Card?" : "Lock Card?",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isLocked
                    ? "Unlocking will re-enable all your card transactions instantly."
                    : "Your card will be temporarily disabled for ATM, POS and online transactions.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: colorScheme.outlineVariant.withOpacity(0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _executeToggleLock();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isLocked ? "Yes, Unlock" : "Yes, Lock",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleNcmc(bool enabled) async {
    if (_authToken == null) return;
    setState(() => ncmcEnabled = enabled);
    try {
      final res = await ApiService.toggleNcmc(_authToken!, enabled);
      if (res["success"] == true) {
        _showStatusDialog(
          enabled ? "NCMC Enabled" : "NCMC Disabled",
          enabled
              ? "You can now use your card for transit payments."
              : "Transit payments have been disabled for this card.",
          Icons.directions_bus_rounded,
        );
      } else {
        setState(() => ncmcEnabled = !enabled);
        _showErrorSnackBar("Failed to update NCMC setting");
      }
    } catch (e) {
      setState(() => ncmcEnabled = !enabled);
      _showErrorSnackBar("Error: Could not connect to server");
    }
  }

  Future<void> _toggleTapPay(bool enabled) async {
    if (_authToken == null) return;

    if (enabled) {
      // Show limit picker before enabling
      _showTapPayLimitSheet();
    } else {
      // Disable instantly — no limit needed
      setState(() => tapPayEnabled = false);
      try {
        final res = await ApiService.toggleTapPay(_authToken!, false, limit: 0);
        if (res["success"] == true) {
          _showStatusDialog(
            "Tap & Pay Disabled",
            "Contactless payments have been disabled for this card.",
            Icons.nfc_rounded,
          );
        } else {
          setState(() => tapPayEnabled = true);
          _showErrorSnackBar("Failed to disable Tap & Pay");
        }
      } catch (e) {
        setState(() => tapPayEnabled = true);
        _showErrorSnackBar("Error: Could not connect to server");
      }
    }
  }

  void _showTapPayLimitSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    double currentLimit = 5000;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  top: 24,
                  left: 24,
                  right: 24,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.nfc_rounded, color: colorScheme.primary, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Enable Tap & Pay",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Set a contactless spending limit per transaction",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "₹ ${currentLimit.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: colorScheme.primary,
                        inactiveTrackColor: colorScheme.primary.withOpacity(0.15),
                        thumbColor: colorScheme.primary,
                        overlayColor: colorScheme.primary.withOpacity(0.2),
                        trackHeight: 6,
                      ),
                      child: Slider(
                        value: currentLimit,
                        min: 500,
                        max: 25000,
                        divisions: 49,
                        onChanged: (v) => setSheetState(() => currentLimit = v),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: currentLimit > 0 ? () async {
                          Navigator.pop(ctx);
                          setState(() => tapPayEnabled = true);
                          try {
                            final res = await ApiService.toggleTapPay(
                              _authToken!, true,
                              limit: currentLimit.toInt(),
                            );
                            if (res["success"] == true) {
                              _showStatusDialog(
                                "Tap & Pay Enabled",
                                "You can now make contactless payments up to ₹${currentLimit.toInt()} per transaction.",
                                Icons.nfc_rounded,
                              );
                            } else {
                              setState(() => tapPayEnabled = false);
                              _showErrorSnackBar("Failed to enable Tap & Pay");
                            }
                          } catch (e) {
                            setState(() => tapPayEnabled = false);
                            _showErrorSnackBar("Error: Could not connect to server");
                          }
                        } : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Enable & Save",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showStatusDialog(String title, String message, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.85),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: colorScheme.primary, size: 32),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Great!",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
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

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          "Card Center",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Premium Card Preview
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF1E293B),
                                    const Color(0xFF0F172A),
                                  ]
                                : [const Color(0xFFF1F5F9), Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.3 : 0.05,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: colorScheme.outlineVariant.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Image.asset(
                                "assets/logos/rupay.png",
                                height: 24,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Lume Prepaid Card",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.onSurface,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _maskedCardNumber,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isLocked || isBlocked || isFreezed)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: isBlocked || isLocked
                                      ? Colors.redAccent.withOpacity(0.8)
                                      : Colors.blueAccent.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isBlocked
                                          ? Icons.block_rounded
                                          : isFreezed
                                          ? Icons.ac_unit_rounded
                                          : Icons.lock_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isBlocked
                                          ? "BLOCKED"
                                          : isFreezed
                                          ? "FROZEN"
                                          : "LOCKED",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
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

                  const SizedBox(height: 32),

                  _buildSectionHeader("QUICK CONTROLS"),
                  _tileSwitch(
                    Icons.directions_bus_rounded,
                    "NCMC (Transit)",
                    "Enable for metro/bus payments",
                    ncmcEnabled,
                    (v) => _toggleNcmc(v),
                    colorScheme,
                  ),
                  _tileSwitch(
                    Icons.nfc_rounded,
                    "Tap & Pay (NFC)",
                    "Pay at offline stores instantly",
                    tapPayEnabled,
                    (v) => _toggleTapPay(v),
                    colorScheme,
                  ),

                  const SizedBox(height: 24),
                  _buildSectionHeader("SECURITY & SETTINGS"),
                  _buildActionTile(
                    Icons.pin_rounded,
                    isPinSet ? "Card PIN" : "Set Card PIN",
                    isPinSet
                        ? "Change your ATM/POS PIN"
                        : "Setup your card PIN securely",
                    colorScheme,
                    onTap: _handlePinAction,
                    isEnabled: _orderStatus == "RECEIVED",
                  ),
                  _buildActionTile(
                    isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                    isLocked ? "Unlock this Card" : "Lock this Card",
                    isLocked
                        ? "Tap to reactivate your card"
                        : "Temporarily freeze your card",
                    colorScheme,
                    textColor: isLocked ? colorScheme.primary : null,
                    onTap: _showLockCardSheet,
                    isEnabled: true,
                  ),
                  _buildActionTile(
                    Icons.block_rounded,
                    isBlocked ? "Replace" : "Block & Replace",
                    "Permanent loss or theft",
                    colorScheme,
                    textColor: Colors.redAccent,
                    onTap: () async {
                      if (_orderStatus == "RECEIVED") {
                        if (isBlocked) {
                          // Take OTP verification first
                          _showOtpVerificationSheet(
                            onSuccess: () async {
                              // Once verified, open reissue screen
                              await Navigator.pushNamed(
                                context,
                                "/card-reissue",
                              );
                              if (mounted) {
                                setState(() => _isLoading = true);
                                _fetchCardDetails();
                              }
                            },
                          );
                        } else {
                          // Need to block first, then user can reissue
                          _showBlockCardSheet();
                        }
                      } else {
                        _showErrorSnackBar(
                          "Physical card must be delivered to block/replace.",
                        );
                      }
                    },
                    isEnabled: _orderStatus == "RECEIVED",
                  ),
                  _buildActionTile(
                    Icons.tune_rounded,
                    "Controls & Limits",
                    "Manage spending thresholds",
                    colorScheme,
                    onTap: () async {
                      // Navigator.pushNamed returns a Future
                      await Navigator.pushNamed(context, "/card-controls");
                      // When returning, refresh the details to sync changes like Tap & Pay
                      if (mounted) {
                        setState(() => _isLoading = true);
                        _fetchCardDetails();
                      }
                    },
                    isEnabled: true,
                  ),

                  const SizedBox(height: 24),
                  _buildSectionHeader("MORE INFORMATION"),
                  _buildActionTile(
                    Icons.card_giftcard_rounded,
                    "Card Benefits",
                    "View lounge and offer access",
                    colorScheme,
                    onTap: () => Navigator.pushNamed(context, "/card-benefits"),
                    isEnabled: true,
                  ),
                  _buildActionTile(
                    Icons.help_outline_rounded,
                    "Support",
                    "Need help with your card?",
                    colorScheme,
                    onTap: () => Navigator.pushNamed(context, "/help-support"),
                    isEnabled: true, // Always allowed even if blocked
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle,
    ColorScheme colorScheme, {
    VoidCallback? onTap,
    Color? textColor,
    bool isEnabled = false,
  }) {
    // Support and Replace tiles are always enabled even if blocked
    final bool effectiveEnabled = isEnabled && (!isBlocked || title == "Support" || title.contains("Replace"));

    return Opacity(
      opacity: effectiveEnabled ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
        child: ListTile(
          onTap: effectiveEnabled ? onTap : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (textColor ?? colorScheme.primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: textColor ?? colorScheme.primary,
              size: 22,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textColor ?? colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Widget _tileSwitch(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    ColorScheme colorScheme,
  ) {
    return Opacity(
      opacity: isBlocked ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
          trailing: Switch(
            value: value,
            onChanged: isBlocked ? null : onChanged,
            activeColor: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  }

class _OtpVerificationSheet extends StatefulWidget {
  final String authToken;
  final VoidCallback onVerified;
  final Function(String) onError;

  const _OtpVerificationSheet({
    required this.authToken,
    required this.onVerified,
    required this.onError,
  });

  @override
  State<_OtpVerificationSheet> createState() => _OtpVerificationSheetState();
}

class _OtpVerificationSheetState extends State<_OtpVerificationSheet> {
  final TextEditingController otpController = TextEditingController();
  bool isVerifying = false;
  int timerSeconds = 30;
  Timer? resendTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() => timerSeconds = 30);
    resendTimer?.cancel();
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timerSeconds == 0) {
        timer.cancel();
      } else {
        if (mounted) {
          setState(() => timerSeconds--);
        }
      }
    });
  }

  @override
  void dispose() {
    resendTimer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  Future<void> _resendOtp() async {
    try {
      final res = await ApiService.cardSendOtp(widget.authToken);
      if (res["success"] == true) {
        _startTimer();
        final devOtp = res["dev_otp"];
        if (devOtp != null) debugPrint("DEBUG OTP: $devOtp");
      } else {
        widget.onError(res["error"] ?? "Failed to resend OTP");
      }
    } catch (e) {
      widget.onError("Resend failed");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(
              Icons.security_rounded,
              size: 48,
              color: Color(0xFF6366F1),
            ),
            const SizedBox(height: 16),
            const Text(
              "Security Verification",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              "Enter the OTP sent to your registered mobile number",
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "0 0 0 0 0 0",
                counterText: "",
                filled: true,
                fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isVerifying
                    ? null
                    : () async {
                        setState(() => isVerifying = true);
                        try {
                          final res = await ApiService.cardVerifyOtp(
                            widget.authToken,
                            otpController.text,
                          );
                          if (res["success"] == true) {
                            widget.onVerified();
                          } else {
                            widget.onError(res["error"] ?? "Invalid OTP");
                            setState(() => isVerifying = false);
                          }
                        } catch (e) {
                          setState(() => isVerifying = false);
                          widget.onError("Verification failed");
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isVerifying
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Verify OTP",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: timerSeconds == 0 ? _resendOtp : null,
              child: Text(
                timerSeconds == 0 ? "Resend OTP" : "Resend in ${timerSeconds}s",
                style: TextStyle(
                  color: timerSeconds == 0
                      ? const Color(0xFF6366F1)
                      : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
