import 'dart:async';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';

class CampusAppPicker {

  static List<ApplicationWithIcon> _cachedApps = [];
  static bool _loaded = false;

  static const keywords = [
    "campus","college","student","university","school","edu","attendance","erp","lms"
  ];

  /// PRELOAD (call on dashboard start)
  static Future preload() async {
    if (_loaded) return;

    List<Application> apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      onlyAppsWithLaunchIntent: true,
    );

    _cachedApps = apps
        .whereType<ApplicationWithIcon>()
        .where((app) {
          final name = app.appName.toLowerCase();
          final pkg = app.packageName.toLowerCase();
          if (pkg.contains("lume_student_app")) return false;

          return keywords.any((k) => name.contains(k) || pkg.contains(k));
        })
        .toList();

    _loaded = true;
  }

  /// OPEN PICKER (instant)
  static void show(BuildContext context) {

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CampusSheet(),
    );
  }
}



class _CampusSheet extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final apps = CampusAppPicker._cachedApps;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [

          const SizedBox(height: 12),

          Container(
            width: 45,
            height: 5,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(20),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            "Campus Apps",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: apps.isEmpty
                ? const Center(child: Text("No campus apps found"))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 18,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: apps.length,
                    itemBuilder: (_, i) {
                      final app = apps[i];

                      return GestureDetector(
                        onTap: () => DeviceApps.openApp(app.packageName),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [

                            /// ICON CARD (fixed size)
                            Container(
                              width: 64,
                              height: 64,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Image.memory(app.icon, fit: BoxFit.contain),
                            ),

                            const SizedBox(height: 6),

                            /// FLEXIBLE TEXT (prevents overflow forever)
                            Expanded(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Text(
                                  app.appName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    height: 1.1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}