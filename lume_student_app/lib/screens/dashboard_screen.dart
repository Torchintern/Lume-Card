import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui';
import '../services/api_service.dart';
import '../utils/campus_app_picker.dart';

enum WeatherCondition { sunny, cloudy, rainy, night }

class WeatherTheme {
  final List<Color> gradientColors;
  final IconData icon;
  final String label;
  final String greetingSuffix;
  final Widget? accent;

  const WeatherTheme({
    required this.gradientColors,
    required this.icon,
    required this.label,
    required this.greetingSuffix,
    this.accent,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  bool _isCardFlipped = false;
  String _userName = "John Doe"; 
  String _userPhone = "";
  String _userEmail = "";
  String _userRegNo = "";
  String _userDept = "";
  String _userInstitute = "";
  String _userDob = "";
  String _userBloodGroup = "";
  String _userBatch = "";
  String? _profileImageUrl;
  bool _isUploading = false;
  String _lumeStatus = "Inactive";
  
  // Weather & Greeting State
  String _weatherTemp = "--°C";
  String _weatherDesc = "Fetching...";
  IconData _weatherIcon = Icons.cloud_queue_rounded;
  WeatherCondition _currentCondition = WeatherCondition.cloudy;
  Timer? _clockTimer;

  final Map<WeatherCondition, WeatherTheme> _weatherThemes = {
    WeatherCondition.sunny: const WeatherTheme(
      gradientColors: [Color(0xFFF59E0B), Color(0xFFFBBF24), Color(0xFFFDE68A)],
      icon: Icons.wb_sunny_rounded,
      label: "Sunny",
      greetingSuffix: "☀️",
    ),
    WeatherCondition.cloudy: const WeatherTheme(
      gradientColors: [Color(0xFF60A5FA), Color(0xFF93C5FD)],
      icon: Icons.cloud_queue_rounded,
      label: "Cloudy",
      greetingSuffix: "☁️",
    ),
    WeatherCondition.rainy: const WeatherTheme(
      gradientColors: [Color(0xFF1E293B), Color(0xFF334155)],
      icon: Icons.umbrella_rounded,
      label: "Rainy",
      greetingSuffix: "🌧",
    ),
    WeatherCondition.night: const WeatherTheme(
      gradientColors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
      icon: Icons.nightlight_round,
      label: "Clear Night",
      greetingSuffix: "🌙",
    ),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args["profile_image"] != null) {
      _profileImageUrl = args["profile_image"];
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _tabController = TabController(length: 4, vsync: this);
    
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _loadUserProfile(); 
    _fetchWeather();
    _startClock();
    CampusAppPicker.preload();   
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");
      if (token != null && token.isNotEmpty) {
        final res = await ApiService.getProfile(token);
        if (res["error"] == null && res["student"] != null && mounted) {
          final student = res["student"];
          String? serverImage = student["profile_image"];
          setState(() {
            _userName = student["full_name"] ?? _userName;
            _userPhone = student["mobile"] ?? _userPhone;
            _userEmail = student["email"] ?? _userEmail;
            _userRegNo = student["reg_no"] ?? _userRegNo;
            _userDept = student["department"] ?? "";
            _userInstitute = student["institute_name"] ?? "";
            _userDob = student["dob"] ?? "";
            _userBloodGroup = student["blood_group"] ?? "";
            _lumeStatus = (student["lume_status"] ?? "inactive").toString().toLowerCase();

            // Build batch string from DB years
            final batchStart = student["batch_start_year"]?.toString() ?? "";
            final batchEnd = student["batch_end_year"]?.toString() ?? "";
            if (batchStart.isNotEmpty && batchEnd.isNotEmpty) {
              _userBatch = "$batchStart - $batchEnd";
            } else if (batchStart.isNotEmpty) {
              _userBatch = batchStart;
            } else {
              _userBatch = "";
            }

            if (serverImage != null && serverImage.isNotEmpty) {
              _profileImageUrl = serverImage;
            }
          });

          // Save AFTER setState
          if (serverImage != null && serverImage.isNotEmpty) {
            await prefs.setString("user_profile_image", serverImage);
          } else {
            _profileImageUrl ??= prefs.getString("user_profile_image");
          }

          await prefs.setString("full_name", _userName);
          await prefs.setString("user_email", _userEmail);
          await prefs.setString("user_reg_no", _userRegNo);
          await prefs.setString("user_dept", _userDept);
          await prefs.setString("user_institute", _userInstitute);
          await prefs.setString("user_dob", _userDob);
          await prefs.setString("user_blood_group", _userBloodGroup);
          await prefs.setString("user_batch", _userBatch);
          await prefs.setString("lume_status", _lumeStatus);
          if (_profileImageUrl != null) await prefs.setString("user_profile_image", _profileImageUrl!);
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _animationController.dispose();
    _flipController.dispose();
    _tabController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _showImageOptions() {
  showModalBottomSheet(
    context: context,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          const SizedBox(height: 12),

          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "Profile Photo",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 10),

          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.blue),
            title: const Text("Take Photo"),
            onTap: () {
              Navigator.pop(context);
              _handleImage(ImageSource.camera);
            },
          ),

          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.blue),
            title: const Text("Upload from Gallery"),
            onTap: () {
              Navigator.pop(context);
              _handleImage(ImageSource.gallery);
            },
          ),

          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text("Remove Photo"),
            onTap: () {
              Navigator.pop(context);
              _removeProfilePhoto();
            },
          ),

          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

Future<void> _handleImage(ImageSource source) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: source, imageQuality: 75);

