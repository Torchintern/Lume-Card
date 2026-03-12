import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../providers/settings_provider.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  late PageController _headerPageController;
  Timer? _headerAutoScrollTimer;
  int _currentHeaderPage = 0;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _headerAutoScrollTimer?.cancel();
    _headerPageController.dispose();
    super.dispose();
  }

  Future<void> _handleAppLockToggle(bool value, SettingsProvider settings) async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (canAuthenticate) {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: value 
              ? 'Please authenticate to enable App Lock' 
              : 'Please authenticate to disable App Lock',
          persistAcrossBackgrounding: true,
          biometricOnly: false,
        );

        if (didAuthenticate) {
          await settings.setAppLock(value);
        } else {
          // Silent on cancel (didAuthenticate is false when user cancels)
          return;
        }
      } else {
        // Fallback for devices without bio/pin (though unlikely for pin)
        await settings.setAppLock(value);
      }
    } on PlatformException catch (e) {
      debugPrint("Auth platform error: ${e.code} - ${e.message}");
      final code = e.code.toLowerCase();
      if (code.contains('cancel') || code.contains('notavailable') || code == 'auth_in_progress') {
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.message ?? e.code}")),
        );
      }
    } catch (e) {
      debugPrint("Auth error: $e");
      if (e.toString().toLowerCase().contains('cancel')) return;
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: ${e.toString()}")),
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Dynamic Premium Header
              SliverAppBar(
                expandedHeight: size.height * 0.32,
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
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  expandedTitleScale: 1.0,
                  titlePadding: EdgeInsets.zero,
                  title: LayoutBuilder(
                    builder: (context, constraints) {
                      final double top = constraints.biggest.height;
                      final double expandedHeight = size.height * 0.32;
                      final double collapsedHeight =
                          MediaQuery.of(context).padding.top + kToolbarHeight;
                      final double delta = expandedHeight - collapsedHeight;
                      final double progress =
                          ((top - collapsedHeight) / delta).clamp(0.0, 1.0);

                      final double fontSize = 18 + (14 * progress);

                      return Container(
                        padding: EdgeInsets.only(
                          left: 25 * (1 - progress) + (20 * progress),
                          bottom: 25 * progress,
                        ),
                        alignment: Alignment.lerp(
                          Alignment.center,
                          Alignment.bottomLeft,
                          progress,
                        ),
                        child: Text(
                          "App Settings",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1 * progress,
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

                      // Overlay Gradient for text readability
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),

                      // Indicators
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 20,
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
                                color: Colors.white.withOpacity(_currentHeaderPage == index ? 0.9 : 0.4),
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
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                  ),
                ),
              ),

              // Content Area
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                  child: Column(
                    children: [
                      _sectionTitle(context, "GENERAL"),
                      _switchTile(
                        icon: Icons.notifications_rounded,
                        color: Colors.orange,
                        title: "Notifications",
                        subtitle: "Manage push notifications",
                        value: settings.notificationsEnabled,
                        onChanged: (v) => settings.setNotifications(v),
                        context: context,
                      ),
                      _selectorTile(
                        icon: Icons.palette_rounded,
                        color: Colors.purple,
                        title: "Theme",
                        subtitle: settings.themeModeString,
                        onTap: () => _showThemePicker(context, settings),
                        context: context,
                      ),
                      _selectorTile(
                        icon: Icons.language_rounded,
                        color: Colors.blue,
                        title: "Language",
                        subtitle: settings.language,
                        onTap: () => _showLanguagePicker(context, settings),
                        context: context,
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle(context, "SECURITY"),
                      _switchTile(
                        icon: Icons.fingerprint_rounded,
                        color: Colors.blue,
                        title: "Biometric Lock",
                        subtitle: "Unlock app with your fingerprint",
                        value: settings.appLockEnabled,
                        onChanged: (v) => _handleAppLockToggle(v, settings),
                        context: context,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// ---------- UI COMPONENTS ----------

  Widget _sectionTitle(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 20),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required BuildContext context,
  }) {
    return _card(
      icon,
      color,
      title,
      subtitle,
      Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: color.withValues(alpha: 0.5),
        activeThumbColor: color,
      ),
      context: context,
    );
  }

  Widget _selectorTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return _card(
      icon,
      color,
      title,
      subtitle,
      Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
      onTap: onTap,
      context: context,
    );
  }

  Widget _card(IconData icon, Color color, String title, String subtitle, Widget trailing, {VoidCallback? onTap, required BuildContext context}) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Exact dashboard UI matching
    final cardColor = colorScheme.surface;
    final borderColor = colorScheme.outlineVariant.withOpacity(isDark ? 0.5 : 0.2);
    final iconBgColor = color.withOpacity(isDark ? 0.2 : 0.1);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title, 
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800, 
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle, 
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  /// ---------- PICKERS ----------

  void _showThemePicker(BuildContext context, SettingsProvider settings) {
    _showOptions(
      context: context,
      title: "Select Theme",
      options: ["Light", "Dark", "System"],
      currentValue: settings.themeModeString,
      onSelect: (v) => settings.setTheme(v),
    );
  }

  void _showLanguagePicker(BuildContext context, SettingsProvider settings) {
    _showOptions(
      context: context,
      title: "Select Language",
      options: ["English"],
      currentValue: settings.language,
      onSelect: (v) => settings.setLanguage(v),
    );
  }

  void _showOptions({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String currentValue,
    required Function(String) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      enableDrag: false,
      backgroundColor: Colors.transparent, // Important for the rounded corners and shadow to show properly
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...options.map((e) {
              final isSelected = e == currentValue;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                title: Text(
                  e,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onSelect(e);
                },
              );
            }),
            const SizedBox(height: 24), // Bottom padding safe area
          ],
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
          icon: Icons.personal_video_rounded,
          title: "Personalization",
          subtitle: "Customize your app experience with themes and languages.",
        );
      case 1:
        return _buildSlideBase(
          color1: const Color(0xFF0F172A),
          color2: const Color(0xFF334155),
          icon: Icons.security_rounded,
          title: "Secure Access",
          subtitle: "Enable App Lock and biometrics for enhanced privacy.",
        );
      case 2:
        return _buildSlideBase(
          color1: const Color(0xFF1E1B4B),
          color2: const Color(0xFF4338CA),
          icon: Icons.notifications_active_rounded,
          title: "Smart Notifications",
          subtitle: "Stay updated with transaction alerts and app news.",
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
