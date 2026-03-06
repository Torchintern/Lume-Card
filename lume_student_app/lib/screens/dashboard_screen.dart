import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
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
  String _kycStatus = "Pending";
  String? _kycSlotDate;
  String? _kycSlotTime;
  bool _isTermsAccepted = false;
  String? _kycRemarks;
  int? _studentId;
  String? _authToken;
  
  // Card sensitive details
  String? _cardNumber;
  String? _cardCvv;
  String? _cardExpiry;
  bool _isCardLocked = false;
  bool _isCardBlocked = false;
  
  // Transactions
  List<dynamic> _recentTransactions = [];
  
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
    // Remove setState listener to prevent full-screen rebuilds on every tab switch step
    // _tabController.addListener(() {
    //   if (mounted) setState(() {});
    // });
    
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
      _kycSlotDate = prefs.getString("kyc_slot_date");
      _kycSlotTime = prefs.getString("kyc_slot_time");
      if (mounted) setState(() {});

      final token = prefs.getString("auth_token");
      _authToken = token;
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
            _kycStatus = (student["kyc_status"] ?? "Pending").toString();
            _kycRemarks = student["kyc_remarks"] ?? student["remarks"];
            _studentId = student["id"];
            
            // Extract slot info if available
            if (student["kyc_slot"] != null) {
              _kycSlotDate = student["kyc_slot"]["date"];
              _kycSlotTime = student["kyc_slot"]["time"];
            } else if (student["slot_date"] != null) {
              _kycSlotDate = student["slot_date"]; 
              _kycSlotTime = student["slot_time"];
            } else if (student["kyc_date"] != null) {
              _kycSlotDate = student["kyc_date"];
              _kycSlotTime = student["kyc_time"];
            }

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

        if (_studentId != null && (_kycStatus.toLowerCase() == "rejected" || _kycStatus.toLowerCase() == "booked" || _kycStatus.toLowerCase() == "under process")) {
          try {
            final kycRes = await ApiService.getKycStatus(_studentId!);
            if (kycRes != null && kycRes is Map) {
              setState(() {
                _kycRemarks = kycRes["remarks"];
                if (kycRes["slot_date"] != null) _kycSlotDate = kycRes["slot_date"];
                if (kycRes["slot_time"] != null) _kycSlotTime = kycRes["slot_time"];
                if (kycRes["date"] != null) _kycSlotDate = kycRes["date"];
                if (kycRes["time"] != null) _kycSlotTime = kycRes["time"];
              });
            }
          } catch (e) {
            debugPrint("Error loading KYC status: $e");
          }
        }

        // Fetch card details for lock status
        try {
          final cardRes = await ApiService.getCardDetails(token);
          if (cardRes.isNotEmpty) {
            final String lockStatus = (cardRes["card_lock"] ?? "").toString().toUpperCase();
            final String cardState = (cardRes["card_state"] ?? "").toString().toUpperCase();
            
            setState(() {
              _isCardLocked = lockStatus == "LOCKED" || cardRes["card_lock"] == true;
              _isCardBlocked = lockStatus == "BLOCKED" || cardState == "BLOCKED";
            });
          }
        } catch (e) {
          debugPrint("Error syncing card lock status: $e");
        }

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
          if (_kycSlotDate != null) await prefs.setString("kyc_slot_date", _kycSlotDate!);
          if (_kycSlotTime != null) await prefs.setString("kyc_slot_time", _kycSlotTime!);
          if (_studentId != null) await prefs.setInt("student_id", _studentId!);
          if (_profileImageUrl != null) await prefs.setString("user_profile_image", _profileImageUrl!);
          
          final txs = await ApiService.getTransactions(token);
          if (mounted) {
            _recentTransactions = txs;
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
    if (mounted) setState(() {});
  }

  bool _isSlotTimeReached() {
    if (_kycSlotDate == null || _kycSlotTime == null) return false;

    try {
      final now = DateTime.now();
      
      // Parse Date (YYYY-MM-DD)
      List<String> dateParts = _kycSlotDate!.split('-');
      if (dateParts.length != 3) return false;
      
      int year, month, day;
      if (dateParts[0].length == 4) {
        year = int.parse(dateParts[0]);
        month = int.parse(dateParts[1]);
        day = int.parse(dateParts[2]);
      } else {
        day = int.parse(dateParts[0]);
        month = int.parse(dateParts[1]);
        year = int.parse(dateParts[2]);
      }

      // Parse Time (Assuming "HH:mm AM/PM" or "HH:mm")
      String timeStr = _kycSlotTime!.toUpperCase().replaceAll(" ", "");
      int hour = 0;
      int minute = 0;

      if (timeStr.contains("AM") || timeStr.contains("PM")) {
        bool isPm = timeStr.contains("PM");
        String cleanTime = timeStr.replaceAll("AM", "").replaceAll("PM", "");
        final timeParts = cleanTime.split(':');
        if (timeParts.length < 2) return false;
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
        
        if (isPm && hour != 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
      } else {
        final timeParts = timeStr.split(':');
        if (timeParts.length < 2) return false;
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
      }

      final slotDateTime = DateTime(year, month, day, hour, minute);
      // Strict activation: now must be after or equal to slot time
      return now.isAfter(slotDateTime) || now.isAtSameMomentAs(slotDateTime);
    } catch (e) {
      debugPrint("Time parsing error: $e");
      return false;
    }
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
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
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
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Profile Photo",
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: Icon(Icons.camera_alt, color: colorScheme.primary),
              title: Text("Take Photo", style: TextStyle(color: colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _handleImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: colorScheme.primary),
              title: Text("Upload from Gallery", style: TextStyle(color: colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _handleImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text("Remove Photo", style: TextStyle(color: Colors.redAccent)),
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
  final colorScheme = Theme.of(context).colorScheme;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Upload failed: $e"),
        backgroundColor: colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  setState(() => _isUploading = false);
}

Future<void> _removeProfilePhoto() async {
  final colorScheme = Theme.of(context).colorScheme;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Failed to remove image"),
        backgroundColor: colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
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

    switch (_kycStatus.toLowerCase()) {
      case "completed":
      case "verified":
        statusColor = const Color(0xFF10B981); // Emerald Green
        bgColor = const Color(0xFFECFDF5);
        statusIcon = Icons.check_circle_rounded;
        statusText = "KYC Verified";
        break;

      case "booked":
      case "under process":
        statusColor = const Color(0xFF3B82F6); // Lume Blue
        bgColor = const Color(0xFFEFF6FF);
        statusIcon = Icons.event_available_rounded;
        statusText = "KYC Booked";
        break;

      case "rejected":
        statusColor = Colors.redAccent;
        bgColor = const Color(0xFFFEF2F2);
        statusIcon = Icons.error_outline_rounded;
        statusText = "KYC Rejected";
        break;

      default:
        statusColor = Colors.orange;
        bgColor = const Color(0xFFFFF7ED);
        statusIcon = Icons.pending_actions_rounded;
        statusText = "KYC Pending";
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
                  _buildDrawerItem(Icons.credit_card_outlined, "Card", iconColor, () {
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: GestureDetector(
            onTap: () async {
              if (_kycStatus != "Completed") {
                await Navigator.pushNamed(context, "/kyc");
                if (!context.mounted) return;
                final currentColorScheme = Theme.of(context).colorScheme;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Complete KYC to activate your card"),
                    backgroundColor: currentColorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: "OK",
                      textColor: colorScheme.onPrimary,
                      onPressed: () {},
                    ),
                  ),
                );
                return;
              }
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
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 14,
              color: colorScheme.primary.withOpacity(0.6),
            ),
            const SizedBox(width: 6),
            Text(
              "Tap to Flip",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
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
                      _buildRuPayLogo(fontSize: 18),
                      const SizedBox(height: 4),
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
          if (_isCardLocked || _isCardBlocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isCardBlocked ? Icons.block_rounded : Icons.lock_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _isCardBlocked ? "BLOCKED" : "LOCKED",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
      child: Stack(
        children: [
          Row(
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
          if (_isCardLocked || _isCardBlocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isCardBlocked ? Icons.block_rounded : Icons.lock_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _isCardBlocked ? "BLOCKED" : "LOCKED",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRuPayLogo({double fontSize = 18}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Image.asset(
        "assets/logos/rupay.png",
        height: fontSize + 6,
        fit: BoxFit.contain,
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



  Widget _buildProfileIcon({required ColorScheme colorScheme, bool isOnDark = false}) {
    final Color iconColor = isOnDark ? Colors.white : colorScheme.primary;
    final Color borderColor = isOnDark ? Colors.white.withOpacity(0.5) : colorScheme.primary.withOpacity(0.2);
    final Color bgColor = isOnDark ? Colors.white.withOpacity(0.2) : colorScheme.primary.withOpacity(0.1);

    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: CircleAvatar(
          key: ValueKey(_profileImageUrl),
          radius: 18,
          backgroundColor: isOnDark ? Colors.white24 : colorScheme.primary.withOpacity(0.05),
          backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
          ? NetworkImage("${ApiService.baseUrl}/uploads/profile_pics/$_profileImageUrl")
          : null,
          child: _profileImageUrl == null || _profileImageUrl!.isEmpty
              ? Text(
                  _getInitials(_userName),
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
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

    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        final bool isHome = _tabController.index == 0;
        final int currentIndex = _tabController.index;
        
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
                    if (isHome)
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
                          
                          // Profile Icon removed from here, now in global Stack for consistency

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
                                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                    )
                    else 
                    SizedBox(height: MediaQuery.of(context).padding.top + 56),

                    // Content Area
                    Expanded(
                      child: Container(
                        transform: isHome ? Matrix4.translationValues(0, -25, 0) : null,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: isHome ? const BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ) : null,
                        ),
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _TabKeepAliveWrapper(child: _buildHomeTab(context, colorScheme)),
                            _TabKeepAliveWrapper(child: _buildCardTab(context, colorScheme)),
                            _TabKeepAliveWrapper(child: _buildRewardsTab(context, colorScheme)),
                            _TabKeepAliveWrapper(child: _buildTransitTab(context, colorScheme)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Custom Header for other tabs
                if (!isHome)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: MediaQuery.of(context).padding.top + 56,
                    color: colorScheme.surface,
                    child: Padding(
                      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                      child: Center(
                        child: Text(
                          ["Home", "Card", "Rewards", "Transit"][currentIndex],
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Fixed Profile Icon - Consistent across all tabs
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 12,
                  child: _buildProfileIcon(colorScheme: colorScheme, isOnDark: isHome),
                ),
              ],
            ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TabBar(
                  controller: _tabController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildHomeTab(BuildContext context, ColorScheme colorScheme) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: HomeBackgroundPainter(
              color: colorScheme.primary,
              isDark: isDark,
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction_rounded,
                size: 64,
                color: colorScheme.primary.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                "Coming Soon",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "We're working on something exciting for your Home hub!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKYCPendingView(BuildContext context, ColorScheme colorScheme) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Text(
                "Empower your digital journey with LUME",
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Know Your Customer",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 25),

              // Main Highlight Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.wallet_rounded,
                                    color: colorScheme.primary, size: 22),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Enhanced Wallet\nCapacity",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Verify your identity to unlock a spending limit of up to ₹ 2 Lakhs.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.currency_rupee_rounded,
                                    color: colorScheme.primary, size: 22),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Complete\nTransparency",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Zero hidden fees. Experience straightforward and honest digital finance.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // Illustration Placeholder
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        image: DecorationImage(
                          image: const AssetImage("assets/images/KYC.png"), 
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Small Cards
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        constraints: const BoxConstraints(minHeight: 160),
                        decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.badge_rounded,
                                color: colorScheme.primary, size: 22),
                          ),
                          const Spacer(),
                          Text(
                            "Keep your Identity documents (PAN/Aadhaar) ready for verification",
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      constraints: const BoxConstraints(minHeight: 160),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.wifi_rounded,
                                color: colorScheme.primary, size: 22),
                          ),
                          const Spacer(),
                          Text(
                            "A stable internet connection ensures a seamless onboarding process.",
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
              
              // Terms & Conditions Checkbox
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _isTermsAccepted,
                        activeColor: colorScheme.primary,
                        checkColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        onChanged: (val) {
                          setState(() {
                            _isTermsAccepted = val ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                            fontFamily: 'Outfit',
                          ),
                          children: [
                            const TextSpan(text: "I accept "),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: GestureDetector(
                                onTap: () => Navigator.pushNamed(context, '/terms'),
                                child: Text(
                                  "Terms & conditions",
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            const TextSpan(text: " and "),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: GestureDetector(
                                onTap: () => Navigator.pushNamed(context, '/privacy'),
                                child: Text(
                                  "Privacy Policy",
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100), // Spacing for floating button
            ],
          ),
        ),
        
        // Floating button at the bottom
        Positioned(
          left: 24,
          right: 24,
          bottom: 20,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: !_isTermsAccepted ? null : () async {
                await Navigator.pushNamed(context, "/kyc");
                await _loadUserProfile();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: colorScheme.primary.withOpacity(0.3),
              ),
              child: const Text(
                "Complete KYC",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKYCUnderProcessView(BuildContext context, ColorScheme colorScheme) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      "assets/images/reach.png", // Crane illustration
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 40),
                    Text(
                      "Your KYC is under\nprocess",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_kycSlotDate != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 16, color: colorScheme.primary),
                          const SizedBox(width: 8),
                            Text(
                              _kycSlotTime != null 
                                ? "Scheduled for $_kycSlotDate at $_kycSlotTime"
                                : "Scheduled for $_kycSlotDate",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      _isSlotTimeReached()
                        ? "Your slot is now active. Please click continue."
                        : "We will notify you once the KYC is completed",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100), 
            ],
          ),
        ),
        
        // Floating Button
        Positioned(
          left: 24,
          right: 24,
          bottom: 20,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSlotTimeReached()
                ? () {
                    _tabController.animateTo(0); // Go back to Home
                  }
                : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSlotTimeReached() ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.12),
                foregroundColor: _isSlotTimeReached() ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.04),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: _isSlotTimeReached() ? 4 : 0,
                shadowColor: colorScheme.primary.withOpacity(0.3),
              ),
              child: Text(
                _isSlotTimeReached() ? "Continue" : "Waiting for Confirmation...",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardTab(BuildContext context, ColorScheme colorScheme) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_kycStatus == "Pending") {
      return _buildKYCPendingView(context, colorScheme);
    }
    
    if (_kycStatus == "Booked") {
      return _buildKYCUnderProcessView(context, colorScheme);
    }

    if (_kycStatus == "Rejected") {
      return _buildKYCRejectedView(context, colorScheme);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: CardBackgroundPainter(
              color: colorScheme.primary,
              isDark: isDark,
            ),
          ),
        ),
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_kycStatus == "Completed") ...[
                _buildFlippingCard(context, colorScheme),
                const SizedBox(height: 30),
                _buildCardActions(context, colorScheme),

                const SizedBox(height: 35),

                _buildTransactionsSection(context, colorScheme),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKYCRejectedView(BuildContext context, ColorScheme colorScheme) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      "assets/images/reject.png",
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      "KYC Verification\nRejected",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.redAccent : Colors.red,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      (_kycRemarks != null && _kycRemarks!.isNotEmpty)
                          ? _kycRemarks!
                          : "Please review and try again with the correct information.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100), // Spacing for floating button
            ],
          ),
        ),
        
        // Floating Button
        Positioned(
          left: 24,
          right: 24,
          bottom: 20,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.pushNamed(context, "/kyc");
                await _loadUserProfile();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: colorScheme.primary.withOpacity(0.3),
              ),
              child: const Text(
                "Re-Verify",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRewardsTab(BuildContext context, ColorScheme colorScheme) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: RewardsBackgroundPainter(
              color: Colors.orange,
              isDark: isDark,
            ),
          ),
        ),
        SingleChildScrollView(
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
        ),
      ],
    );
  }

  Widget _buildTransitTab(BuildContext context, ColorScheme colorScheme) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: TransitBackgroundPainter(
              color: Colors.blue,
              isDark: isDark,
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 64,
                color: colorScheme.primary.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                "Coming Soon",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "Smart transit tracking and passes are on their way!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

  void _showCardDetails() async {
    if (_authToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Authentication session expired. Please login again.")),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await ApiService.getCardDetails(_authToken!);
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (res.isEmpty || res["card_number"] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not retrieve card details.")),
        );
        return;
      }

      setState(() {
      _cardNumber = res["card_number"];
      _cardCvv = res["cvv"].toString();
      _isCardLocked = res["card_lock"] == "LOCKED" || res["card_lock"] == true;
        
        final month = res["expiry_month"].toString().padLeft(2, '0');
        final year = res["expiry_year"].toString();
        final shortYear = year.length > 2 ? year.substring(year.length - 2) : year;
        _cardExpiry = "$month/$shortYear";
      });

      _displayCardDetailsDialog();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  void _showLockCardSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isCardLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  size: 44,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _isCardLocked ? "Unlock Card?" : "Lock Card?",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isCardLocked
                    ? "Unlocking will re-enable all your card transactions instantly."
                    : "Your card will be temporarily disabled for ATM, POS and online transactions.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_authToken == null) return;
                          Navigator.pop(sheetContext);
                          
                          // Show loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (dialogContext) => const Center(child: CircularProgressIndicator()),
                          );

                          bool success = false;
                          try {
                            if (_isCardLocked) {
                              final res = await ApiService.unlockCard(_authToken!);
                              success = res["success"] == true;
                            } else {
                              final res = await ApiService.lockCard(_authToken!);
                              success = res["success"] == true;
                            }
                          } catch (e) {
                            debugPrint("Error toggling card lock: $e");
                          }

                          if (mounted) Navigator.pop(context); // Close loading dialog

                          if (success) {
                            setState(() {
                              _isCardLocked = !_isCardLocked;
                            });
                            _showCardStatusDialog(
                              _isCardLocked
                                  ? "Card Locked Successfully"
                                  : "Card Unlocked Successfully",
                            );
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text("Failed to update card status. Please try again."),
                                  backgroundColor: colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _isCardLocked ? "Yes, Unlock" : "Yes, Lock",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }


  void _showCardStatusDialog(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Your card preferences have been updated successfully.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Great!",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  void _displayCardDetailsDialog() {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        bool isNumberHidden = true;
        bool isCvvHidden = true;

        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: StatefulBuilder(
            builder: (context, setState) {
              final String displayNum = isNumberHidden
                  ? "****\n****\n****\n${_cardNumber?.substring((_cardNumber?.length ?? 4) - 4) ?? "0000"}"
                  : _cardNumber?.replaceAllMapped(RegExp(r".{4}"), (match) => "${match.group(0)}\n").trim() ?? "0000\n0000\n0000\n0000";

              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Vertical Card Container
                    Container(
                      width: 260, // standard vertical ratio
                      height: 440,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: const [Color(0xFF4B5563), Color(0xFF374151)], // Ash grey for both themes
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 0,
                            spreadRadius: 1, // Inner subtle border
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Background Decorative Pattern
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: CustomPaint(
                                painter: CardBackgroundPainter(
                                  color: Colors.white,
                                  isDark: true, // Force low opacity decorations
                                ),
                              ),
                            ),
                          ),
                          
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Row: Bank Name & Contactless
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "LUME",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                    Icon(Icons.wifi_rounded, color: Colors.white.withOpacity(0.8), size: 28),
                                  ],
                                ),
                                const SizedBox(height: 30),
                                
                                // Chip & Tap Icon
                                Container(
                                  width: 42,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      colors: [Colors.amber.shade200, Colors.amber.shade400],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: CustomPaint(painter: ChipLinesPainter()),
                                ),
                                
                                const Spacer(),
                                
                                // Card Number (Vertical format)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayNum,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 4.0,
                                          height: 1.8,
                                          shadows: [
                                            Shadow(color: Colors.black.withOpacity(0.3), offset: const Offset(0, 2), blurRadius: 4),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        isNumberHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      onPressed: () => setState(() => isNumberHidden = !isNumberHidden),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 20),
                                
                              // Bottom Row: Name, Expiry, CVV
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // User Name
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "CARDHOLDER",
                                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8, letterSpacing: 1.0),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _userName.toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                            maxLines: 2,
                                            overflow: TextOverflow.visible,
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    const SizedBox(width: 8),

                                    // Valid Thru
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "VALID THRU",
                                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8, letterSpacing: 1.0),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _cardExpiry ?? "--/--",
                                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // CVV Row & RuPay
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "CVV",
                                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8, letterSpacing: 1.0),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              isCvvHidden ? "***" : _cardCvv ?? "---",
                                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () => setState(() => isCvvHidden = !isCvvHidden),
                                              child: Icon(
                                                isCvvHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                                color: Colors.white.withOpacity(0.7),
                                                size: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    
                                    // RuPay Logo Mock
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        _buildRuPayLogo(fontSize: 14),
                                        const SizedBox(height: 4),
                                        const Text(
                                          "PREPAID",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 2.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Close Button
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Text(
                          "Close",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
        );
      },
    );
  }

  Widget _buildCardActions(BuildContext context, ColorScheme colorScheme) {
    final iconColor = colorScheme.primary;

    Widget actionItem(IconData icon, String label, VoidCallback? onTap, {bool isEnabled = true}) {
      return Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: isEnabled ? onTap : null,
            child: Opacity(
              opacity: isEnabled ? 1.0 : 0.5,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: (isEnabled ? iconColor : Colors.grey).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: isEnabled ? iconColor : Colors.grey, size: 32),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isEnabled 
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.grey,
            ),
          )
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        actionItem(
          Icons.visibility_rounded,
          "View Details",
          () => _showCardDetails(),
          isEnabled: !_isCardBlocked,
        ),
        actionItem(
          _isCardLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
          _isCardLocked ? "Unlock Card" : "Lock Card",
          () {
            _showLockCardSheet();
          },
          isEnabled: !_isCardBlocked,
        ),
        actionItem(
          Icons.receipt_long_rounded,
          "Transactions",
          () => Navigator.pushNamed(context, "/transactions"),
          isEnabled: true, // Always allowed
        ),
        actionItem(
          Icons.settings_rounded,
          "Settings",
          () async {
            await Navigator.pushNamed(context, "/card-center");
            _loadUserProfile();
          },
          isEnabled: true, // Always allowed
        ),
      ],
    );
  }

  Widget _buildTransactionsSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Card Transactions",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, "/transactions"),
              child: Row(
                children: [
                  Text(
                    "View all",
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 18, color: colorScheme.primary),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_recentTransactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 48, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                const SizedBox(height: 12),
                Text(
                  "No transactions done",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ..._recentTransactions.take(5).map((tx) => _buildTransactionItem(tx, colorScheme)).toList(),
      ],
    );
  }

  Widget _buildTransactionItem(dynamic tx, ColorScheme colorScheme) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    IconData icon;
    Color iconColor;
    Color iconBgColor;
    Color amountColor;
    String prefix;

    switch (tx["type"]) {
      case "paid":
        icon = Icons.arrow_upward_rounded;
        iconColor = Colors.redAccent;
        iconBgColor = Colors.redAccent.withOpacity(0.1);
        amountColor = Colors.redAccent;
        prefix = "-";
        break;
      case "received":
        icon = Icons.arrow_downward_rounded;
        iconColor = Colors.green;
        iconBgColor = Colors.green.withOpacity(0.1);
        amountColor = Colors.green;
        prefix = "+";
        break;
      default: // topup
        icon = Icons.account_balance_wallet_rounded;
        iconColor = const Color(0xFF0284C7);
        iconBgColor = const Color(0xFFE0F2FE);
        amountColor = const Color(0xFF0284C7);
        prefix = "+";
    }

    Color statusColor;
    switch (tx["status"].toString().toLowerCase()) {
      case "success":
        statusColor = Colors.green;
        break;
      case "expired":
      case "cancelled":
        statusColor = Colors.redAccent;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(isDark ? 0.5 : 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx["title"],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tx["date"],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$prefix₹${tx["amount"].toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: amountColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tx["status"],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabKeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _TabKeepAliveWrapper({required this.child});

  @override
  State<_TabKeepAliveWrapper> createState() => _TabKeepAliveWrapperState();
}

class _TabKeepAliveWrapperState extends State<_TabKeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
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

class CardBackgroundPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  CardBackgroundPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(isDark ? 0.12 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Draw stylized card outlines in a pattern
    for (int i = 0; i < 6; i++) {
      final double xPos = size.width * (0.2 + (i % 2) * 0.4);
      final double yPos = size.height * (0.1 + i * 0.15);
      
      canvas.save();
      canvas.translate(xPos, yPos);
      canvas.rotate(0.2 * (i + 1));
      
      final rect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-60, -40, 120, 80),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, paint);
      
      // Draw a small "chip" inside
      final chipRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-45, -15, 20, 15),
        const Radius.circular(2),
      );
      canvas.drawRRect(chipRect, paint);
      
      canvas.restore();
    }

    // Add some soft decorative circles
    final dotPaint = Paint()
      ..color = color.withOpacity(isDark ? 0.06 : 0.04)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.15), 60, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.45), 40, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.8), 80, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CardBackgroundPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isDark != isDark;
  }
}

class HomeBackgroundPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  HomeBackgroundPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double opacity = isDark ? 0.12 : 0.08;
    final List<IconData> icons = [
      Icons.grid_view_rounded,
      Icons.widgets_rounded,
      Icons.layers_rounded,
      Icons.auto_awesome_mosaic_rounded,
    ];

    for (int i = 0; i < 8; i++) {
      final double xPos = size.width * (0.1 + (i % 3) * 0.35);
      final double yPos = size.height * (0.1 + i * 0.12);
      final IconData icon = icons[i % icons.length];
      
      _drawIcon(canvas, icon, Offset(xPos, yPos), 40, color.withOpacity(opacity));
    }
  }

  void _drawIcon(Canvas canvas, IconData icon, Offset center, double size, Color color) {
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant HomeBackgroundPainter oldDelegate) => 
      oldDelegate.color != color || oldDelegate.isDark != isDark;
}

class RewardsBackgroundPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  RewardsBackgroundPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double opacity = isDark ? 0.12 : 0.08;
    final List<IconData> icons = [
      Icons.card_giftcard_rounded,
      Icons.restaurant_rounded,
      Icons.attach_money_rounded,
      Icons.monetization_on_rounded,
    ];

    for (int i = 0; i < 8; i++) {
      final double xPos = size.width * (0.15 + (i % 3) * 0.32);
      final double yPos = size.height * (0.05 + i * 0.13);
      final IconData icon = icons[i % icons.length];
      
      _drawIcon(canvas, icon, Offset(xPos, yPos), 45, color.withOpacity(opacity));
    }
  }

  void _drawIcon(Canvas canvas, IconData icon, Offset center, double size, Color color) {
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant RewardsBackgroundPainter oldDelegate) => 
      oldDelegate.color != color || oldDelegate.isDark != isDark;
}

class TransitBackgroundPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  TransitBackgroundPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double opacity = isDark ? 0.12 : 0.08;
    final List<IconData> icons = [
      Icons.subway_rounded,
      Icons.directions_bus_rounded,
      Icons.flight_rounded,
      Icons.commute_rounded,
    ];

    for (int i = 0; i < 6; i++) {
      final double xPos = size.width * (0.2 + (i % 2) * 0.5);
      final double yPos = size.height * (0.1 + i * 0.15);
      final IconData icon = icons[i % icons.length];
      
      _drawIcon(canvas, icon, Offset(xPos, yPos), 42, color.withOpacity(opacity));
    }
  }

  void _drawIcon(Canvas canvas, IconData icon, Offset center, double size, Color color) {
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant TransitBackgroundPainter oldDelegate) => 
      oldDelegate.color != color || oldDelegate.isDark != isDark;
}
