import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../providers/settings_provider.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final LocalAuthentication auth = LocalAuthentication();

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
          // Revert or show message if needed. Switches usually stay at old value if we don't call setState or notify.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Authentication failed")),
            );
          }
        }
      } else {
        // Fallback for devices without bio/pin (though unlikely for pin)
        await settings.setAppLock(value);
      }
    } catch (e) {
      debugPrint("Auth error: $e");
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
          return Column(
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
                      child: Stack(
                        children: [
                          Positioned(
                            top: 10,
                            left: 12,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const Positioned(
                            bottom: 50,
                            left: 20,
                            child: Text(
                              "App Settings",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
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
                  transform: Matrix4.translationValues(0, -30, 0),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
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
                            icon: Icons.lock_rounded,
                            color: Colors.green,
                            title: "Biometric",
                            subtitle: "Login Using Biometric to open app",
                            value: settings.appLockEnabled,
                            onChanged: (v) => _handleAppLockToggle(v, settings),
                            context: context,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
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
        padding: const EdgeInsets.only(bottom: 12, top: 10),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            letterSpacing: 1.1,
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
      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
      onTap: onTap,
      context: context,
    );
  }

  Widget _card(IconData icon, Color color, String title, String subtitle, Widget trailing, {VoidCallback? onTap, required BuildContext context}) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final shadowColor = isDark ? Colors.black.withValues(alpha: 0.4) : color.withValues(alpha: 0.10);
    final borderColor = color.withValues(alpha: isDark ? 0.3 : 0.15);
    final iconBgColor = color.withValues(alpha: isDark ? 0.2 : 0.15);
    final titleColor = colorScheme.onSurface;
    final subtitleColor = colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 18,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: titleColor)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(color: subtitleColor)),
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
              color: Colors.black.withOpacity(0.1),
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
                color: Colors.grey.shade300,
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
            }).toList(),
            const SizedBox(height: 24), // Bottom padding safe area
          ],
        ),
      ),
    );
  }
}