  if (picked == null) return;

  setState(() => _isUploading = true);

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("auth_token");

    if (token == null) return;

    final res = await ApiService.uploadProfileImage(token, picked.path);

    if (res["profile_image"] != null) {
      final filename = res["profile_image"];

      setState(() {
        _profileImageUrl = filename;
      });

      await prefs.setString("user_profile_image", filename);
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Upload failed: $e")));
  }

  setState(() => _isUploading = false);
}

Future<void> _removeProfilePhoto() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString("auth_token");

  if (token == null) return;

  try {
    await ApiService.removeProfileImage(token);

    setState(() {
      _profileImageUrl = null;
    });

    await prefs.remove("user_profile_image");

  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Failed to remove image")));
  }
}

  String _getInitials(String name) {
    List<String> names = name.split(" ");
    String initials = "";
    int numWords = names.length > 2 ? 2 : names.length;
    for (var i = 0; i < numWords; i++) {
        if (names[i].isNotEmpty) {
            initials += names[i][0].toUpperCase();
        }
    }
    return initials.isEmpty ? "LU" : initials;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    String baseGreeting;
    if (hour < 12) {
      baseGreeting = "Good Morning";
    } else if (hour < 15) {
      baseGreeting = "Good Afternoon";
    } else {
      baseGreeting = "Good Evening";
    }
    
    // Additional weather-based messages
    if (_currentCondition == WeatherCondition.rainy) {
      return "Stay dry today";
    } else if (_currentCondition == WeatherCondition.sunny && hour >= 12 && hour < 17) {
      return "Enjoy the sun";
    }

    return baseGreeting;
  }

  String _getFormattedDate() {
    return DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now());
  }

  // Real weather fetch from Open-Meteo
  Future<void> _fetchWeather() async {
    try {
      // Default coordinate (e.g., London 51.5074, -0.1278) 
      // In a real app, you'd use geolocator to get user's position
      const double lat = 12.9716; // Example: Bangalore
      const double lon = 77.5946;
      
      final url = Uri.parse(
        "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true"
      );
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data["current_weather"];
        final double temp = current["temperature"];
        final int code = current["weathercode"];
        
        if (mounted) {
          setState(() {
            _weatherTemp = "${temp.toStringAsFixed(1)}°C";
            _currentCondition = _mapWeatherCode(code);
            _weatherDesc = _weatherThemes[_currentCondition]!.label;
            _weatherIcon = _weatherThemes[_currentCondition]!.icon;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching weather: $e");
      // Fallback
      if (mounted) {
        setState(() {
          _weatherTemp = "28°C";
          _weatherDesc = "Cloudy";
        });
      }
    }
  }

  WeatherCondition _mapWeatherCode(int code) {
    final hour = DateTime.now().hour;
    bool isNight = hour >= 19 || hour < 6;
    
    // WMO Weather interpretation codes (WW)
    if (code >= 61 && code <= 99) return WeatherCondition.rainy;
    if (code >= 1 && code <= 3) return isNight ? WeatherCondition.night : WeatherCondition.cloudy;
    if (code == 0) return isNight ? WeatherCondition.night : WeatherCondition.sunny;
    return WeatherCondition.cloudy;
  }

  Widget _buildDrawer(BuildContext context, ColorScheme colorScheme) {
    const Color iconColor = Color(0xFF3B82F6); // Lume Blue
    // ================= STATUS UI LOGIC =================
    late Color statusColor;
    late Color bgColor;
    late IconData statusIcon;
    late String statusText;

    switch (_lumeStatus.toLowerCase()) {
      case "active":
        statusColor = const Color(0xFF10B981);
        bgColor = const Color(0xFFECFDF5);
        statusIcon = Icons.check_circle_rounded;
        statusText = "Active";
        break;

      case "blocked":
        statusColor = Colors.orange;
        bgColor = const Color(0xFFFFF7ED);
        statusIcon = Icons.warning_rounded;
        statusText = "Blocked";
        break;

      default:
        statusColor = Colors.redAccent;
        bgColor = const Color(0xFFFEF2F2);
        statusIcon = Icons.cancel_rounded;
        statusText = "Inactive";
    }


    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // Simplified Drawer Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5))),
            ),
            child: Column(
              children: [
                Center(
                  child: Stack(
                    children: [
                      Container(
                        key: ValueKey(_profileImageUrl),
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1), // Light version of primary
                          shape: BoxShape.circle,
                          image: _profileImageUrl != null && _profileImageUrl!.isNotEmpty 
                            ? DecorationImage(
                                image: NetworkImage("${ApiService.baseUrl}/uploads/profile_pics/$_profileImageUrl"),
                                fit: BoxFit.cover,
                              )
                            : null,
                        ),
                        child: _profileImageUrl == null || _profileImageUrl!.isEmpty 
                          ? Center(
                              child: Text(
                                _getInitials(_userName),
                                style: const TextStyle(
                                  color: iconColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _isUploading ? null : _showImageOptions,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
                            ),
                            child: _isUploading 
                              ? const SizedBox(
                                  width: 16, 
                                  height: 16, 
                                  child: CircularProgressIndicator(strokeWidth: 2, color: iconColor)
                                )
                              : const Icon(Icons.camera_alt_rounded, size: 16, color: iconColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _userName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  _userPhone,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                ),

                const SizedBox(height: 2),

                Text(
                  _userEmail.isEmpty ? "No email provided" : _userEmail,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                ),

                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: statusColor, width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Drawer Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 0),
              physics: const BouncingScrollPhysics(),
              children: [
                const Divider(height: 1),
                _buildDrawerSection("ACCOUNT", [
                  _buildDrawerItem(Icons.badge_outlined, "My Profile", iconColor, () async {
                  await Navigator.pushNamed(context, "/profile", arguments: {
                    "student": {
                      "full_name": _userName,
                      "mobile": _userPhone,
                      "email": _userEmail,
                      "reg_no": _userRegNo,
                      "department": _userDept,
                      "institute_name": _userInstitute,
                      "dob": _userDob,
                      "blood_group": _userBloodGroup,
                      "profile_image": _profileImageUrl,
                      "batch_start_year": _userBatch.contains(" - ")
                          ? _userBatch.split(" - ").first
                          : null,
                      "batch_end_year": _userBatch.contains(" - ")
                          ? _userBatch.split(" - ").last
                          : null,
                    }
                  });
                  await _loadUserProfile();
                }),
                  _buildDrawerItem(Icons.credit_card_outlined, "Card Centre", iconColor, () {
                    _tabController.animateTo(1);
                  }),
                  _buildDrawerItem(Icons.card_giftcard_outlined, "Rewards", iconColor, () {
                    _tabController.animateTo(2);
                  }),
                ]),
                const Divider(height: 1),
                _buildDrawerSection("EXPLORE", [
                  _buildDrawerItem(Icons.school_outlined, "Scholar", iconColor, () {
                    Navigator.pushNamed(context, "/scholar");
                  }),
                  _buildDrawerItem(Icons.location_city_outlined, "My Campus", iconColor, () {
                      CampusAppPicker.show(context);
                  }),
                ]),
                const Divider(height: 1),
                _buildDrawerSection("SUPPORT", [
                  _buildDrawerItem(Icons.headset_mic_outlined, "Help & Support", iconColor, () {
                    Navigator.pushNamed(context, "/help-support");
                  }),
                  _buildDrawerItem(Icons.tune_rounded, "App Settings", iconColor, () {
                    Navigator.pushNamed(context, "/app-settings");
                  }),
                ]),
                const Divider(height: 1),
                _buildDrawerSection("ABOUT", [
                  _buildDrawerItem(Icons.info_outline_rounded, "About Lume", iconColor, () {
                    Navigator.pushNamed(context, '/about');
                  }),
                  _buildDrawerItem(Icons.description_outlined, "Terms & Conditions", iconColor, () {
                    Navigator.pushNamed(context, '/terms');
                  }),
                  _buildDrawerItem(Icons.privacy_tip_outlined, "Privacy Policy", iconColor, () {
                    Navigator.pushNamed(context, '/privacy');
                  }),
                ]),
                const Divider(height: 1),
                // Logout and Logo moved INSIDE scrollable view
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 24),
                        title: const Text(
                          "Logout",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.redAccent,
                          ),
                        ),
                        onTap: () {
                          Navigator.pushNamedAndRemoveUntil(context, "/loginpin", (_) => false);
                        },
                      ),
                      const SizedBox(height: 24),
                      Image.asset("assets/logo.png", height: 35),
                      const SizedBox(height: 8),
                      Text(
                        "Version 1.0.0",
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade400,
              letterSpacing: 1.1,
            ),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, Color iconColor, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
          letterSpacing: -0.3,
        ),
      ),
      onTap: () {
        _scaffoldKey.currentState?.closeDrawer();
        onTap();
      },
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300, size: 20),
    );
  }

  Widget _buildFlippingCard(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isCardFlipped = !_isCardFlipped;
          });
          if (_isCardFlipped) {
            _flipController.forward();
          } else {
            _flipController.reverse();
          }
        },
        child: AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            final angle = _flipAnimation.value * 3.141592653589793;
            final isBackVisible = angle > (3.141592653589793 / 2);
            
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              alignment: Alignment.center,
              child: isBackVisible
                  ? Transform(
                      transform: Matrix4.identity()..rotateY(3.141592653589793),
                      alignment: Alignment.center,
                      child: _buildCardBack(context, colorScheme),
                    )
                  : _buildCardFront(context, colorScheme),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardFront(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: 260,
      height: 410,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1F2937), // Dark grey
            Color(0xFF374151), // Medium grey
            Color(0xFF111827), // Deep grey/black
            Color(0xFF1F2937), // Back to dark grey
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.4, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 25,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Brushed Metal Texture
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(
                painter: BrushedMetalPainter(),
              ),
            ),
          ),
          
          // Subtle Metallic Highlight
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.transparent,
                    Colors.black.withOpacity(0.1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          
          Positioned(
            right: -20,
            bottom: 30,
            child: Opacity(
              opacity: 0.1,
              child: Image.asset("assets/logo.png", height: 200, color: Colors.white10),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Section - Chip and Contactless Icon
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 25),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Premium Chip Design (Vertical)
                        Container(
                          width: 38,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFDE68A),
                                const Color(0xFFF59E0B),
                                const Color(0xFFD97706),
                                const Color(0xFFFDE68A),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black54, width: 0.5),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(painter: ChipLinesPainter()),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.contactless_outlined, color: Colors.white70, size: 28),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                const Spacer(),
                
                // Central Logo - LUME
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "🄻🅄🄼🄴",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "STUDENT EXCLUSIVE",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(flex: 2),
                
                // Bottom Section - RuPay and Prepaid
                Align(
                  alignment: Alignment.bottomRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "RuPay",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.play_arrow_rounded, color: Colors.orange, size: 20),
                        ],
                      ),
                      const Text(
                        "PREPAID",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: 260,
      height: 410,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 25,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Row(
        children: [
          // Orange left strip
          Container(
            width: 10,
            decoration: const BoxDecoration(
              color: Color(0xFFE8820C),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
            ),
          ),
          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: University Logo + Name
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset("assets/logos/university.png", height: 35),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _userInstitute.isEmpty ? "UNIVERSITY NAME" : _userInstitute,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1A2E),
                            height: 1.1,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  _buildSimpleDivider(),
                  const SizedBox(height: 8),

                  // Student Name
                  Text(
                    _userName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A2E),
                      letterSpacing: 0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (_userDept.isNotEmpty)
                    Text(
                      _userDept.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E).withOpacity(0.7),
                        letterSpacing: 0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 12),

                  // Photo + Details row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Photo
                      Container(
                        width: 75,
                        height: 95,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                          image: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage("${ApiService.baseUrl}/uploads/profile_pics/$_profileImageUrl"),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                            ? Center(
                                child: Text(
                                  _getInitials(_userName),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      // Detail rows
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCardDetailRow("STUDENT ID", _userRegNo.isEmpty ? "-" : _userRegNo),
                            const SizedBox(height: 5),
                            _buildCardDetailRow("BATCH", _userBatch.isEmpty ? "-" : _userBatch),
                            const SizedBox(height: 5),
                            _buildCardDetailRow("PHONE", _userPhone.isEmpty ? "-" : _userPhone),
                            const SizedBox(height: 5),
                            _buildCardDetailRow("BLOOD GR", _userBloodGroup.isEmpty ? "-" : _userBloodGroup),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Footer: Signature + QR
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Signature column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 70,
                            height: 20,
                            child: CustomPaint(painter: SignaturePainter()),
                          ),
                          Container(
                            width: 70,
                            height: 1,
                            color: const Color(0xFFD1D5DB),
                            margin: const EdgeInsets.symmetric(vertical: 2),
                          ),
                          const Text(
                            "REGISTRAR",
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6B7280),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      
                      // QR Code
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: QrImageView(
                          data: _userRegNo.isEmpty ? "LUME_STUDENT" : _userRegNo,
                          version: QrVersions.auto,
                          size: 60.0,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    "This card is valid in India only.",
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: 6.5, 
                      color: Color(0xFF9CA3AF),
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

    );
  }

  Widget _buildSimpleDivider() {
    return Container(
      height: 1.5,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE8820C).withOpacity(0.5),
            const Color(0xFFE8820C).withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildCardDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A2E).withOpacity(0.5),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11, 
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }



  Widget _buildWeatherAccents() {
    switch (_currentCondition) {
      case WeatherCondition.sunny:
        return Stack(
          children: [
            Positioned(
              top: -20,
              right: -20,
              child: Icon(Icons.wb_sunny_rounded, size: 200, color: Colors.white.withOpacity(0.15)),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: Icon(Icons.wb_sunny_rounded, size: 100, color: Colors.white.withOpacity(0.08)),
            ),
          ],
        );
      case WeatherCondition.cloudy:
        return Stack(
          children: [
            Positioned(
              top: 20,
              right: 20,
              child: Icon(Icons.cloud_rounded, size: 180, color: Colors.white.withOpacity(0.12)),
            ),
            Positioned(
              bottom: 40,
              left: -30,
              child: Icon(Icons.cloud_rounded, size: 140, color: Colors.white.withOpacity(0.08)),
            ),
          ],
        );
      case WeatherCondition.rainy:
        return Stack(
          children: [
            Positioned(
              top: 0,
              right: 40,
              child: Icon(Icons.umbrella_rounded, size: 160, color: Colors.white.withOpacity(0.1)),
            ),
            ...List.generate(15, (index) => Positioned(
              top: (index * 20) % 200,
              left: (index * 30) % 400,
              child: Icon(Icons.water_drop_rounded, size: 12, color: Colors.white.withOpacity(0.15)),
            )),
          ],
        );
      case WeatherCondition.night:
        return Stack(
          children: [
            Positioned(
              top: 10,
              right: 30,
              child: Icon(Icons.nightlight_round, size: 120, color: Colors.white.withOpacity(0.15)),
            ),
            ...List.generate(20, (index) => Positioned(
              top: (index * 15) % 250.0,
              left: (index * 25) % 450.0,
              child: Icon(Icons.star_rounded, size: 8, color: Colors.white.withOpacity(0.2)),
            )),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colorScheme.surface,
      drawer: _buildDrawer(context, colorScheme),
      body: Stack(
          children: [
            // Background Gradient accent
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colorScheme.secondary.withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            
            Column(
              children: [
                // Fixed Premium Header
                Container(
                  height: size.height * 0.35,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _weatherThemes[_currentCondition]!.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Dynamic Weather Accents
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 1000),
                        child: Container(
                          key: ValueKey(_currentCondition),
                          child: _buildWeatherAccents(),
                        ),
                      ),
                      
                      // App Bar Actions & Leading
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 10,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                                  ),
                                  child: CircleAvatar(
                                    key: ValueKey(_profileImageUrl),
                                    radius: 18,
                                    backgroundColor: Colors.white24,
                                    backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                                    ? NetworkImage("${ApiService.baseUrl}/uploads/profile_pics/$_profileImageUrl")
                                    : null,
                                    child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                                        ? Text(
                                            _getInitials(_userName),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                              ),
                              IconButton(
                                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                                onPressed: () {
                                  Navigator.pushNamed(context, '/notifications');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Header Content
                      Positioned(
                        bottom: 40,
                        left: 24,
                        right: 24,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${_getGreeting()} ${_weatherThemes[_currentCondition]!.greetingSuffix}",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.8,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getFormattedDate(),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Glassmorphism Weather Card
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_weatherIcon, color: Colors.white, size: 28),
                                      const SizedBox(height: 6),
                                      Text(
                                        _weatherTemp,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      Text(
                                        _weatherDesc.toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Navigation Tabs Container
                Container(
                  width: double.infinity,
                  transform: Matrix4.translationValues(0, -25, 0),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: colorScheme.primary.withOpacity(0.1),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: Colors.grey.shade500,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    tabs: const [
                      Tab(icon: Icon(Icons.home_rounded), text: "Home"),
                      Tab(icon: Icon(Icons.credit_card_rounded), text: "Card"),
                      Tab(icon: Icon(Icons.emoji_events_rounded), text: "Rewards"),
                      Tab(icon: Icon(Icons.directions_bus_rounded), text: "Transit"),
                    ],
                  ),
                ),

                // Content Area
                Expanded(
                  child: Container(
                    color: colorScheme.surface,
                    transform: Matrix4.translationValues(0, -25, 0),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildHomeTab(context, colorScheme),
                        _buildCardTab(context, colorScheme),
                        _buildRewardsTab(context, colorScheme),
                        _buildTransitTab(context, colorScheme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  }

  Widget _buildHomeTab(BuildContext context, ColorScheme colorScheme) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Your Hub",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              Icon(Icons.widgets_rounded, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 20),
          
          // Interactive Grid
          GridView.count(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.9,
            children: [
              _AnimatedActionCard(
                animation: _animationController,
                index: 0,
                title: "Virtual ID",
                icon: Icons.badge_rounded,
                color: colorScheme.primary,
              ),
              _AnimatedActionCard(
                animation: _animationController,
                index: 1,
                title: "Attendance",
                icon: Icons.calendar_month_rounded,
                color: const Color(0xFFF59E0B), // Vibrant Orange
              ),
              _AnimatedActionCard(
                animation: _animationController,
                index: 2,
                title: "Results",
                icon: Icons.assignment_turned_in_rounded,
                color: const Color(0xFF10B981), // Emerald Green
              ),
              _AnimatedActionCard(
                animation: _animationController,
                index: 3,
                title: "Timetable",
                icon: Icons.schedule_rounded,
                color: const Color(0xFF8B5CF6), // Purple
              ),
            ],
          ),
          const SizedBox(height: 40),
          
          // Notice Board section
          FadeTransition(
            opacity: CurvedAnimation(parent: _animationController, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
                CurvedAnimation(parent: _animationController, curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic)),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colorScheme.secondary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_active_rounded, color: colorScheme.secondary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Important Update",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Mid-term exam schedule has been released.",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCardTab(BuildContext context, ColorScheme colorScheme) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFlippingCard(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(String title, String amount, String date, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  date,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: amount.startsWith("+") ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsTab(BuildContext context, ColorScheme colorScheme) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Points Balance
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Your Points",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
                        const SizedBox(width: 8),
                        const Text(
                          "2,450",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    elevation: 0,
                  ),
                  child: const Text("Redeem", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          
          // Featured Deals
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Featured Offers",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text("View All"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildOfferCard("20% Off", "At Campus Store", Icons.shopping_bag_rounded, Colors.blue),
                _buildOfferCard("Free Coffee", "At Red Cup Cafe", Icons.coffee_rounded, Colors.brown),
                _buildOfferCard("BOGO Movie", "PVR Cinemas", Icons.movie_rounded, Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 40),
          
          // Categories
          Text(
            "Categories",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCategoryIcon(Icons.restaurant_rounded, "Food", Colors.green),
              _buildCategoryIcon(Icons.shopping_cart_rounded, "Shop", Colors.purple),
              _buildCategoryIcon(Icons.local_taxi_rounded, "Travel", Colors.amber),
              _buildCategoryIcon(Icons.sports_esports_rounded, "Games", Colors.pink),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTransitTab(BuildContext context, ColorScheme colorScheme) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transit Pass
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Transit Pass",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Active • Valid till 30 Jun",
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "STUDENT",
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: "TRANSIT-$_userRegNo",
                    version: QrVersions.auto,
                    size: 100.0,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Tap or Scan at Entry",
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          
          // Campus Bus
          Text(
            "Campus Bus Schedule",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildBusItem("Bus 05", "Main Gate → Admin Block", "2 mins away", Colors.blue),
          _buildBusItem("Bus 12", "Hostel 3 → Engineering", "15 mins away", Colors.orange),
          const SizedBox(height: 40),
          
          // Trip History
          Text(
            "Recent Trips",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildTripItem("Main Gate Tap", "Today, 08:45 AM", Icons.directions_bus_rounded),
          _buildTripItem("Library Exit", "Yesterday, 05:20 PM", Icons.sensor_door_rounded),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBusItem(String busNo, String route, String arrival, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              busNo,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  arrival,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildTripItem(String title, String time, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.grey.shade600, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  time,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(String title, String subtitle, IconData icon, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18),
          ),
          Text(
            subtitle,
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}

class _AnimatedActionCard extends StatefulWidget {
  final AnimationController animation;
  final int index;
  final String title;
  final IconData icon;
  final Color color;

  const _AnimatedActionCard({
    required this.animation,
    required this.index,
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  State<_AnimatedActionCard> createState() => _AnimatedActionCardState();
}

class _AnimatedActionCardState extends State<_AnimatedActionCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate staggered delay based on index
    final double start = (widget.index * 0.1).clamp(0.0, 1.0);
    final double end = (start + 0.4).clamp(0.0, 1.0);
    
    final fadeOut = CurvedAnimation(parent: widget.animation, curve: Interval(start, end, curve: Curves.easeOut));
    final slideIn = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: widget.animation, curve: Interval(start, end, curve: Curves.easeOutCubic)),
    );

    return FadeTransition(
      opacity: fadeOut,
      child: SlideTransition(
        position: slideIn,
        child: GestureDetector(
          onTapDown: (_) => _scaleController.forward(),
          onTapUp: (_) {
            _scaleController.reverse();
            // Action logic here
          },
          onTapCancel: () => _scaleController.reverse(),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: widget.color.withOpacity(0.1), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    // Decorative fading circle
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color.withOpacity(0.05),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(widget.icon, color: widget.color, size: 28),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "View >",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Custom Painters ---

class CardDecorativePainter extends CustomPainter {
  final Color color;
  CardDecorativePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 60.0;

    final center = Offset(size.width, 0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.7),
      0, 3.14159, false, paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.9),
      0, 3.14159, false, paint,
    );
  }

  @override
  bool shouldRepaint(covariant CardDecorativePainter oldDelegate) =>
      oldDelegate.color != color;
}

class ChipLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Vertical divider line in the middle
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);

    // Horizontal lines dividing into rows
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, 2 * size.height / 3), Offset(0, 2 * size.height / 3), paint); // Optimization error in my head, wait

    // Correcting lines for vertical chip
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, 2 * size.height / 3), Offset(size.width, 2 * size.height / 3), paint);

    // Small central square (vertical)
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.5,
      height: size.height * 0.3,
    );
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SignaturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.cubicTo(
      size.width * 0.15, size.height * 0.2,
      size.width * 0.25, size.height * 0.9,
      size.width * 0.4, size.height * 0.4,
    );
    path.cubicTo(
      size.width * 0.5, size.height * 0.1,
      size.width * 0.6, size.height * 0.8,
      size.width * 0.75, size.height * 0.5,
    );
    path.cubicTo(
      size.width * 0.85, size.height * 0.3,
      size.width * 0.92, size.height * 0.6,
      size.width, size.height * 0.5,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BrushedMetalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5;

    for (double i = 0; i < size.height; i += 2) {
      double x = (i * 13) % size.width;
      canvas.drawLine(
        Offset(x, i),
        Offset((x + 100) % size.width, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
