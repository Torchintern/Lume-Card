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

  @override
  void initState() {
    super.initState();
    _fetchMandates();
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      const Positioned(
                        bottom: 50,
                        left: 20,
                        child: Text(
                          "Auto Setup History",
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _mandates.isEmpty
                      ? _buildEmptyState(isDark)
                      : RefreshIndicator(
                          onRefresh: _fetchMandates,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _mandates.length,
                            itemBuilder: (context, index) {
                              return _buildMandateCard(_mandates[index], isDark, colorScheme);
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
}
