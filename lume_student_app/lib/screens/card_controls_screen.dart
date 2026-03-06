import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class CardControlsScreen extends StatefulWidget {
  const CardControlsScreen({super.key});

  @override
  State<CardControlsScreen> createState() => _CardControlsScreenState();
}

class _CardControlsScreenState extends State<CardControlsScreen> {
  bool _isLoading = true;
  String? _authToken;
  bool _hasUnsavedChanges = false;

  // Initial values for comparison
  late bool _initialPosEnabled, _initialOnlineEnabled, _initialContactlessEnabled, _initialTokenisedEnabled, _initialAtmEnabled;
  late int _initialPosLimit, _initialOnlineLimit, _initialContactlessLimit, _initialTokenisedLimit, _initialAtmLimit;

  // Controls State
  bool _posEnabled = false;
  int _posLimit = 0;
  
  bool _onlineEnabled = false;
  int _onlineLimit = 0;
  
  bool _contactlessEnabled = false;
  int _contactlessLimit = 0;
  
  bool _tokenisedEnabled = false;
  int _tokenisedLimit = 0;

  bool _atmEnabled = false;
  int _atmLimit = 0;

  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _loadCardControls();
  }

  Future<void> _loadCardControls() async {
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
        _posEnabled = res["pos_enabled"] == true;
        _posLimit = res["pos_limit"] ?? 0;
        _onlineEnabled = res["online_enabled"] == true;
        _onlineLimit = res["online_limit"] ?? 0;
        _contactlessEnabled = res["tap_and_pay_enabled"] == true;
        _contactlessLimit = res["contactless_limit"] ?? 0;
        _tokenisedEnabled = res["tokenised_enabled"] == true;
        _tokenisedLimit = res["tokenised_limit"] ?? 0;
        _atmEnabled = res["atm_enabled"] == true;
        _atmLimit = res["atm_limit"] ?? 0;

        _initialPosEnabled = _posEnabled; _initialPosLimit = _posLimit;
        _initialOnlineEnabled = _onlineEnabled; _initialOnlineLimit = _onlineLimit;
        _initialContactlessEnabled = _contactlessEnabled; _initialContactlessLimit = _contactlessLimit;
        _initialTokenisedEnabled = _tokenisedEnabled; _initialTokenisedLimit = _tokenisedLimit;
        _initialAtmEnabled = _atmEnabled; _initialAtmLimit = _atmLimit;

        final String cardState = (res["card_state"] ?? "").toString().toUpperCase();
        final String lockStatus = (res["card_lock"] ?? "").toString().toUpperCase();
        _isBlocked = cardState == "BLOCKED" || lockStatus == "BLOCKED";
        
        setState(() => _isLoading = false);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading controls: $e");
      setState(() => _isLoading = false);
    }
  }

  void _checkChanges() {
    final changed = _posEnabled != _initialPosEnabled || _posLimit != _initialPosLimit ||
                    _onlineEnabled != _initialOnlineEnabled || _onlineLimit != _initialOnlineLimit ||
                    _contactlessEnabled != _initialContactlessEnabled || _contactlessLimit != _initialContactlessLimit ||
                    _tokenisedEnabled != _initialTokenisedEnabled || _tokenisedLimit != _initialTokenisedLimit ||
                    _atmEnabled != _initialAtmEnabled || _atmLimit != _initialAtmLimit;
    setState(() => _hasUnsavedChanges = changed);
  }

  void _showLimitBottomSheet(String title, int currentLimit, bool isEnabled, Function(bool, int) onSave, {int maxLimit = 200000}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LimitSettingsSheet(
        title: title,
        initialLimit: currentLimit == 0 ? (maxLimit >= 50000 ? 50000 : maxLimit) : currentLimit,
        isDisabling: isEnabled,
        maxLimit: maxLimit,
        onSave: (enabled, limit) {
          onSave(enabled, limit);
          _checkChanges();
        },
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _LeaveConfirmationSheet(onSave: () async {
        Navigator.pop(context, false);
        await _saveChanges();
      }),
    );
    
    return result ?? false;
  }

  Future<void> _saveChanges() async {
    if (_authToken == null) return;
    setState(() => _isLoading = true);
    
    try {
      // Hit the API to save limits to DB
      final reqBody = {
        "pos_enabled": _posEnabled,
        "pos_limit": _posLimit,
        "online_enabled": _onlineEnabled,
        "online_limit": _onlineLimit,
        "tap_and_pay_enabled": _contactlessEnabled,
        "contactless_limit": _contactlessLimit,
        "tokenised_enabled": _tokenisedEnabled,
        "tokenised_limit": _tokenisedLimit,
        "atm_enabled": _atmEnabled,
        "atm_limit": _atmLimit,
      };
      
      final dynamic response = await ApiService.updateCardControls(_authToken!, reqBody);
      
      if (response != null && response["success"] == true) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasUnsavedChanges = false;
            // Update initials to current
            _initialPosEnabled = _posEnabled; _initialPosLimit = _posLimit;
            _initialOnlineEnabled = _onlineEnabled; _initialOnlineLimit = _onlineLimit;
            _initialContactlessEnabled = _contactlessEnabled; _initialContactlessLimit = _contactlessLimit;
            _initialTokenisedEnabled = _tokenisedEnabled; _initialTokenisedLimit = _tokenisedLimit;
            _initialAtmEnabled = _atmEnabled; _initialAtmLimit = _atmLimit;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Changes saved successfully"),
              backgroundColor: Color(0xFF6366F1),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception("Failed to update controls");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar("Failed to save changes");
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: Stack(
          children: [
            Container(
              height: size.height * 0.3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildPremiumHeader(context),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                      ),
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
                            child: Opacity(
                              opacity: _isBlocked ? 0.6 : 1.0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.visibility_off_outlined, color: Color(0xFF6366F1), size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text("These controls apply only to domestic transactions", style: TextStyle(color: const Color(0xFF6366F1).withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildControlTile(
                                    context,
                                    icon: Icons.storefront_rounded,
                                    title: "POS (In-store)",
                                    limit: _posLimit,
                                    value: _posEnabled,
                                    onChanged: _isBlocked ? null : () => _showLimitBottomSheet("POS (In-store)", _posLimit, _posEnabled, (e, l) => setState(() { _posEnabled = e; _posLimit = l; })),
                                  ),
                                  _buildControlTile(
                                    context,
                                    icon: Icons.shopping_cart_outlined,
                                    title: "Online/Ecom",
                                    limit: _onlineLimit,
                                    value: _onlineEnabled,
                                    onChanged: _isBlocked ? null : () => _showLimitBottomSheet("Online/Ecom", _onlineLimit, _onlineEnabled, (e, l) => setState(() { _onlineEnabled = e; _onlineLimit = l; })),
                                  ),
                                  _buildControlTile(
                                    context,
                                    icon: Icons.contactless_outlined,
                                    title: "Contactless",
                                    limit: _contactlessLimit,
                                    value: _contactlessEnabled,
                                    onChanged: _isBlocked ? null : () => _showLimitBottomSheet("Contactless", _contactlessLimit, _contactlessEnabled, (e, l) => setState(() { _contactlessEnabled = e; _contactlessLimit = l; })),
                                  ),
                                  _buildControlTile(
                                    context,
                                    icon: Icons.security_rounded,
                                    title: "Tokenised",
                                    limit: _tokenisedLimit,
                                    value: _tokenisedEnabled,
                                    onChanged: _isBlocked ? null : () => _showLimitBottomSheet("Tokenised", _tokenisedLimit, _tokenisedEnabled, (e, l) => setState(() { _tokenisedEnabled = e; _tokenisedLimit = l; })),
                                  ),
                                  _buildControlTile(
                                    context,
                                    icon: Icons.atm_rounded,
                                    title: "ATM Withdrawal",
                                    limit: _atmLimit,
                                    value: _atmEnabled,
                                    onChanged: _isBlocked ? null : () => _showLimitBottomSheet("ATM Withdrawal", _atmLimit, _atmEnabled, (e, l) => setState(() { _atmEnabled = e; _atmLimit = l; }), maxLimit: 20000),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isLoading && _hasUnsavedChanges)
            Positioned(
              left: 24, right: 24, bottom: 30,
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isBlocked ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isBlocked ? Colors.grey.shade300 : colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 10,
                    shadowColor: colorScheme.primary.withOpacity(0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Save changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5)),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () async {
                final result = await _onWillPop();
                if (result && context.mounted) Navigator.pop(context);
              },
            ),
          ),
          const Text("Card controls & limits", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildControlTile(BuildContext context, {required IconData icon, required String title, required int limit, required bool value, required VoidCallback? onChanged}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: InkWell(
        onTap: onChanged,
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Text(
                    value ? "Limit: ₹${limit.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}" : "Disabled",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: value ? (isDark ? Colors.white70 : Colors.black87) : Colors.grey),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: (v) => onChanged?.call(),
              activeColor: colorScheme.primary,
              activeTrackColor: colorScheme.primary.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitSettingsSheet extends StatefulWidget {
  final String title;
  final int initialLimit;
  final bool isDisabling;
  final int maxLimit;
  final Function(bool, int) onSave;

  const _LimitSettingsSheet({required this.title, required this.initialLimit, required this.isDisabling, required this.maxLimit, required this.onSave});

  @override
  State<_LimitSettingsSheet> createState() => _LimitSettingsSheetState();
}

class _LimitSettingsSheetState extends State<_LimitSettingsSheet> {
  late double _currentLimit;

  @override
  void initState() {
    super.initState();
    _currentLimit = widget.initialLimit.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 24),
          Text(widget.isDisabling ? "Disable ${widget.title}?" : "Enable ${widget.title}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          
          if (widget.isDisabling) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
              child: const Text(
                "Are you sure you want to disable this feature? Your transaction limit will be removed.", 
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave(false, 0);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: const Text("Disable & Save", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
              child: const Text(
                "Set transaction limit to enable this feature", 
                style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
              child: Text("₹ ${_currentLimit.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1E293B))),
            ),
            const SizedBox(height: 40),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: colorScheme.primary,
                inactiveTrackColor: colorScheme.primary.withOpacity(0.1),
                thumbColor: colorScheme.primary,
                overlayColor: colorScheme.primary.withOpacity(0.2),
                trackHeight: 6,
              ),
              child: Slider(
                value: _currentLimit,
                min: 0,
                max: widget.maxLimit.toDouble(),
                divisions: widget.maxLimit ~/ 1000, // 1k steps
                onChanged: (v) => setState(() => _currentLimit = v),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _currentLimit > 0 ? () {
                  widget.onSave(true, _currentLimit.toInt());
                  Navigator.pop(context);
                } : null,
                style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: const Text("Enable & Save", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _LeaveConfirmationSheet extends StatelessWidget {
  final VoidCallback onSave;

  const _LeaveConfirmationSheet({required this.onSave});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.warning_amber_rounded, color: colorScheme.primary, size: 40),
          ),
          const SizedBox(height: 24),
          const Text("Leave without saving?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text("You have unsaved changes. If you leave now, they will be lost.", textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15, height: 1.5)),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: const Text("Save changes", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 56,
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("I'll do it later", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

