import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class MandatesScreen extends StatefulWidget {
  const MandatesScreen({super.key});

  @override
  State<MandatesScreen> createState() => _MandatesScreenState();
}

class _MandatesScreenState extends State<MandatesScreen> {
  bool _isLoading = true;
  List<dynamic> _mandates = [];
  bool _needsRefresh = false; // Track if mandates were modified to refresh dashboard

  // ================= HEADER CAROUSEL =================
  late PageController _headerPageController;
  Timer? _headerAutoScrollTimer;
  int _currentHeaderPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchMandates();
    _headerPageController = PageController(initialPage: 400);
    _startHeaderAutoScroll();
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

  Future<void> _fetchMandates() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final res = await ApiService.getMandates(token);
      if (res['mandates'] != null) {
        setState(() {
          _mandates = res['mandates'];
        });
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(int mandateId, String newStatus) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final res = await ApiService.updateMandateStatus(token, mandateId, newStatus);
      if (res['success'] == true) {
        setState(() => _needsRefresh = true);
        _fetchMandates(); // Refresh
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    _headerAutoScrollTimer?.cancel();
    _headerPageController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
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
                      left: 25 * progress,
                      bottom: 25 * progress,
                    ),
                    alignment: Alignment.lerp(
                      Alignment.center,
                      Alignment.bottomLeft,
                      progress,
                    ),
                    child: Text(
                      "Auto Setup History",
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
              child: _isLoading
                  ? SizedBox(
                      height: size.height * 0.5,
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : _mandates.isEmpty
                      ? SizedBox(
                          height: size.height * 0.5,
                          child: _buildEmptyState(isDark),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchMandates,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: _mandates.length,
                            itemBuilder: (context, index) {
                              return _buildMandateCard(
                                  _mandates[index], isDark, colorScheme);
                            },
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.auto_awesome_motion_rounded,
          size: 80,
          color: isDark ? Colors.white24 : Colors.grey[300],
        ),
        const SizedBox(height: 16),
        Text(
          "No Mandates Found",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Set up auto top-up to see them here.",
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white38 : Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildMandateCard(Map<String, dynamic> mandate, bool isDark, ColorScheme colorScheme) {
    bool isActive = mandate['status'] == 'Active';
    bool isPaused = mandate['status'] == 'Paused';
    bool isInactive = mandate['status'] == 'Inactive';

    Color statusColor = isActive ? const Color(0xFF10B981) : (isPaused ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    Color statusBg = statusColor.withOpacity(0.12);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        mandate['status'].toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Text(
                      "ID: ${mandate['id']}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        mandate['mandate_type'] == 'Frequency' ? Icons.calendar_month_rounded : Icons.account_balance_wallet_rounded,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mandate['details'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Recharge: ₹${NumberFormat('#,##,##0').format(mandate['amount'])}",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isInactive) ...[
            Divider(height: 1, color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05)),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _updateStatus(mandate['id'], isActive ? 'Paused' : 'Active'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      child: Text(
                        isActive ? "Pause" : "Resume",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 24, color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05)),
                Expanded(
                  child: InkWell(
                    onTap: () => _updateStatus(mandate['id'], 'Inactive'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildHeaderSlide(int index, ColorScheme colorScheme) {
    switch (index) {
      case 0:
        return _buildSlideBase(
          color1: colorScheme.primary,
          color2: colorScheme.secondary,
          icon: Icons.history_rounded,
          title: "Setup History",
          subtitle: "View and manage all your automated wallet activities.",
        );
      case 1:
        return _buildSlideBase(
          color1: const Color(0xFF1E1B4B),
          color2: const Color(0xFF4338CA),
          icon: Icons.autorenew_rounded,
          title: "Smart Control",
          subtitle: "Easily pause, resume, or cancel any mandate instantly.",
        );
      case 2:
        return _buildSlideBase(
          color1: const Color(0xFF0F172A),
          color2: const Color(0xFF334155),
          icon: Icons.security_rounded,
          title: "Bank Grade",
          subtitle: "All automatic debits are secured through encrypted gateways.",
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
