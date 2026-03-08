import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';

import 'screens/phone_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/student_confirm_screen.dart';
import 'screens/set_pin_screen.dart';
import 'screens/login_pin_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/scholar_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/app_settings_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/about/terms_conditions_screen.dart';
import 'screens/about/privacy_policy_screen.dart';
import 'screens/about/about_lume_screen.dart';
import 'screens/kyc_form_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/card_center_screen.dart';
import 'screens/card_benefits_screen.dart';
import 'screens/card_controls_screen.dart';
import 'screens/card_reissue_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final lastLoginStr = prefs.getString('last_login_time');

  String startRoute = "/phone";

  if (lastLoginStr != null) {
    final lastLogin = DateTime.tryParse(lastLoginStr);
    if (lastLogin != null) {
      final difference = DateTime.now().difference(lastLogin);

      // 96 hours = 4 days login session
      if (difference.inHours <= 96) {
        startRoute = "/loginpin";
      }
    }
  }

  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
      ],
      child: LumeApp(initialRoute: startRoute),
    ),
  );
}

class LumeApp extends StatelessWidget {
  final String initialRoute;

  const LumeApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Lume',

          themeMode: settings.themeMode,

          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1),
              primary: const Color(0xFF6366F1),
              secondary: const Color(0xFF3B82F6),
              surface: Colors.white,
              background: const Color(0xFFF8FAFC),
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),

            textTheme: const TextTheme(
              displayLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.5),
              displayMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
              headlineLarge: TextStyle(fontWeight: FontWeight.w700),
              titleLarge: TextStyle(fontWeight: FontWeight.w700),
            ),

            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            cardTheme: CardThemeData(
              elevation: 8,
              shadowColor: const Color(0xFF6366F1).withOpacity(0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              color: Colors.white,
            ),
          ),

          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1),
              brightness: Brightness.dark,
              primary: const Color(0xFF818CF8),
              secondary: const Color(0xFF60A5FA),
              surface: const Color(0xFF1E293B),
              onSurface: Colors.white,
              onSurfaceVariant: Colors.grey.shade400,
              background: const Color(0xFF0F172A),
              onBackground: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFF0F172A),

            textTheme: const TextTheme(
              displayLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.5, color: Colors.white),
              displayMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white),
              headlineLarge: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              titleLarge: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white),
              labelLarge: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
            ),

            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),

            cardTheme: CardThemeData(
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              color: const Color(0xFF1E293B),
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Color(0xFF1E293B),
              surfaceTintColor: Colors.transparent,
            ),
          ),

          builder: (context, child) {
            return child!;
          },

          // Dynamic first screen
          initialRoute: initialRoute,

          routes: {
            "/phone": (_) => const PhoneScreen(),
            "/otp": (_) => const OTPScreen(),
            "/confirm": (_) => const StudentConfirmScreen(),
            "/setpin": (_) => const SetPinScreen(),
            "/loginpin": (_) => const LoginPinScreen(),
            "/dashboard": (_) => const DashboardScreen(),
            "/profile": (_) => const ProfileScreen(),
            "/scholar": (_) => const ScholarScreen(),
            "/help-support": (context) => const HelpSupportScreen(),
            '/app-settings': (context) => const AppSettingsScreen(),
            '/terms': (context) => const TermsConditionsScreen(),
            '/privacy': (context) => const PrivacyPolicyScreen(),
            '/about': (context) => const AboutLumeScreen(),
            '/notifications': (context) => const NotificationScreen(),
            '/kyc': (context) => const KycFormScreen(),
            "/transactions": (context) => const TransactionsScreen(),
            "/card-center": (context) => const CardCenterScreen(),
            "/card-benefits": (context) => const CardBenefitsScreen(),
            "/card-controls": (context) => const CardControlsScreen(),
            "/card-reissue": (context) => const CardReissueScreen(),
          },
        );
      },
    );
  }
}