import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../services/api_service.dart';
import '../providers/settings_provider.dart';
import 'dart:ui';

class LoginPinScreen extends StatefulWidget {
  const LoginPinScreen({super.key});

  @override
  State<LoginPinScreen> createState() => _LoginPinScreenState();
}

class _LoginPinScreenState extends State<LoginPinScreen> with SingleTickerProviderStateMixin {
  final TextEditingController pinController = TextEditingController();
  final FocusNode pinFocusNode = FocusNode();
  final LocalAuthentication auth = LocalAuthentication();
  
  bool loading = false;
  bool _isPinComplete = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    pinController.addListener(() {
      setState(() {
        _isPinComplete = pinController.text.length == 6;
      });
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    pinController.dispose();
    pinFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void login({String? providedPin, SettingsProvider? settings}) async {
    final String pin = providedPin ?? pinController.text;
    
    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enter your PIN"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    pinFocusNode.unfocus();
    setState(() => loading = true);

    final prefs = await SharedPreferences.getInstance();
    final String? storedPhone = prefs.getString("user_phone");

    if (storedPhone == null || storedPhone.isEmpty) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Phone number not found. Please register/login again."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, "/phone", (_) => false);
      return;
    }

    final res = await ApiService.loginPin(
      storedPhone,
      pin,
    );

    if (!mounted) return;
    setState(() => loading = false);

    if (res["error"] != null) {
      String errorMessage = res["error"];
      if (errorMessage == "User not registered") {
        errorMessage = "Invalid PIN";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      // Save login time, token and profile details
      await prefs.setString("last_login_time", DateTime.now().toIso8601String());
      if (res["token"] != null) {
        await prefs.setString("auth_token", res["token"]);
      }
      
      // Ensure we have the PIN saved securely for biometrics (if/when enabled)
      if (settings != null) {
        await settings.saveSecurePin(pin);
      }

      // Cache details for Biometric login
      await prefs.setString("full_name", res["full_name"] ?? "");
      await prefs.setString("user_email", res["email"] ?? "");
      await prefs.setString("user_reg_no", res["reg_no"] ?? "");
      await prefs.setInt("reg_id", res["student_id"]);
      
      String dept = res["department"] ?? "";
      await prefs.setString("user_dept", dept.isEmpty ? "Not Specified" : dept);
      
      String inst = res["institute_name"] ?? "";
      await prefs.setString("user_institute", inst.isEmpty ? "Lume Institute" : inst);

      if (res["dob"] != null) await prefs.setString("user_dob", res["dob"]);
      if (res["blood_group"] != null) await prefs.setString("user_blood_group", res["blood_group"]);

      // Navigate to dashboard on success
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context, 
          "/dashboard", 
          (_) => false,
          arguments: {
            "full_name": res["full_name"] ?? "Lume User",
            "mobile": res["mobile"] ?? storedPhone,
            "email": res["email"] ?? "",
            "reg_no": res["reg_no"] ?? "",
            "department": res["department"] ?? "",
            "institute_name": res["institute_name"] ?? "",
            "dob": res["dob"] ?? "Not Provided",
            "blood_group": res["blood_group"] ?? "Not Provided",
          },
        );
      }
    }
  }

  Future<void> _loginWithBiometrics(SettingsProvider settings) async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (canAuthenticate) {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Authenticate to login to Lume',
          persistAcrossBackgrounding: true,
          biometricOnly: false,
        );

        if (didAuthenticate) {
          final String? securePin = await settings.getSecurePin();
          if (securePin != null && securePin.isNotEmpty) {
            login(providedPin: securePin, settings: settings);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Security PIN not found. Please login with PIN once to enable fingerprint."),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Biometrics not supported on this device")),
          );
        }
      }
    } on PlatformException catch (e) {
      debugPrint("Biometric platform error: ${e.code} - ${e.message}");
      // Suppress SnackBar for any cancellation or in-progress error
      final code = e.code.toLowerCase();
      if (code.contains('cancel') || code.contains('notavailable') || code == 'auth_in_progress') {
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Authentication Error: ${e.message ?? e.code}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("Biometric error detail: $e");
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('cancel')) return;
      
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains("NotAvailable")) {
          return; // Already handled by string check but being safe here
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Authentication Error: $errorMsg"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Stack(
    children: [
      Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return SingleChildScrollView(
            child: Column(
              children: [
                // Header Section
                Container(
                  height: size.height * 0.4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                            child: ClipOval(
                              child: Image.asset(
                                "assets/logo.png",
                                height: 60,
                                width: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "Welcome Back to Lume",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Enter your secure PIN to login",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Interactive Form Section
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Card(
                        elevation: 8,
                        shadowColor: Colors.black.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Enter PIN",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    if (pinFocusNode.hasFocus)
                                      BoxShadow(
                                        color: colorScheme.primary.withValues(alpha: 0.2),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      )
                                  ],
                                ),
                                child: TextField(
                                  controller: pinController,
                                  focusNode: pinFocusNode,
                                  obscureText: true,
                                  obscuringCharacter: '●',
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    letterSpacing: 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: "",
                                    hintText: "••••••",
                                    hintStyle: TextStyle(
                                      fontSize: 28,
                                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                      letterSpacing: 16.0,
                                    ),
                                    filled: true,
                                    fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
    
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: (_isPinComplete && !loading) ? () => login(settings: settings) : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: loading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Text(
                                              "Login",
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.login_rounded,
                                              size: 20,
                                              color: _isPinComplete 
                                                  ? colorScheme.onPrimary 
                                                  : colorScheme.onSurface.withValues(alpha: 0.38),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
    
                              if (settings.appLockEnabled) ...[
                                const SizedBox(height: 32),
                                Center(
                                  child: InkWell(
                                    onTap: () => _loginWithBiometrics(settings),
                                    borderRadius: BorderRadius.circular(40),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                                      ),
                                      child: Icon(
                                        Icons.fingerprint_rounded,
                                        size: 48,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
    
                              const SizedBox(height: 12),
    
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, "/phone", arguments: {"isForgotPin": true});
                                  },
                                  child: Text(
                                    "Forgot PIN?",
                                    style: TextStyle(
                                      color: colorScheme.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

        if (loading)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              color: Colors.black.withOpacity(0.2),
              child: const Center(
                child: _RippleLoader(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RippleLoader extends StatefulWidget {
  const _RippleLoader();

  @override
  State<_RippleLoader> createState() => _RippleLoaderState();
}

class _RippleLoaderState extends State<_RippleLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildRipple(controller.value, color),
              _buildRipple((controller.value + 0.3) % 1, color),
              _buildRipple((controller.value + 0.6) % 1, color),
              Icon(
                Icons.lock_rounded,
                size: 36,
                color: color,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRipple(double value, Color color) {
    return Container(
      width: 120 * value,
      height: 120 * value,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withOpacity(1 - value),
          width: 3,
        ),
      ),
    );
  }
}
