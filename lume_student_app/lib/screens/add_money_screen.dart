import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AddMoneyScreen extends StatefulWidget {
  const AddMoneyScreen({super.key});

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  final TextEditingController _amountController = TextEditingController(text: "100");
  double _availableBalance = 0.0;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _needsRefresh = false; // Tracks if dashboard needs refresh on return

  // ================= HEADER CAROUSEL =================
  late PageController _headerPageController;
  Timer? _headerAutoScrollTimer;
  int _currentHeaderPage = 0;

  // ================= SCROLL & FOCUS =================
  final ScrollController _scrollController = ScrollController();
  final FocusNode _amountFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _headerPageController = PageController(initialPage: 400);
    _startHeaderAutoScroll();

    // Auto-scroll on focus
    _amountFocusNode.addListener(() {
      if (_amountFocusNode.hasFocus) {
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
    });
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

  Future<void> _loadBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");
      if (token != null && token.isNotEmpty) {
        final cardRes = await ApiService.getCardDetails(token);
        if (cardRes.isNotEmpty && mounted) {
          setState(() {
            _availableBalance = (cardRes["balance"] ?? 0.0).toDouble();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading balance: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _processPayment() async {
    final amountText = _amountController.text.replaceAll(',', '');
    final double amount = double.tryParse(amountText) ?? 0.0;

    if (amount <= 0) {
      _showErrorDialog("Invalid Amount", "Please enter a valid amount greater than zero.");
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");
      if (token != null && token.isNotEmpty) {
        // We pass "success" to immediately reflect the balance via the backend.
        final res = await ApiService.addMoney(token, amount, "success");
        if (res["status"] == "success" || res["status"] == "pending" || res["message"] != null) {
          if (mounted) {
            _needsRefresh = true;
            _loadBalance(); // Update balance immediately in UI
            _showSuccessDialog(amount);
          }
        } else {
          if (mounted) {
            _showErrorDialog("Payment Failed", res["error"] ?? "Failed to add money. Please try again.");
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog("Connection Error", "An error occurred while processing your payment. Please ensure you have a stable connection and try again.");
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _headerAutoScrollTimer?.cancel();
    _headerPageController.dispose();
    _scrollController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _addAmount(int amount) {
    int current = int.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    _amountController.text = (current + amount).toString();
  }

  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double limitRemaining = 200000.0 - _availableBalance;
    if (limitRemaining < 0) limitRemaining = 0;

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          CustomScrollView(
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
                centerTitle: true,
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
                          left: 25 * (1 - progress) + (25 * progress),
                          bottom: 25 * progress,
                        ),
                        alignment: Alignment.lerp(
                          Alignment.center,
                          Alignment.bottomLeft,
                          progress,
                        ),
                        child: Text(
                          "Top Up Wallet",
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 180),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : const Color(0xFFE2E8F0).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                "Available Balance: ₹${NumberFormat('#,##,##0.00').format(_availableBalance)}",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF64748B),
                                ),
                              ),
                      ),
                      const SizedBox(height: 50),
                      TextField(
                        controller: _amountController,
                        focusNode: _amountFocusNode,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        scrollPadding: const EdgeInsets.only(bottom: 250),
                        cursorColor: colorScheme.primary,
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -1.5,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Monthly limit left: ₹${NumberFormat('#,##,##0.00').format(limitRemaining)}",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: limitRemaining == 0
                              ? Colors.redAccent.withOpacity(isDark ? 0.8 : 1.0)
                              : (isDark
                                  ? Colors.white38
                                  : const Color(0xFF94A3B8)),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _quickAddButton("+ ₹100", 100),
                          const SizedBox(width: 12),
                          _quickAddButton("+ ₹500", 500),
                          const SizedBox(width: 12),
                          _quickAddButton("+ ₹1,000", 1000),
                        ],
                      ),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: () async {
                          final result =
                              await Navigator.pushNamed(context, '/set-mandate');
                          if (result is Map && result['refresh'] == true) {
                            _needsRefresh = true;
                            // If backend returned new balance, apply it immediately
                            final double? newBal =
                                (result['newBalance'] as num?)?.toDouble();
                            if (newBal != null && mounted) {
                              setState(() => _availableBalance = newBal);
                            } else {
                              _loadBalance(); // Fallback: re-fetch
                            }
                          } else if (result == true) {
                            _needsRefresh = true;
                            _loadBalance();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.04)
                                : colorScheme.primary.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : colorScheme.primary.withOpacity(0.12),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? colorScheme.primary.withOpacity(0.2)
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: isDark
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: colorScheme.primary
                                                .withOpacity(0.1),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Icon(
                                  Icons.autorenew_rounded,
                                  color: colorScheme.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Set Auto Top-Up",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: colorScheme.onSurface,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Never run out of balance",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white54
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "SETUP",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom Payment Section
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(24, 16, 24,
                  MediaQuery.of(context).padding.bottom + 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _showOrderSummary,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: colorScheme.primary.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        "View order summary",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ListenableBuilder(
                        listenable: _amountController,
                        builder: (context, _) {
                          int currentAmount = int.tryParse(
                                  _amountController.text.replaceAll(',', '')) ??
                              0;
                          return ElevatedButton(
                            onPressed: (_isProcessing || currentAmount <= 0)
                                ? null
                                : _processPayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: currentAmount <= 0
                                  ? (isDark
                                      ? Colors.white12
                                      : const Color(0xFFE2E8F0))
                                  : colorScheme.primary,
                              foregroundColor: currentAmount <= 0
                                  ? (isDark
                                      ? Colors.white38
                                      : const Color(0xFF94A3B8))
                                  : colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                            ),
                            child: _isProcessing
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    "Pay ₹${NumberFormat('#,##,##0').format(currentAmount)}.00",
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                          );
                        }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderSummary() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountText = _amountController.text.replaceAll(',', '');
    final int amount = int.tryParse(amountText) ?? 0;
    final String formattedAmount = "₹${NumberFormat('#,##,##0.00').format(amount)}";

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 12,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Payment Summary",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Amount",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    formattedAmount,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                height: 1,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Payment",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    formattedAmount,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
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

  void _showSuccessDialog(double amount) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (dialogContext, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.elasticOut.transform(anim1.value),
          child: Opacity(
            opacity: anim1.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: _buildSuccessContent(dialogContext, amount),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuccessContent(BuildContext dialogContext, double amount) {
    final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
    final colorScheme = Theme.of(dialogContext).colorScheme;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(isDark ? 0.2 : 0.1),
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
            "Top Up Successful!",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "₹${NumberFormat('#,##,##0.00').format(amount)} has been added to your wallet securely.",
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
                if (mounted) {
                  Navigator.pop(context, true); // Return to dashboard, triggering refresh
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
                "Back to Home",
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
    );
  }

  void _showErrorDialog(String title, String message) {
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
          child: Opacity(
            opacity: anim1.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: _buildErrorContent(dialogContext, title, message),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorContent(BuildContext dialogContext, String title, String message) {
    final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
    final colorScheme = Theme.of(dialogContext).colorScheme;

    return Container(
      padding: const EdgeInsets.all(32),
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
    );
  }

  Widget _quickAddButton(String label, int amount) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _addAmount(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? colorScheme.primary.withOpacity(0.15) : colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? colorScheme.primary.withOpacity(0.3) : colorScheme.primary.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isDark ? colorScheme.primary.withOpacity(0.9) : colorScheme.primary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSlide(int index, ColorScheme colorScheme) {
    switch (index) {
      case 0:
        return _buildSlideBase(
          color1: colorScheme.primary,
          color2: colorScheme.secondary,
          icon: Icons.account_balance_wallet_rounded,
          title: "Wallet Security",
          subtitle: "Funds are encrypted and protected by bank-grade security.",
        );
      case 1:
        return _buildSlideBase(
          color1: const Color(0xFF1E1B4B),
          color2: const Color(0xFF4338CA),
          icon: Icons.bolt_rounded,
          title: "Instant Credit",
          subtitle: "Money is added to your card balance instantly after payment.",
        );
      case 2:
        return _buildSlideBase(
          color1: const Color(0xFF0F172A),
          color2: const Color(0xFF334155),
          icon: Icons.confirmation_number_rounded,
          title: "Smart Rewards",
          subtitle: "Unlock exclusive vouchers and cashbacks on every top-up.",
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
