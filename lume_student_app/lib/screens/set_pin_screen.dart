import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/settings_provider.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> with SingleTickerProviderStateMixin {
  final TextEditingController createPinController = TextEditingController();
  final TextEditingController confirmPinController = TextEditingController();
  
  final FocusNode createPinFocus = FocusNode();
  final FocusNode confirmPinFocus = FocusNode();
  
  bool loading = false;
  bool _isCreatePinComplete = false;
  bool _isConfirmPinComplete = false;
  bool _doPinsMatch = false;

  late String phone;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    createPinController.addListener(() {
      setState(() {
        _isCreatePinComplete = createPinController.text.length == 6;
        _validatePins();
      });
    });

    confirmPinController.addListener(() {
      setState(() {
        _isConfirmPinComplete = confirmPinController.text.length == 6;
        _validatePins();
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
  
  void _validatePins() {
    if (_isCreatePinComplete && _isConfirmPinComplete) {
      _doPinsMatch = createPinController.text == confirmPinController.text;
    } else {
      _doPinsMatch = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    phone = ModalRoute.of(context)!.settings.arguments as String;
  }

  @override
  void dispose() {
    createPinController.dispose();
    confirmPinController.dispose();
    createPinFocus.dispose();
    confirmPinFocus.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void setPin() async {
    if (!_doPinsMatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("PINs do not match. Please try again."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    createPinFocus.unfocus();
    confirmPinFocus.unfocus();
    setState(() => loading = true);

    final res = await ApiService.setPin(phone, createPinController.text);

    if (!mounted) return;
    setState(() => loading = false);

    if (res["error"] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res["error"]),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      // Cache details for Biometric login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("full_name", res["full_name"] ?? "");
      await prefs.setString("user_email", res["email"] ?? "");
      await prefs.setString("user_reg_no", res["reg_no"] ?? "");
      await prefs.setInt("reg_id", res["student_id"]);
      
      String dept = res["department"] ?? "";
      await prefs.setString("user_dept", dept.isEmpty ? "Not Specified" : dept);
      
      String inst = res["institute_name"] ?? "";
      await prefs.setString("user_institute", inst.isEmpty ? "Lume Institute" : inst);

      // Save PIN securely for Biometric login
      if (mounted) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        await settings.saveSecurePin(createPinController.text);
      }

      // Show success message before navigating
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text("Security PIN created successfully!"),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, "/loginpin", (_) => false);
      });
    }
  }

  Widget _buildPinInputField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData prefixIcon,
    required bool isComplete,
    bool showMatchStatus = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    Color getBorderColor() {
      if (showMatchStatus && isComplete && _isCreatePinComplete) {
        return _doPinsMatch ? Colors.green : Colors.redAccent;
      }
      return focusNode.hasFocus ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.2);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (focusNode.hasFocus)
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
            ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: true,
            obscuringCharacter: '●',
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 12.0,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              counterText: "",
              prefixIcon: Icon(
                prefixIcon,
                color: focusNode.hasFocus ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              suffixIcon: showMatchStatus && isComplete && _isCreatePinComplete
                  ? Icon(
                      _doPinsMatch ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: _doPinsMatch ? Colors.green : Colors.redAccent,
                    )
                  : (isComplete && !showMatchStatus)
                      ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                      : null,
              filled: true,
              fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: getBorderColor(),
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: (showMatchStatus && isComplete && _isCreatePinComplete && !_doPinsMatch) 
                      ? Colors.redAccent.withValues(alpha: 0.5) 
                      : Colors.transparent,
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              height: size.height * 0.35,
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_person_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Secure Your App",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Create a memorable 6 digit PIN",
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
                    shadowColor: Colors.black.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPinInputField(
                            label: "Create New PIN",
                            controller: createPinController,
                            focusNode: createPinFocus,
                            prefixIcon: Icons.lock_outline_rounded,
                            isComplete: _isCreatePinComplete,
                          ),
                          
                          const SizedBox(height: 24),
                          
                          _buildPinInputField(
                            label: "Re-enter to Confirm",
                            controller: confirmPinController,
                            focusNode: confirmPinFocus,
                            prefixIcon: Icons.lock_reset_rounded,
                            isComplete: _isConfirmPinComplete,
                            showMatchStatus: true,
                          ),
                          
                          if (_isConfirmPinComplete && !_doPinsMatch && !confirmPinFocus.hasFocus) ...[
                            const SizedBox(height: 8),
                            const Text(
                              "PINs do not match",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],

                          const SizedBox(height: 40),

                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: (_doPinsMatch && !loading) ? setPin : null,
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
                                          "Confirm & Create PIN",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.shield_rounded,
                                          size: 20,
                                          color: _doPinsMatch 
                                              ? colorScheme.onPrimary 
                                              : colorScheme.onSurface.withValues(alpha: 0.38),
                                        ),
                                      ],
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
      ),
    );
  }
}