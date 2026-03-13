import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:nfc_manager/nfc_manager.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../utils/campus_app_picker.dart';

enum WeatherCondition { sunny, cloudy, rainy, night, snow, thunder, sunrise, sunset }

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

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _flipController;
  late AnimationController _pulseController;
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
  bool _isCardFreezed = false;
  String _orderStatus = "NOT_REQUESTED";
  double _cardBalance = 0.0;
  double _ncmcBalance = 0.0;
  double _ncmcUnclaimedBalance = 0.0;
  String? _ncmcLastUpdated;
  bool _isPinSet = false;
  bool _isBalanceVisible = false;
  bool _isNcmcBalanceVisible = false;
  bool _isNcmcPrimary = false; // New: Tracks which balance is in front
  bool _hasActiveMandates = false; // Tracks if active mandates exist for the UI
  bool _isNfcAvailable = false; // Tracks device NFC capability

  // Transactions
  List<dynamic> _recentTransactions = [];

  // Weather & Greeting State
  String _weatherTemp = "--°C";
  String _weatherDesc = "Fetching...";
  IconData _weatherIcon = Icons.cloud_queue_rounded;
  WeatherCondition _currentCondition = WeatherCondition.cloudy;
  Timer? _clockTimer;
  Timer? _refreshTimer;
  late PageController _headerPageController;
  Timer? _headerAutoScrollTimer;
  int _currentHeaderPage = 0;

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
    WeatherCondition.snow: const WeatherTheme(
      gradientColors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1), Color(0xFF94A3B8)],
      icon: Icons.ac_unit_rounded,
      label: "Snowy",
      greetingSuffix: "❄️",
    ),
    WeatherCondition.thunder: const WeatherTheme(
      gradientColors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
      icon: Icons.thunderstorm_rounded,
      label: "Thunderstorm",
      greetingSuffix: "⚡",
    ),
    WeatherCondition.sunrise: const WeatherTheme(
      gradientColors: [Color(0xFFFF7E5F), Color(0xFFFEB47B)],
      icon: Icons.wb_twilight_rounded,
      label: "Sunrise",
      greetingSuffix: "🌅",
    ),
    WeatherCondition.sunset: const WeatherTheme(
      gradientColors: [Color(0xFF4B6CB7), Color(0xFF182848)],
      icon: Icons.wb_twilight_rounded,
      label: "Sunset",
      greetingSuffix: "🌇",
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
    _tabController.addListener(_handleTabSelection);

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _headerPageController = PageController(initialPage: 400); // Start at a multiple of 4
    _startHeaderAutoScroll();
    _animationController.forward();
    _loadUserProfile();
    CampusAppPicker.preload();
    _startClock();
    _startAutoRefresh();
    _checkNfcAvailability();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchWeather();
    });
  }

  void _startHeaderAutoScroll() {
    _headerAutoScrollTimer?.cancel();
    _headerAutoScrollTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (_headerPageController.hasClients) {
        _headerPageController.nextPage(
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutCubic,
        );
        HapticFeedback.selectionClick();
      }
    });
  }

  Future<void> _checkNfcAvailability() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (mounted) {
        setState(() {
          _isNfcAvailable = isAvailable;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isNfcAvailable = false;
        });
      }
    }
  }

  Future<void> _claimNcmcViaNfc() async {
    if (!_isNfcAvailable) return;

    // Show Tap Instruction
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 350,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            const Icon(Icons.contactless_rounded, size: 64, color: Colors.blueAccent),
            const SizedBox(height: 24),
            const Text("Ready to Scan", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text("Hold your Lume Card near the top back of your device to claim your transit balance.", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87, elevation: 0),
                child: const Text("CANCEL"),
              ),
            ),
          ],
        ),
      ),
    );

    // Simulation of NFC Scan and Claim
    // In a real app, this would use NfcManager.instance.startSession()
    // For this simulation/mock, we wait then claim.
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      Navigator.pop(context); // Close scan sheet
      
      // Execute the backend claim synchronously
      try {
        final res = await ApiService.claimNcmc(_authToken!);
        if (res["success"] == true) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Balance sync successful! Card updated."), backgroundColor: Colors.green));
          _loadUserProfile();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res["error"] ?? "Failed to sync card"), backgroundColor: Colors.red));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  void _startAutoRefresh() {
    // Refresh mandate/wallet data every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && (_tabController.index == 1 || _tabController.index == 3)) {
        _loadUserProfile();
      } else if (mounted && timer.tick % 4 == 0) {
        _loadUserProfile();
      }
      
      // Refresh weather every 30 minutes (60 ticks of 30 seconds)
      if (mounted && timer.tick % 60 == 0) {
        _fetchWeather();
      }
    });
  }

  void _handleTabSelection() {
    if (mounted) {
      // Re-trigger build to update header title etc.
      setState(() {});
      
      // Auto-refresh data when landing on Card or Transit Tab
      if (_tabController.index == 1 || _tabController.index == 3) {
        _loadUserProfile();
      }
    }
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
            _lumeStatus = (student["lume_status"] ?? "inactive")
                .toString()
                .toLowerCase();
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

          if (_studentId != null &&
              (_kycStatus.toLowerCase() == "rejected" ||
                  _kycStatus.toLowerCase() == "booked" ||
                  _kycStatus.toLowerCase() == "under process")) {
            try {
              final kycRes = await ApiService.getKycStatus(_studentId!);
              if (kycRes != null && kycRes is Map) {
                setState(() {
                  _kycRemarks = kycRes["remarks"];
                  if (kycRes["slot_date"] != null)
                    _kycSlotDate = kycRes["slot_date"];
                  if (kycRes["slot_time"] != null)
                    _kycSlotTime = kycRes["slot_time"];
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
              final String lockStatus = (cardRes["card_lock"] ?? "")
                  .toString()
                  .toUpperCase();
              final String cardState = (cardRes["card_state"] ?? "")
                  .toString()
                  .toUpperCase();

              setState(() {
                _isCardLocked =
                    lockStatus == "LOCKED" || cardRes["card_lock"] == true;
                _isCardBlocked =
                    lockStatus == "BLOCKED" || cardState == "BLOCKED";
                _isCardFreezed = cardRes["is_freezed"] == true;
                _orderStatus = cardRes["order_status"] ?? "NOT_REQUESTED";
                _isPinSet = cardRes["is_pin_set"] == true;
                _cardBalance = (cardRes["balance"] ?? 0.0).toDouble();
                _ncmcBalance = (cardRes["ncmc_balance"] ?? cardRes["transit_balance"] ?? 0.0).toDouble();
                _ncmcUnclaimedBalance = (cardRes["ncmc_unclaimed_balance"] ?? 0.0).toDouble();
                _ncmcLastUpdated = cardRes["ncmc_last_updated"];
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
          if (_kycSlotDate != null)
            await prefs.setString("kyc_slot_date", _kycSlotDate!);
          if (_kycSlotTime != null)
            await prefs.setString("kyc_slot_time", _kycSlotTime!);
          if (_studentId != null) await prefs.setInt("student_id", _studentId!);
          if (_profileImageUrl != null)
            await prefs.setString("user_profile_image", _profileImageUrl!);

          final txs = await ApiService.getTransactions(token);
          final mandateRes = await ApiService.getMandates(token);
          
          if (mounted) {
            _recentTransactions = txs;
            bool hasActive = false;
            final mandatesList = mandateRes["mandates"] as List? ?? [];
            for (var mandate in mandatesList) {
              final status = mandate["status"]?.toString().toUpperCase() ?? "";
              if (status == "ACTIVE" || status == "PAUSED") {
                hasActive = true;
                break;
              }
            }
            // also setting true if there are mandates even if paused, 
            // the button should be there to manage them if they exist at all.
            _hasActiveMandates = hasActive;
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
    if (mounted) setState(() {});
  }

  Future<void> _showNcmcRechargeDialog() async {
    final TextEditingController amountController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Transit Recharge"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter amount to recharge your transit card (Min: ₹100, Max: ₹2000)"),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Amount",
                  prefixText: "₹ ",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Enter amount";
                  final amt = double.tryParse(value);
                  if (amt == null) return "Invalid amount";
                  if (amt < 100) return "Min recharge ₹100";
                  if (amt > 2000) return "Max recharge ₹2000";
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final amt = double.parse(amountController.text);
                Navigator.pop(context); // Close input dialog
                
                // Show Loading
                showDialog(
                  context: this.context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final res = await ApiService.rechargeNcmc(_authToken!, amt);
                  if (mounted) Navigator.pop(this.context); // Close loading

                  if (res["success"] == true) {
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text("₹$amt added to unclaimed balance!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadUserProfile();
                  } else {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(res["error"] ?? "Failed to recharge"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) Navigator.pop(this.context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text("Error: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text("RECHARGE"),
          ),
        ],
      ),
    );
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
    _clockTimer?.cancel();
    _refreshTimer?.cancel();
    _headerAutoScrollTimer?.cancel();
    _tabController.removeListener(_handleTabSelection);
    _headerPageController.dispose();
    _animationController.dispose();
    _flipController.dispose();
    _pulseController.dispose();
    _tabController.dispose();
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
              title: Text(
                "Take Photo",
                style: TextStyle(color: colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: colorScheme.primary),
              title: Text(
                "Upload from Gallery",
                style: TextStyle(color: colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text(
                "Remove Photo",
                style: TextStyle(color: Colors.redAccent),
              ),
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
    } else if (_currentCondition == WeatherCondition.sunny &&
        hour >= 12 &&
        hour < 17) {
      return "Enjoy the sun";
    }

    return baseGreeting;
  }

  String _getFormattedDate() {
    return DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now());
  }

  // Real weather fetch using Geolocator and Open-Meteo
  Future<void> _fetchWeather() async {
    try {
      Position? position;
      try {
        // Reduced priority for faster fix, with timeout
        position = await _determinePosition().timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint("Weather: Error/Timeout getting position: $e");
      }
      
      double lat = 12.9716; // Fallback: Bangalore
      double lon = 77.5946;

      if (position != null) {
        lat = position.latitude;
        lon = position.longitude;
      }

      final url = Uri.parse(
        "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&daily=sunrise,sunset&timezone=auto",
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data["current_weather"];
        final double temp = current["temperature"] ?? 0.0;
        final int code = current["weathercode"] ?? 0;
        final int isDay = current["is_day"] ?? 1;
        
        // Sunrise/Sunset times
        String? sunriseStr;
        String? sunsetStr;
        if (data["daily"] != null) {
          sunriseStr = data["daily"]["sunrise"]?[0];
          sunsetStr = data["daily"]["sunset"]?[0];
        }

        if (mounted) {
          setState(() {
            _weatherTemp = "${temp.toStringAsFixed(1)}°C";
            _currentCondition = _mapWeatherCodeDetailed(code, isDay == 0, sunriseStr, sunsetStr);
            _weatherDesc = _weatherThemes[_currentCondition]!.label;
            _weatherIcon = _weatherThemes[_currentCondition]!.icon;
          });
        }
      } else {
        throw Exception("Weather API Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching weather: $e");
      // Hard fallback so it's not stuck on "Fetching..."
      if (mounted) {
        setState(() {
          _weatherTemp = "28°C";
          _weatherDesc = "Sunny";
          _currentCondition = WeatherCondition.sunny;
          _weatherIcon = _weatherThemes[_currentCondition]!.icon;
        });
      }
    }
  }

  Future<Position?> _determinePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        // This is where it asks the user for permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("Location permissions are denied.");
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("Location permissions are permanently denied.");
        return null;
      }

      // Check service after permission to be more proactive
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services are disabled.");
        return null;
      }

      // Try last known position first (instant)
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) return lastKnown;

      // Get current position with balanced accuracy for speed
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (e) {
      debugPrint("Location helper error: $e");
      return null;
    }
  }

  WeatherCondition _mapWeatherCodeDetailed(int code, bool isNight, String? sunrise, String? sunset) {
    final now = DateTime.now();

    // Check for Sunrise/Sunset periods (approx 30 mins window)
    try {
      if (sunrise != null) {
        final riseTime = DateTime.parse(sunrise);
        if (now.isAfter(riseTime.subtract(const Duration(minutes: 30))) &&
            now.isBefore(riseTime.add(const Duration(minutes: 30)))) {
          return WeatherCondition.sunrise;
        }
      }
      if (sunset != null) {
        final setTime = DateTime.parse(sunset);
        if (now.isAfter(setTime.subtract(const Duration(minutes: 30))) &&
            now.isBefore(setTime.add(const Duration(minutes: 30)))) {
          return WeatherCondition.sunset;
        }
      }
    } catch (_) {}

    // Thunderstorm
    if (code >= 95 && code <= 99) return WeatherCondition.thunder;

    // Snow
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) return WeatherCondition.snow;

    // Rainy
    if ((code >= 51 && code <= 65) || (code >= 80 && code <= 82)) return WeatherCondition.rainy;

    // Clear sky and Mainly Clear
    if (code == 0 || code == 1) return isNight ? WeatherCondition.night : WeatherCondition.sunny;
    
    // Partly cloudy, and overcast
    if (code == 2 || code == 3) return isNight ? WeatherCondition.night : WeatherCondition.cloudy;
    
    // Fog
    if (code == 45 || code == 48) return isNight ? WeatherCondition.night : WeatherCondition.cloudy;
    
    return isNight ? WeatherCondition.night : WeatherCondition.cloudy;
  }

  Widget _buildDrawer(BuildContext context, ColorScheme colorScheme) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color dashBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    // ================= STATUS UI LOGIC =================
    late Color statusColor;
    late Color chipBg;
    late IconData statusIcon;
    late String statusText;

    switch (_kycStatus.toLowerCase()) {
      case "completed":
      case "verified":
        statusColor = const Color(0xFF10B981); // Emerald Green
        chipBg = isDark ? statusColor.withOpacity(0.15) : const Color(0xFFECFDF5);
        statusIcon = Icons.check_circle_rounded;
        statusText = "KYC Verified";
        break;
      case "booked":
      case "under process":
        statusColor = const Color(0xFF3B82F6); // Lume Blue
        chipBg = isDark ? statusColor.withOpacity(0.15) : const Color(0xFFEFF6FF);
        statusIcon = Icons.event_available_rounded;
        statusText = "KYC Booked";
        break;
      case "rejected":
        statusColor = Colors.redAccent;
        chipBg = isDark ? statusColor.withOpacity(0.15) : const Color(0xFFFEF2F2);
        statusIcon = Icons.error_outline_rounded;
        statusText = "KYC Rejected";
        break;
      default:
        statusColor = Colors.orange;
        chipBg = isDark ? statusColor.withOpacity(0.15) : const Color(0xFFFFF7ED);
        statusIcon = Icons.pending_actions_rounded;
        statusText = "KYC Pending";
    }

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: dashBg,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
          // Enhanced Premium Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 64, 28, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                  colorScheme.primary.withOpacity(0.25),
                  dashBg,
                ]
                    : [
                  colorScheme.primary.withOpacity(0.1),
                  dashBg,
                ],
              ),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(40),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.primary.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Container(
                            key: ValueKey(_profileImageUrl),
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                              image:
                                  _profileImageUrl != null &&
                                          _profileImageUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            "${ApiService.baseUrl}/uploads/profile_pics/$_profileImageUrl",
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                            ),
                            child: _profileImageUrl == null ||
                                    _profileImageUrl!.isEmpty
                                ? Center(
                                    child: Text(
                                      _getInitials(_userName),
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: _isUploading ? null : _showImageOptions,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorScheme.surface,
                                  width: 2,
                                ),
                              ),
                              child: _isUploading
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.edit_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: chipBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 12, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusText.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                    letterSpacing: 0.5,
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
                const SizedBox(height: 24),
                // Quick Stats Strip
                Row(
                  children: [
                    _buildQuickInfo(
                      Icons.phone_android_rounded,
                      _userPhone,
                      colorScheme,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickInfo(
                        Icons.alternate_email_rounded,
                        _userEmail.isEmpty ? "No Email" : _userEmail,
                        colorScheme,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Drawer Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildDrawerSection("MAIN MENU", [
                  _buildDrawerItem(
                    Icons.person_rounded,
                    "My Profile",
                    colorScheme,
                    () async {
                      await Navigator.pushNamed(
                        context,
                        "/profile",
                        arguments: {
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
                          },
                        },
                      );
                      await _loadUserProfile();
                    },
                  ),
                  _buildDrawerItem(
                    Icons.credit_card_rounded,
                    "Virtual Card",
                    colorScheme,
                    () => _tabController.animateTo(1),
                  ),
                  _buildDrawerItem(
                    Icons.card_giftcard_rounded,
                    "My Rewards",
                    colorScheme,
                    () => _tabController.animateTo(2),
                  ),
                  _buildDrawerItem(
                    Icons.directions_bus_rounded,
                    "Transit",
                    colorScheme,
                    () => _tabController.animateTo(3),
                  ),
                ]),
                const SizedBox(height: 8),
                _buildDrawerSection("EXPLORE", [
                  _buildDrawerItem(
                    Icons.request_quote_rounded,
                    "Scholar Program",
                    colorScheme,
                    () => Navigator.pushNamed(context, "/scholar"),
                  ),
                  _buildDrawerItem(
                    Icons.location_city_rounded,
                    "My Campus",
                    colorScheme,
                    () => CampusAppPicker.show(context),
                  ),
                ]),
                const SizedBox(height: 8),
                _buildDrawerSection("PREFERENCES", [
                  _buildDrawerItem(
                    Icons.headset_mic_rounded,
                    "Support Center",
                    colorScheme,
                    () => Navigator.pushNamed(context, "/help-support"),
                  ),
                  _buildDrawerItem(
                    Icons.tune_rounded,
                    "App Settings",
                    colorScheme,
                    () => Navigator.pushNamed(context, "/app-settings"),
                  ),
                ]),
                const SizedBox(height: 8),
                _buildDrawerSection("ABOUT", [
                  _buildDrawerItem(
                    Icons.info_outline_rounded,
                    "About Lume",
                    colorScheme,
                    () => Navigator.pushNamed(context, "/about"),
                  ),
                  _buildDrawerItem(
                    Icons.description_outlined,
                    "Terms and Conditions",
                    colorScheme,
                    () => Navigator.pushNamed(context, "/terms"),
                  ),
                  _buildDrawerItem(
                    Icons.privacy_tip_outlined,
                    "Privacy Policy",
                    colorScheme,
                    () => Navigator.pushNamed(context, "/privacy"),
                  ),
                ]),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // Refined Footer
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      "/loginpin",
                      (_) => false,
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Logout",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Image.asset("assets/logo.png", height: 28),
                    const SizedBox(height: 4),
                    Text(
                      "v1.0.0",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfo(IconData icon, String text, ColorScheme colorScheme) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(isDark ? 0.4 : 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
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
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade500,
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    ColorScheme colorScheme,
    VoidCallback onTap,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: () {
          _scaffoldKey.currentState?.closeDrawer();
          onTap();
        },
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            letterSpacing: -0.2,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: colorScheme.onSurfaceVariant.withOpacity(0.3),
          size: 18,
        ),
      ),
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
                          transform: Matrix4.identity()
                            ..rotateY(3.141592653589793),
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
              child: CustomPaint(painter: BrushedMetalPainter()),
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
              child: Image.asset(
                "assets/logo.png",
                height: 200,
                color: Colors.white10,
              ),
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
                            border: Border.all(
                              color: Colors.black54,
                              width: 0.5,
                            ),
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
                        const Icon(
                          Icons.contactless_outlined,
                          color: Colors.white70,
                          size: 28,
                        ),
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
          if (_isCardLocked || _isCardBlocked || _isCardFreezed)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _isCardBlocked || _isCardLocked
                          ? Colors.redAccent.withOpacity(0.8)
                          : Colors.blueAccent.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isCardBlocked
                              ? Icons.block_rounded
                              : _isCardFreezed
                              ? Icons.ac_unit_rounded
                              : Icons.lock_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isCardBlocked
                              ? "BLOCKED"
                              : _isCardFreezed
                              ? "FROZEN"
                              : "LOCKED",
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
              // Decorative left strip
              Container(
                width: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.7),
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
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
                          Image.asset(
                            "assets/logos/university.png",
                            height: 35,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _userInstitute.isEmpty
                                  ? "UNIVERSITY NAME"
                                  : _userInstitute,
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
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 1,
                              ),
                              image:
                                  _profileImageUrl != null &&
                                      _profileImageUrl!.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(
                                        "${ApiService.baseUrl}/uploads/profile_pics/$_profileImageUrl",
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child:
                                _profileImageUrl == null ||
                                    _profileImageUrl!.isEmpty
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
                                _buildCardDetailRow(
                                  "STUDENT ID",
                                  _userRegNo.isEmpty ? "-" : _userRegNo,
                                ),
                                const SizedBox(height: 5),
                                _buildCardDetailRow(
                                  "BATCH",
                                  _userBatch.isEmpty ? "-" : _userBatch,
                                ),
                                const SizedBox(height: 5),
                                _buildCardDetailRow(
                                  "PHONE",
                                  _userPhone.isEmpty ? "-" : _userPhone,
                                ),
                                const SizedBox(height: 5),
                                _buildCardDetailRow(
                                  "BLOOD GR",
                                  _userBloodGroup.isEmpty
                                      ? "-"
                                      : _userBloodGroup,
                                ),
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
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: QrImageView(
                              data: _userRegNo.isEmpty
                                  ? "LUME_STUDENT"
                                  : _userRegNo,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isCardBlocked
                              ? Icons.block_rounded
                              : Icons.lock_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
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
            const Color(0xFF7C3AED).withOpacity(0.4), // Metallic Purple
            const Color(0xFF7C3AED).withOpacity(0.1),
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

  Widget _buildProfileIcon({
    required ColorScheme colorScheme,
    bool isOnDark = false,
  }) {
    final Color iconColor = isOnDark ? Colors.white : colorScheme.primary;
    final Color borderColor = isOnDark
        ? Colors.white.withOpacity(0.5)
        : colorScheme.primary.withOpacity(0.2);
    final Color bgColor = isOnDark
        ? Colors.white.withOpacity(0.2)
        : colorScheme.primary.withOpacity(0.1);

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
          backgroundColor: isOnDark
              ? Colors.white24
              : colorScheme.primary.withOpacity(0.05),
          backgroundImage:
              _profileImageUrl != null && _profileImageUrl!.isNotEmpty
              ? NetworkImage(
                  "${ApiService.baseUrl}/uploads/profile_pics/$_profileImageUrl",
                )
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
              child: Icon(
                Icons.wb_sunny_rounded,
                size: 200,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: Icon(
                Icons.wb_sunny_rounded,
                size: 100,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ],
        );
      case WeatherCondition.cloudy:
        return Stack(
          children: [
            Positioned(
              top: 20,
              right: 20,
              child: Icon(
                Icons.cloud_rounded,
                size: 180,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            Positioned(
              bottom: 40,
              left: -30,
              child: Icon(
                Icons.cloud_rounded,
                size: 140,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ],
        );
      case WeatherCondition.rainy:
        return Stack(
          children: [
            Positioned(
              top: 0,
              right: 40,
              child: Icon(
                Icons.umbrella_rounded,
                size: 160,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            ...List.generate(
              15,
              (index) => Positioned(
                top: (index * 20) % 200,
                left: (index * 30) % 400,
                child: Icon(
                  Icons.water_drop_rounded,
                  size: 12,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ),
          ],
        );
      case WeatherCondition.night:
        return Stack(
          children: [
            Positioned(
              top: 10,
              right: 30,
              child: Icon(
                Icons.nightlight_round,
                size: 120,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            ...List.generate(
              20,
              (index) => Positioned(
                top: (index * 15) % 250.0,
                left: (index * 25) % 450.0,
                child: Icon(
                  Icons.star_rounded,
                  size: 8,
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
            ),
          ],
        );
      case WeatherCondition.snow:
        return Stack(
          children: List.generate(
            25,
            (index) => Positioned(
              top: (index * 12) % 240.0,
              left: (index * 18) % 420.0,
              child: Icon(
                Icons.ac_unit_rounded,
                size: 10 + (index % 10).toDouble(),
                color: Colors.white.withOpacity(0.2),
              ),
            ),
          ),
        );
      case WeatherCondition.thunder:
        return Stack(
          children: [
            Positioned(
              top: 10,
              right: 20,
              child: Icon(
                Icons.thunderstorm_rounded,
                size: 160,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            ...List.generate(
              3,
              (index) => Positioned(
                top: 40 + (index * 20),
                left: 60 + (index * 40),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 40,
                  color: Colors.yellowAccent.withOpacity(0.2),
                ),
              ),
            ),
          ],
        );
      case WeatherCondition.sunrise:
        return Stack(
          children: [
            Positioned(
              bottom: -20,
              left: 40,
              child: Icon(
                Icons.wb_twilight_rounded,
                size: 180,
                color: Colors.orangeAccent.withOpacity(0.2),
              ),
            ),
          ],
        );
      case WeatherCondition.sunset:
        return Stack(
          children: [
            Positioned(
              bottom: -20,
              right: 40,
              child: Icon(
                Icons.wb_twilight_rounded,
                size: 180,
                color: Colors.redAccent.withOpacity(0.15),
              ),
            ),
          ],
        );
    }
  }



  Widget _buildWeatherAndGreetingSlide() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _weatherThemes[_currentCondition]!.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Dynamic Weather Accents
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 1000),
          child: Container(
            key: ValueKey(_currentCondition),
            child: _buildWeatherAccents(),
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
                        shadows: [
                          Shadow(color: Colors.black.withOpacity(0.2), offset: const Offset(0, 1), blurRadius: 3),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        height: 1.1,
                        shadows: [
                          Shadow(color: Colors.black.withOpacity(0.3), offset: const Offset(0, 2), blurRadius: 4),
                        ],
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
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(color: Colors.black.withOpacity(0.1), offset: const Offset(0, 1), blurRadius: 2),
                            ],
                          ),
                        ),
                        Text(
                          _weatherDesc.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
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
    );
  }

  Widget _buildCashbackSlide() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark 
                  ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
                  : [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Animated Money Background
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Stack(
                children: [
                  // Large Pulsing Money Icon
                  Positioned(
                    right: -50,
                    top: -50,
                    child: Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.15),
                      child: Opacity(
                        opacity: 0.12,
                        child: Icon(
                          Icons.payments_rounded,
                          size: 280,
                          color: Colors.greenAccent.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                  // Floating Money Particles
                  ...List.generate(6, (index) {
                    final double progress = (_pulseController.value + (index / 6)) % 1.0;
                    return Positioned(
                      right: 40 + (index * 30).toDouble(),
                      top: 10 + (progress * 100),
                      child: Opacity(
                        opacity: (1.0 - progress) * 0.4,
                        child: Transform.rotate(
                          angle: progress * 6.28,
                          child: const Icon(
                            Icons.attach_money_rounded,
                            size: 24,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.25),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "LIMITED TIME",
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Upto 10% Cashback",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              shadows: [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
                            ),
                          ),
                          Text(
                            "on your first Top-Up",
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final refresh = await Navigator.pushNamed(context, '/add-money');
                        if (refresh == true) {
                          _loadUserProfile();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.indigo.shade800,
                        elevation: 6,
                        shadowColor: Colors.black45,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("Top-Up", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 45,
          right: 40,
          child: Transform.rotate(
                angle: -0.15,
                child: Transform.translate(
                  offset: const Offset(10, 0),
                  child: Container(
                    width: 140,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1F2937), Color(0xFF111827)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(8, 8),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Card Content
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            width: 20,
                            height: 15,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFDE68A), Color(0xFFD97706)],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Image.asset(
                            "assets/logos/rupay.png",
                            height: 14,
                            color: Colors.white.withOpacity(0.9),
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Text(
                            "LUME",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        // Shine effect
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.1),
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
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
      ],
    );
  }

  Widget _buildRewardsSlide() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
                  : [const Color(0xFF059669), const Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Interactive Animated Brand Coupons
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final List<Map<String, dynamic>> brands = [
                {"img": "assets/rewards/swiggy.png", "pos": const Offset(10, 5)},
                {"img": "assets/rewards/zomato.png", "pos": const Offset(110, 45)},
                {"img": "assets/rewards/flipkart.png", "pos": const Offset(10, 115)},
                {"img": "assets/rewards/amazon.png", "pos": const Offset(115, 135)},
                {"img": "assets/rewards/kfc.png", "pos": const Offset(120, -25)},
                {"img": "assets/rewards/ajio.png", "pos": const Offset(15, -35)},
                {"img": "assets/rewards/netflix.png", "pos": const Offset(210, 10)},
                {"img": "assets/rewards/spotify.png", "pos": const Offset(215, 120)},
                {"img": "assets/rewards/bookmyshow.png", "pos": const Offset(315, 5)},
                {"img": "assets/rewards/pvr.png", "pos": const Offset(320, 110)},
                {"img": "assets/rewards/mcdonalds.png", "pos": const Offset(10, 225)},
                {"img": "assets/rewards/reliance.png", "pos": const Offset(120, 245)},
                {"img": "assets/rewards/croma.png", "pos": const Offset(225, 230)},
                {"img": "assets/rewards/apple.png", "pos": const Offset(330, 215)},
                {"img": "assets/rewards/mmt.png", "pos": const Offset(220, -35)},
                {"img": "assets/rewards/goibibo.png", "pos": const Offset(325, -25)},
              ];

              return Stack(
                children: brands.asMap().entries.map((entry) {
                  final int i = entry.key;
                  final brand = entry.value;
                  final double angle = (i % 2 == 0 ? 0.15 : -0.15) + (sin(_pulseController.value * 3.14 + i) * 0.05);
                  final double floatY = sin(_pulseController.value * 3.14 + i) * 10;

                  return Positioned(
                    top: brand["pos"].dy + floatY,
                    right: brand["pos"].dx,
                    child: Transform.rotate(
                      angle: angle,
                      child: Container(
                        width: 90,
                        height: 55,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(4, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Stack(
                            children: [
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Image.asset(
                                    brand["img"].toString(),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              // Coupon Notch Effect
                              Positioned(
                                left: -5,
                                top: 20,
                                child: Container(
                                  width: 10,
                                  height: 15,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF064E3B)
                                        : const Color(0xFF059669),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        
        const Positioned(
          bottom: -20,
          right: -20,
          child: IgnorePointer(
            child: Icon(Icons.savings_rounded, size: 150, color: Colors.white10),
          ),
        ),

        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.25),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Enjoy huge discounts",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.1,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.4),
                                  offset: const Offset(0, 2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "with gift cards from 200+ brands",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.2),
                                  offset: const Offset(0, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        _tabController.animateTo(2);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: isDark ? const Color(0xFF065F46) : const Color(0xFF059669),
                        elevation: 8,
                        shadowColor: Colors.black45,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Explore",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNcmcRechargeSlide() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF083344), const Color(0xFF155E75)]
                  : [const Color(0xFF0891B2), const Color(0xFF0E7490)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Large Background Image Accent
        Positioned(
          right: -30,
          top: -20,
          child: Opacity(
            opacity: 0.15,
            child: Image.asset(
              "assets/images/train_bus.png",
              height: 280,
              fit: BoxFit.contain,
            ),
          ),
        ),
        
        Positioned(
          bottom: 40,
          left: 24,
          right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    "SMART TRAVEL",
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "Recharge NCMC Today",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 2),
              const Text(
                "Never run out of balance for your commute",
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _showNcmcRechargeDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0891B2),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Recharge Now", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              ),
            ],
          ),
        ),
      ],
    );
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
              // Background Gradient accents
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
              Positioned(
                bottom: -150,
                left: -100,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colorScheme.primary.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Fixed Premium Header (only on Home)
              if (isHome)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: size.height * 0.35,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Builder(
                      builder: (context) {
                        final bool isKycNotCompleted = _kycStatus.toLowerCase() != "completed";
                        final bool isCardNotRequested = _orderStatus == "NOT_REQUESTED";
                        final bool isNcmcRechargeVisible = _orderStatus == "RECEIVED" && _isPinSet;
                        
                        int totalHeaderSlides;
                        if (isKycNotCompleted) {
                          totalHeaderSlides = 2;
                        } else if (isCardNotRequested) {
                          // Weather, Order, Cashback, Rewards (4 slides, NCMC hidden)
                          totalHeaderSlides = 4; 
                        } else {
                          // KYC done and card ordered. Check if NCMC Recharge should be shown.
                          totalHeaderSlides = isNcmcRechargeVisible ? 4 : 3;
                        }

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            PageView.builder(
                              controller: _headerPageController,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentHeaderPage = index % totalHeaderSlides;
                                });
                              },
                              itemBuilder: (context, index) {
                                return AnimatedBuilder(
                                  animation: _headerPageController,
                                  builder: (context, child) {
                                    double value = 1.0;
                                    if (_headerPageController.position.haveDimensions) {
                                      value = (_headerPageController.page! - index);
                                      value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                                    } else {
                                      // Initial state before first frame
                                      if (index == _headerPageController.initialPage) {
                                        value = 1.0;
                                      } else {
                                        value = 0.7;
                                      }
                                    }

                                    return Opacity(
                                      opacity: value,
                                      child: Transform.scale(
                                        scale: value,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _buildHeaderSlide(index % totalHeaderSlides, isKycNotCompleted),
                                );
                              },
                            ),
                            
                            // Page Indicators
                            Positioned(
                              bottom: 20,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(totalHeaderSlides, (index) {
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    height: 6,
                                    width: _currentHeaderPage == index ? 20 : 6,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(_currentHeaderPage == index ? 0.9 : 0.4),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

              // Content Area
              Positioned.fill(
                top: isHome
                    ? (size.height * 0.35 - 28)
                    : (MediaQuery.of(context).padding.top + 56),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: isHome
                        ? const BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          )
                        : null,
                  ),
                  clipBehavior: isHome ? Clip.antiAlias : Clip.none,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _TabKeepAliveWrapper(
                        child: _buildHomeTab(context, colorScheme),
                      ),
                      _TabKeepAliveWrapper(
                        child: _buildCardTab(context, colorScheme, isHome),
                      ),
                      _TabKeepAliveWrapper(
                        child: _buildRewardsTab(context, colorScheme),
                      ),
                      _TabKeepAliveWrapper(
                        child: _buildTransitTab(context, colorScheme),
                      ),
                    ],
                  ),
                ),
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
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top,
                      ),
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
                child: _buildProfileIcon(
                  colorScheme: colorScheme,
                  isOnDark: isHome,
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
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
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.home_rounded), text: "Home"),
                    Tab(icon: Icon(Icons.credit_card_rounded), text: "Card"),
                    Tab(
                      icon: Icon(Icons.emoji_events_rounded),
                      text: "Rewards",
                    ),
                    Tab(
                      icon: Icon(Icons.directions_bus_rounded),
                      text: "Transit",
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }



  Widget _buildHeaderSlide(int index, bool isKycNotCompleted) {
    if (isKycNotCompleted) {
      switch (index) {
        case 0: return _buildWeatherAndGreetingSlide();
        case 1: return _buildKycSlide();
        default: return const SizedBox.shrink();
      }
    } else {
      final bool isCardNotRequested = _orderStatus == "NOT_REQUESTED";
      final bool isNcmcRechargeVisible = _orderStatus == "RECEIVED" && _isPinSet;

      if (isCardNotRequested) {
        switch (index) {
          case 0: return _buildWeatherAndGreetingSlide();
          case 1: return _buildOrderCardSlide();
          case 2: return _buildCashbackSlide();
          case 3: return _buildRewardsSlide();
          default: return const SizedBox.shrink();
        }
      } else {
        if (isNcmcRechargeVisible) {
          switch (index) {
            case 0: return _buildWeatherAndGreetingSlide();
            case 1: return _buildCashbackSlide();
            case 2: return _buildRewardsSlide();
            case 3: return _buildNcmcRechargeSlide();
            default: return const SizedBox.shrink();
          }
        } else {
          switch (index) {
            case 0: return _buildWeatherAndGreetingSlide();
            case 1: return _buildCashbackSlide();
            case 2: return _buildRewardsSlide();
            default: return const SizedBox.shrink();
          }
        }
      }
    }
  }

  Widget _buildKycSlide() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF7F1D1D), const Color(0xFF991B1B)]
                  : [const Color(0xFFEF4444), const Color(0xFFB91C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        // Interactive Animated Security Icons
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final List<Map<String, dynamic>> secureIcons = [
                {"icon": Icons.security_rounded, "pos": const Offset(10, 5)},
                {"icon": Icons.fingerprint_rounded, "pos": const Offset(110, 45)},
                {"icon": Icons.face_rounded, "pos": const Offset(10, 115)},
                {"icon": Icons.vpn_key_rounded, "pos": const Offset(115, 135)},
                {"icon": Icons.qr_code_scanner_rounded, "pos": const Offset(120, -25)},
                {"icon": Icons.shield_rounded, "pos": const Offset(15, -35)},
                {"icon": Icons.verified_user_rounded, "pos": const Offset(210, 10)},
                {"icon": Icons.lock_rounded, "pos": const Offset(215, 120)},
                {"icon": Icons.badge_rounded, "pos": const Offset(315, 5)},
                {"icon": Icons.security_update_good_rounded, "pos": const Offset(320, 110)},
              ];

              return Stack(
                children: [
                  // Pulsing Scan Rings
                  Center(
                    child: Container(
                      width: 300 * _pulseController.value,
                      height: 300 * _pulseController.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.15 * (1 - _pulseController.value)), width: 2),
                      ),
                    ),
                  ),
                  ...secureIcons.asMap().entries.map((entry) {
                    final int i = entry.key;
                    final item = entry.value;
                    final double angle = (sin(_pulseController.value * 3.14 + i) * 0.1);
                    final double floatY = sin(_pulseController.value * 3.14 + i) * 15;

                    return Positioned(
                      top: item["pos"].dy + floatY,
                      right: item["pos"].dx,
                      child: Transform.rotate(
                        angle: angle,
                        child: Icon(
                          item["icon"],
                          size: 40,
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
        
        const Positioned(
          bottom: -20,
          right: -20,
          child: IgnorePointer(
            child: Icon(Icons.verified_user_rounded, size: 150, color: Colors.white10),
          ),
        ),
        
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.security_rounded, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                const Text(
                                  "ACTION REQUIRED",
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Complete KYC",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              shadows: [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)],
                            ),
                          ),
                          Text(
                            "Unlock full card features & higher limits",
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        _tabController.animateTo(1);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFB91C1C),
                        elevation: 8,
                        shadowColor: Colors.black45,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("Complete KYC", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCardSlide() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Interactive Premium Background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [const Color(0xFF78350F), const Color(0xFF92400E), const Color(0xFF451A03)]
                    : [const Color(0xFFD97706), const Color(0xFFB45309), const Color(0xFF78350F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        
        // Interactive Animated Delivery/Logistic Icons
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final List<Map<String, dynamic>> deliveryIcons = [
                {"icon": Icons.local_shipping_rounded, "pos": const Offset(10, 5)},
                {"icon": Icons.map_rounded, "pos": const Offset(110, 45)},
                {"icon": Icons.home_work_rounded, "pos": const Offset(10, 115)},
                {"icon": Icons.location_on_rounded, "pos": const Offset(115, 135)},
                {"icon": Icons.explore_rounded, "pos": const Offset(120, -25)},
                {"icon": Icons.inventory_2_rounded, "pos": const Offset(15, -35)},
                {"icon": Icons.verified_rounded, "pos": const Offset(210, 10)},
                {"icon": Icons.route_rounded, "pos": const Offset(215, 120)},
                {"icon": Icons.delivery_dining_rounded, "pos": const Offset(315, 5)},
                {"icon": Icons.done_all_rounded, "pos": const Offset(320, 110)},
              ];

              return Stack(
                children: [
                  // Pulsing Delivery Zone Ring
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Container(
                      width: 250 * _pulseController.value,
                      height: 250 * _pulseController.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12 * (1 - _pulseController.value)),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  ...deliveryIcons.asMap().entries.map((entry) {
                    final int i = entry.key;
                    final item = entry.value;
                    final double floatY = sin(_pulseController.value * 3.14 + i) * 12;
                    final double angle = (cos(_pulseController.value * 3.14 + i) * 0.08);

                    return Positioned(
                      top: item["pos"].dy + floatY,
                      right: item["pos"].dx,
                      child: Transform.rotate(
                        angle: angle,
                        child: Icon(
                          item["icon"],
                          size: 38,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),

        // Floating Card Preview (Stylized)
        Positioned(
          right: 30,
          bottom: 75,
          child: Transform.rotate(
            angle: -0.15,
            child: Container(
              width: 135,
              height: 85,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F2937), Color(0xFF111827), Color(0xFF000000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 15,
                    offset: const Offset(6, 12),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(-1, -1),
                  ),
                ],
                border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.2),
              ),
              child: Stack(
                children: [
                   // Glossy Reflector Overlay
                   Positioned.fill(
                     child: Container(
                       decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(14),
                         gradient: LinearGradient(
                           colors: [Colors.white.withOpacity(0.0), Colors.white.withOpacity(0.03)],
                           begin: Alignment.topRight,
                           end: Alignment.bottomLeft,
                         ),
                       ),
                     ),
                   ),
                   // Chip
                   Positioned(
                     top: 15,
                     left: 15,
                     child: Container(
                       width: 26,
                       height: 20,
                       decoration: BoxDecoration(
                         gradient: const LinearGradient(
                           colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
                           begin: Alignment.topLeft,
                           end: Alignment.bottomRight,
                         ),
                         borderRadius: BorderRadius.circular(4),
                         boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
                       ),
                     ),
                   ),
                   // Contactless
                   Positioned(
                     bottom: 15,
                     right: 15,
                     child: Icon(Icons.contactless_rounded, color: Colors.white.withOpacity(0.7), size: 18),
                   ),
                   // Logo
                   Positioned(
                     top: 15,
                     right: 15,
                     child: const Text(
                       "LUME",
                       style: TextStyle(
                         color: Colors.white70,
                         fontSize: 11,
                         fontWeight: FontWeight.w900,
                         letterSpacing: 1.5,
                       ),
                     ),
                   ),
                ],
              ),
            ),
          ),
        ),

        // Main Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 75), // Push header text more down
              const Text(
                "Order Your\nPhysical Card",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -0.8,
                  shadows: [
                    Shadow(color: Colors.black45, offset: Offset(0, 3), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.52,
                child: Text(
                  "Get your contactless Lume card delivered right to your home.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 15), // Move button somewhat up (replacing Spacer)
              ElevatedButton(
                onPressed: () {
                  _showOrderCardFormSheet(context, colorScheme);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFB45309),
                  elevation: 12,
                  shadowColor: Colors.black.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Order Now", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Interactive PhonePe-style Card Stack
              Opacity(
                opacity: _kycStatus.toLowerCase() != "completed" ? 0.4 : 1.0,
                child: IgnorePointer(
                  ignoring: _kycStatus.toLowerCase() != "completed",
                  child: SizedBox(
                    height: 195,
                    width: double.infinity,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                  children: [
                    // Dynamic Depth Swapping: Back card built FIRST
                    if (_isNcmcPrimary) ...[
                      _buildInteractiveBalanceCard(
                        context,
                        colorScheme,
                        isNcmc: false,
                        key: const ValueKey("prepaid_card"),
                      ),
                      _buildInteractiveBalanceCard(
                        context,
                        colorScheme,
                        isNcmc: true,
                        key: const ValueKey("ncmc_card"),
                      ),
                    ] else ...[
                      _buildInteractiveBalanceCard(
                        context,
                        colorScheme,
                        isNcmc: true,
                        key: const ValueKey("ncmc_card"),
                      ),
                      _buildInteractiveBalanceCard(
                        context,
                        colorScheme,
                        isNcmc: false,
                        key: const ValueKey("prepaid_card"),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
              if (_hasActiveMandates)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/mandates'),
                    child: Container(
                      width: double.infinity,
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer.withOpacity(isDark ? 0.4 : 0.7),
                            colorScheme.surface,
                            colorScheme.primaryContainer.withOpacity(isDark ? 0.3 : 0.5),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Decorative Autopay-relevant background element
                          Positioned(
                            right: -20,
                            top: -10,
                            child: Transform.rotate(
                              angle: -0.2,
                              child: Container(
                                width: 140,
                                height: 180,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary.withOpacity(0.8),
                                      colorScheme.primary.withOpacity(0.4),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Icon(
                                    Icons.published_with_changes_rounded,
                                    size: 40,
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          // Content Row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Smart Recharge ON",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: colorScheme.onSurface,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Your wallet refills automatically\nand travel smart",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface.withOpacity(0.6),
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Manage Button
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    "Manage",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 8),

              _buildLumePartnerAd(context, colorScheme),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLumePartnerAd(BuildContext context, ColorScheme colorScheme) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Your Money's New Rhythm:",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withOpacity(isDark ? 0.6 : 0.35),
              height: 1.1,
              letterSpacing: -1.0,
            ),
          ),
          Text(
            "TAP. PAY. PROSPER.",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withOpacity(isDark ? 0.6 : 0.35),
              height: 1.1,
              letterSpacing: -1.0,
            ),
          ),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                colorScheme.primary,
                colorScheme.primary.withOpacity(0.8),
              ],
            ).createShader(bounds),
            child: const Text(
              "Experience Lume",
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -1.5,
              ),
            ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildPartnerLogo("assets/logos/npci.png", height: 28),
              _buildPartnerLogo("assets/logos/rupay.png", height: 22),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerLogo(String assetPath, {double height = 30}) {
    return Image.asset(
      assetPath,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Container(),
    );
  }

  Widget _buildInteractiveBalanceCard(
    BuildContext context,
    ColorScheme colorScheme, {
    required bool isNcmc,
    required Key key,
  }) {
    final bool isFront = isNcmc == _isNcmcPrimary;
    
    // Updated offsets for the "Stacked Strip" look from the image
    // Back card peeks out from TOP
    final double targetTop = isFront ? 45.0 : 0.0;
    final double targetLeft = 24.0;
    final double targetRight = 24.0;
    final double targetScale = isFront ? 1.0 : 0.95;
    final double targetOpacity = isFront ? 1.0 : 0.85;

    // Refined Tinted Colors matched with Dashboard UI
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Both cards now use the premium Silver/Slate theme for a uniform dashboard look
    final Color cardBg = isFront
        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC))
        : colorScheme.surface;
    
    final Color labelColor = isDark 
        ? Colors.white.withOpacity(0.9) 
        : const Color(0xFF475569); // High contrast label
        
    final Color patternColor = (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFCBD5E1).withOpacity(0.4));

    return AnimatedPositioned(
      key: key,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutSine,
      top: targetTop,
      left: targetLeft,
      right: targetRight,
      child: GestureDetector(
        onTap: isFront ? null : () => setState(() => _isNcmcPrimary = isNcmc),
        child: AnimatedScale(
          scale: targetScale,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: targetOpacity,
            duration: const Duration(milliseconds: 400),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isFront ? 0.08 : 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: isFront
                      ? colorScheme.primary.withOpacity(0.2)
                      : colorScheme.outlineVariant.withOpacity(0.2),
                  width: 1.2,
                ),
              ),
              child: Opacity(
                opacity: (isNcmc && _orderStatus != "RECEIVED") ? 0.4 : 1.0,
                child: IgnorePointer(
                  ignoring: (isNcmc && _orderStatus != "RECEIVED"),
                  child: Stack(
                    children: [
                      // Pattern Decoration
                      Positioned(
                        right: -20,
                        bottom: -20,
                        child: Opacity(
                          opacity: 0.6,
                          child: CustomPaint(
                            size: const Size(150, 150),
                            painter: CardPatternPainter(color: patternColor),
                          ),
                        ),
                      ),
                      
                      // Card Content
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: isNcmc
                            ? _buildNcmcCardContent(context, colorScheme, isFront, labelColor)
                            : _buildPrepaidCardContent(context, colorScheme, isFront, labelColor, showAddMoney: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }




  Widget _buildPrepaidCardContent(BuildContext context, ColorScheme colorScheme,
      bool isPrimary, Color labelColor,
      {bool showAddMoney = true}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "PREPAID WALLET",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: labelColor,
            letterSpacing: 0.8,
          ),
        ),
        if (isPrimary) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _kycStatus.toLowerCase() != "completed" 
                    ? null 
                    : () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                child: Text(
                  (_kycStatus.toLowerCase() == "completed" && _isBalanceVisible)
                      ? "₹ ${NumberFormat('#,##,##0.00').format(_cardBalance)}"
                      : "₹ • • • • • •",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white 
                        : const Color(0xFF1E293B),
                    letterSpacing: -1,
                  ),
                ),
              ),
              // Action Button
              if (showAddMoney)
                GestureDetector(
                  onTap: () async {
                    final refresh = await Navigator.pushNamed(context, '/add-money');
                    if (refresh == true) {
                      _loadUserProfile();
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          "Add Money",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _buildRuPayLogo(fontSize: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _kycStatus.toLowerCase() == "completed" 
                ? "Available Balance" 
                : "Complete KYC to Unlock",
            style: TextStyle(
              fontSize: 13,
              color: _kycStatus.toLowerCase() == "completed"
                  ? (isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.4))
                  : (isDark ? Colors.redAccent.withOpacity(0.8) : Colors.red.withOpacity(0.7)),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNcmcCardContent(BuildContext context, ColorScheme colorScheme, bool isPrimary, Color labelColor) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    String formattedUpdate = "Never";
    if (_ncmcLastUpdated != null) {
      try {
        DateTime dt = DateTime.parse(_ncmcLastUpdated!);
        formattedUpdate = DateFormat('dd MMM, hh:mm a').format(dt);
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "NCMC BALANCE",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: labelColor,
                letterSpacing: 0.8,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, "/ncmc-details"),
              child: Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: labelColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
        if (isPrimary) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _kycStatus.toLowerCase() != "completed" 
                        ? null 
                        : () async {
                        final wasHidden = !_isNcmcBalanceVisible;
                        setState(() {
                          _isNcmcBalanceVisible = !_isNcmcBalanceVisible;
                        });

                        // If unmasking, update last updated timestamp in backend
                        if (wasHidden && _authToken != null) {
                          try {
                            final res = await ApiService.updateNcmcTimestamp(_authToken!);
                            if (res["success"] == true && mounted) {
                              setState(() {
                                _ncmcLastUpdated = res["ncmc_last_updated"];
                              });
                            }
                          } catch (e) {
                            debugPrint("Error updating NCMC timestamp: $e");
                          }
                        }
                      },
                      child: Text(
                        (_kycStatus.toLowerCase() == "completed" && _orderStatus == "RECEIVED" && _isNcmcBalanceVisible)
                            ? "₹ ${NumberFormat('#,##,##0.00').format(_ncmcBalance)}"
                            : "₹ • • • • • •",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white 
                              : const Color(0xFF1E293B),
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    Text(
                      _kycStatus.toLowerCase() != "completed"
                          ? "Complete KYC to Unlock"
                          : (_orderStatus != "RECEIVED"
                              ? "Order your Lume Card to Unlock"
                              : "Last Updated: $formattedUpdate"),
                      style: TextStyle(
                        fontSize: 10,
                        color: (_kycStatus.toLowerCase() == "completed" && _orderStatus == "RECEIVED")
                            ? (isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.4))
                            : (isDark ? Colors.redAccent.withOpacity(0.8) : Colors.red.withOpacity(0.7)),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_ncmcUnclaimedBalance > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: GestureDetector(
                          onTap: _isNfcAvailable ? _claimNcmcViaNfc : null,
                          child: Text(
                            "Unclaimed Balance: ₹${_ncmcUnclaimedBalance.toStringAsFixed(2)} ${_isNfcAvailable ? 'Tap to Claim' : 'Claim at Kiosk'}",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "Unclaimed Balance: ₹0.00",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Action Button
              GestureDetector(
                onTap: _showNcmcRechargeDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        "Recharge",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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
                  border: Border.all(
                    color: colorScheme.outlineVariant.withOpacity(0.5),
                  ),
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
                                  color: colorScheme.primaryContainer
                                      .withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.wallet_rounded,
                                  color: colorScheme.primary,
                                  size: 22,
                                ),
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
                                  color: colorScheme.primaryContainer
                                      .withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.currency_rupee_rounded,
                                  color: colorScheme.primary,
                                  size: 22,
                                ),
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
                              color: Colors.black.withOpacity(
                                isDark ? 0.3 : 0.04,
                              ),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: colorScheme.outlineVariant.withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withOpacity(
                                  0.3,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.badge_rounded,
                                color: colorScheme.primary,
                                size: 22,
                              ),
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
                              color: Colors.black.withOpacity(
                                isDark ? 0.3 : 0.04,
                              ),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: colorScheme.outlineVariant.withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withOpacity(
                                  0.3,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.wifi_rounded,
                                color: colorScheme.primary,
                                size: 22,
                              ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
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
                                onTap: () =>
                                    Navigator.pushNamed(context, '/terms'),
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
                                onTap: () =>
                                    Navigator.pushNamed(context, '/privacy'),
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
              onPressed: !_isTermsAccepted
                  ? null
                  : () async {
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKYCUnderProcessView(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
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
                  border: Border.all(
                    color: colorScheme.outlineVariant.withOpacity(0.5),
                  ),
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
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
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
                backgroundColor: _isSlotTimeReached()
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.12),
                foregroundColor: _isSlotTimeReached()
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface.withOpacity(0.04),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: _isSlotTimeReached() ? 4 : 0,
                shadowColor: colorScheme.primary.withOpacity(0.3),
              ),
              child: Text(
                _isSlotTimeReached()
                    ? "Continue"
                    : "Waiting for Confirmation...",
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

  Widget _buildCardTab(BuildContext context, ColorScheme colorScheme, bool isHome) {
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
          padding: EdgeInsets.symmetric(
              horizontal: 24.0, vertical: isHome ? 20 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_kycStatus == "Completed") ...[
                _buildBalanceStrip(colorScheme),
                const SizedBox(height: 24),
                _buildFlippingCard(context, colorScheme),
                const SizedBox(height: 30),
                _buildCardActions(context, colorScheme),

                const SizedBox(height: 35),
                if (_orderStatus == "NOT_REQUESTED")
                  _buildOrderCardSuggestion(context, colorScheme)
                else if (_orderStatus != "RECEIVED")
                  _buildOrderStatusCard(context, colorScheme),

                const SizedBox(height: 35),

                _buildTransactionsSection(context, colorScheme),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceStrip(ColorScheme colorScheme) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Matching the Home tab's premium Silver/Slate colors
    final Color cardBg =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final Color labelColor =
        isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF475569);
    final Color patternColor = isDark
        ? Colors.white.withOpacity(0.05)
        : const Color(0xFFCBD5E1).withOpacity(0.4);

    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
          width: 1.2,
        ),
      ),
      child: Stack(
        children: [
          // Background Pattern
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: CustomPaint(
                painter: CardPatternPainter(color: patternColor),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildPrepaidCardContent(context, colorScheme, true, labelColor,
                showAddMoney: false),
          ),
        ],
      ),
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
                  border: Border.all(
                    color: colorScheme.outlineVariant.withOpacity(0.5),
                  ),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.stars_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Redeem",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                  TextButton(onPressed: () {}, child: const Text("View All")),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildOfferCard(
                      "20% Off",
                      "At Campus Store",
                      Icons.shopping_bag_rounded,
                      Colors.blue,
                    ),
                    _buildOfferCard(
                      "Free Coffee",
                      "At Red Cup Cafe",
                      Icons.coffee_rounded,
                      Colors.brown,
                    ),
                    _buildOfferCard(
                      "BOGO Movie",
                      "PVR Cinemas",
                      Icons.movie_rounded,
                      Colors.red,
                    ),
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
                  _buildCategoryIcon(
                    Icons.restaurant_rounded,
                    "Food",
                    Colors.green,
                  ),
                  _buildCategoryIcon(
                    Icons.shopping_cart_rounded,
                    "Shop",
                    Colors.purple,
                  ),
                  _buildCategoryIcon(
                    Icons.local_taxi_rounded,
                    "Travel",
                    Colors.amber,
                  ),
                  _buildCategoryIcon(
                    Icons.sports_esports_rounded,
                    "Games",
                    Colors.pink,
                  ),
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
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: (_kycStatus.toLowerCase() != "completed" || _orderStatus != "RECEIVED") ? 0.4 : 1.0,
                child: IgnorePointer(
                  ignoring: (_kycStatus.toLowerCase() != "completed" || _orderStatus != "RECEIVED"),
                  child: _buildNcmcBalanceStrip(colorScheme),
                ),
              ),
              const SizedBox(height: 20),
              _buildNcmcRechargeBanner(colorScheme),
              const SizedBox(height: 35),
              _buildTransactionsSection(context, colorScheme, isTransit: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNcmcBalanceStrip(ColorScheme colorScheme) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Matching the Home tab's premium Silver/Slate colors
    final Color cardBg =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final Color labelColor =
        isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF475569);
    final Color patternColor = isDark
        ? Colors.white.withOpacity(0.05)
        : const Color(0xFFCBD5E1).withOpacity(0.4);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
          width: 1.2,
        ),
      ),
      child: Stack(
        children: [
          // Background Pattern
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: CustomPaint(
                painter: CardPatternPainter(color: patternColor),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: _buildNcmcCardContent(context, colorScheme, true, labelColor),
          ),
        ],
      ),
    );
  }

  Widget _buildNcmcRechargeBanner(ColorScheme colorScheme) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color patternColor = isDark
        ? Colors.white.withOpacity(0.05)
        : const Color(0xFFCBD5E1).withOpacity(0.4);

    return Container(
      width: double.infinity,
      height: 110,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(isDark ? 0.4 : 0.7),
            colorScheme.surface,
            colorScheme.primaryContainer.withOpacity(isDark ? 0.3 : 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.15),
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.5,
              child: CustomPaint(
                painter: CardPatternPainter(color: patternColor),
              ),
            ),
          ),

          // Tilted Accent Box (Matching Smart Recharge style)
          Positioned(
            left: -35,
            top: -15,
            child: Transform.rotate(
              angle: 0.2, // Tilted slightly to the right for the left side
              child: Container(
                width: 160,
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(isDark ? 0.4 : 0.3),
                      colorScheme.primary.withOpacity(isDark ? 0.2 : 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
            ),
          ),

          // Illustration
          Positioned(
            left: -60,
            top: -20,
            bottom: -60,
            width: 280,
            child: Opacity(
              opacity: 0.95,
              child: Image.asset(
                "assets/images/train_bus.png",
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Text Content
          Positioned(
            left: 175,
            right: 16,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Recharge NCMC",
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "card today!",
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 11),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      _buildMiniBrandLogo("assets/banks/pnb.png"),
                      const SizedBox(width: 8),
                      _buildMiniBrandLogo("assets/banks/airtel.png"),
                      const SizedBox(width: 8),
                      _buildMiniBrandLogo("assets/banks/hdfc.png"),
                      const SizedBox(width: 8),
                      _buildMiniBrandLogo("assets/banks/sbi.png"),
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

  Widget _buildMiniBrandLogo(String path) {
    return SizedBox(
      width: 34,
      height: 20,
      child: Image.asset(
        path,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildOfferCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
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
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
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
        const SnackBar(
          content: Text("Authentication session expired. Please login again."),
        ),
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
        _isCardLocked =
            res["card_lock"] == "LOCKED" || res["card_lock"] == true;

        final month = res["expiry_month"].toString().padLeft(2, '0');
        final year = res["expiry_year"].toString();
        final shortYear = year.length > 2
            ? year.substring(year.length - 2)
            : year;
        _cardExpiry = "$month/$shortYear";
      });

      _displayCardDetailsDialog();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
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
                          side: BorderSide(
                            color: colorScheme.outlineVariant.withOpacity(0.5),
                          ),
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
                            builder: (dialogContext) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );

                          bool success = false;
                          try {
                            if (_isCardLocked) {
                              final res = await ApiService.unlockCard(
                                _authToken!,
                              );
                              success = res["success"] == true;
                            } else {
                              final res = await ApiService.lockCard(
                                _authToken!,
                              );
                              success = res["success"] == true;
                            }
                          } catch (e) {
                            debugPrint("Error toggling card lock: $e");
                          }

                          if (mounted)
                            Navigator.pop(context); // Close loading dialog

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
                                  content: const Text(
                                    "Failed to update card status. Please try again.",
                                  ),
                                  backgroundColor: colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                  : _cardNumber
                            ?.replaceAllMapped(
                              RegExp(r".{4}"),
                              (match) => "${match.group(0)}\n",
                            )
                            .trim() ??
                        "0000\n0000\n0000\n0000";

              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Vertical Card Container
                    Container(
                      width: 260, // standard vertical ratio
                      height: 440,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: const [
                            Color(0xFF4B5563),
                            Color(0xFF374151),
                          ], // Ash grey for both themes
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                    Icon(
                                      Icons.wifi_rounded,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 28,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 30),

                                // Chip & Tap Icon
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    width: 42,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.amber.shade200,
                                          Colors.amber.shade400,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: CustomPaint(
                                      painter: ChipLinesPainter(),
                                    ),
                                  ),
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
                                            Shadow(
                                              color: Colors.black.withOpacity(
                                                0.3,
                                              ),
                                              offset: const Offset(0, 2),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        isNumberHidden
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      onPressed: () => setState(
                                        () => isNumberHidden = !isNumberHidden,
                                      ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "CARDHOLDER",
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.5,
                                              ),
                                              fontSize: 8,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _userName.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5,
                                            ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "VALID THRU",
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.5,
                                              ),
                                              fontSize: 8,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _cardExpiry ?? "--/--",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.0,
                                            ),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "CVV",
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                            fontSize: 8,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              isCvvHidden
                                                  ? "***"
                                                  : _cardCvv ?? "---",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 2.0,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () => setState(
                                                () =>
                                                    isCvvHidden = !isCvvHidden,
                                              ),
                                              child: Icon(
                                                isCvvHidden
                                                    ? Icons
                                                          .visibility_off_rounded
                                                    : Icons.visibility_rounded,
                                                color: Colors.white.withOpacity(
                                                  0.7,
                                                ),
                                                size: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    // RuPay Logo Mock
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
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
            },
          ),
        );
      },
    );
  }

  Widget _buildCardActions(BuildContext context, ColorScheme colorScheme) {
    final iconColor = colorScheme.primary;

    Widget actionItem(
      IconData icon,
      String label,
      VoidCallback? onTap, {
      bool isEnabled = true,
    }) {
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
                  color: (isEnabled ? iconColor : Colors.grey).withOpacity(
                    0.15,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? iconColor : Colors.grey,
                  size: 32,
                ),
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
          ),
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

  Widget _buildTransactionsSection(
    BuildContext context,
    ColorScheme colorScheme, {
    bool isTransit = false,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    final displayList = _recentTransactions.where((tx) {
      final category = tx["category"]?.toString() ?? "Card";
      return isTransit ? category.toLowerCase() == "transit" : category.toLowerCase() != "transit";
    }).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Transactions",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, "/transactions", arguments: {"initialTab": isTransit ? 1 : 0}),
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
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
          ),
          if (displayList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
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
            ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayList.length > 5 ? 5 : displayList.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
                indent: 64,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final tx = displayList[index];
                return _buildTransactionItem(tx, colorScheme, isInsideTile: true);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOrderCardSuggestion(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: double.infinity,
      height: 155, // Increased height for better spacing
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  colorScheme.surface,
                  colorScheme.surface.withOpacity(0.8),
                  colorScheme.primary.withOpacity(0.1),
                ]
              : [
                  Colors.white,
                  colorScheme.primary.withOpacity(0.05),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isDark
              ? colorScheme.primary.withOpacity(0.2)
              : colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Rotated stylized Lume Card
            Positioned(
              right: -90, // Slightly more tucked
              top: 10,
              child: Transform.rotate(
                angle: -0.3,
                child: Container(
                  width: 220,
                  height: 250,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1F2937),
                        Color(0xFF374151),
                        Color(0xFF111827),
                        Color(0xFF1F2937),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [0.0, 0.4, 0.6, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: isDark 
                        ? Border.all(color: Colors.white.withOpacity(0.1), width: 1.5)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(-5, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      const Positioned(
                        top: 24,
                        left: 24,
                        child: Text(
                          "🄻🅄🄼🄴",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 24,
                        right: 32, // Moved further right away from the logo
                        child: Transform.rotate(
                          angle: 1.57,
                          child: const Icon(
                            Icons.contactless_outlined,
                            color: Colors.white70,
                            size: 22,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 80,
                        left: 24,
                        child: Container(
                          width: 35,
                          height: 25,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Left side content: Using Column to prevent vertical overlap
            Positioned(
              left: 20,
              top: 0,
              bottom: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Order Lume Card Today!",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: screenWidth * 0.44, // Optimized width
                    child: Text(
                      "Order your physical card TAP, PAY and EARN!!!",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.9),
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16), // Fixed spacing
                  ElevatedButton(
                    onPressed: () => _showOrderCardFormSheet(context, colorScheme),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      elevation: 4,
                      shadowColor: colorScheme.primary.withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size(0, 42),
                    ),
                    child: const Text(
                      "Order now",
                      style: TextStyle(
                        fontSize: 13,
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
    );
  }

  void _showOrderCardFormSheet(BuildContext context, ColorScheme colorScheme) {
    final TextEditingController addressController = TextEditingController();
    final TextEditingController cityController = TextEditingController();
    final TextEditingController stateController = TextEditingController();
    final TextEditingController pincodeController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          bool isFetchingPincode = false;

          bool isFormValid() {
            return addressController.text.trim().isNotEmpty &&
                cityController.text.trim().isNotEmpty &&
                stateController.text.trim().isNotEmpty &&
                pincodeController.text.trim().isNotEmpty &&
                phoneController.text.trim().isNotEmpty;
          }

          void checkPincode(String value) async {
            if (value.length == 6) {
              setSheetState(() => isFetchingPincode = true);
              try {
                final data = await ApiService.getPincodeDetails(value);
                if (data != null && data is List && data.isNotEmpty) {
                  final status = data[0]["Status"];
                  if (status == "Success") {
                    final postOffice = data[0]["PostOffice"][0];
                    cityController.text = postOffice["District"];
                    stateController.text = postOffice["State"];
                  }
                }
              } catch (_) {}
              if (mounted) {
                setSheetState(() => isFetchingPincode = false);
              }
            }
          }

          Widget buildTextField(
              String label, IconData icon, TextEditingController controller,
              {TextInputType? keyboardType,
              bool isReadOnly = false,
              Widget? suffix}) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  readOnly: isReadOnly,
                  onChanged: (val) {
                    setSheetState(() {});
                    if (label == "Pincode") {
                      checkPincode(val);
                    }
                  },
                  decoration: InputDecoration(
                    prefixIcon:
                        Icon(icon, color: colorScheme.primary, size: 20),
                    suffixIcon: suffix,
                    hintText: "Enter $label",
                    filled: true,
                    fillColor: isReadOnly
                        ? colorScheme.surfaceVariant.withOpacity(0.1)
                        : colorScheme.surfaceVariant.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(18),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              top: 32,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Delivery Details",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Please provide your permanent address for physical card delivery.",
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  buildTextField(
                      "Full Address", Icons.home_rounded, addressController),
                  Row(
                    children: [
                      Expanded(
                        child: buildTextField(
                            "Pincode", Icons.pin_drop_rounded, pincodeController,
                            keyboardType: TextInputType.number,
                            suffix: isFetchingPincode
                                ? Transform.scale(
                                    scale: 0.5,
                                    child: const CircularProgressIndicator(
                                        strokeWidth: 3),
                                  )
                                : null),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: buildTextField("Phone Number",
                            Icons.phone_android_rounded, phoneController,
                            keyboardType: TextInputType.phone),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: buildTextField(
                            "City", Icons.location_city_rounded, cityController,
                            isReadOnly: true),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: buildTextField(
                            "State", Icons.map_rounded, stateController,
                            isReadOnly: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isFormValid()
                          ? () async {
                              Navigator.pop(context); // Close sheet
                              _executeOrderCard({
                                "address": addressController.text.trim(),
                                "city": cityController.text.trim(),
                                "state": stateController.text.trim(),
                                "pincode": pincodeController.text.trim(),
                                "phone": phoneController.text.trim(),
                              });
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            colorScheme.onSurface.withOpacity(0.12),
                        disabledForegroundColor:
                            colorScheme.onSurface.withOpacity(0.38),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Order Physical Card",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _executeOrderCard(Map<String, String> details) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await ApiService.orderCard(_authToken!, details);
      if (mounted) Navigator.pop(context); // Close loading

      if (res["success"] == true) {
        setState(() {
          _orderStatus = "ORDERED";
        });
        _showCardStatusDialog("Card Ordered Successfully!");
        HapticFeedback.heavyImpact();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res["error"] ?? "Failed to order card"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool?> _showDeliveryConfirmationSheet() {
    final colorScheme = Theme.of(context).colorScheme;

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mark_as_unread_rounded,
                color: colorScheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Card Received?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Have you successfully received your physical Lume card? This will complete the order lifecycle.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: colorScheme.outline),
                    ),
                    child: Text(
                      "Not Yet",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Yes, Received",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusCard(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    String displayStatus = _orderStatus;
    IconData statusIcon = Icons.inventory_2_rounded;
    Color statusColor = Colors.orange;
    double progress = 0.2;

    if (_orderStatus == "ORDERED") {
      displayStatus = "Order Placed";
      statusIcon = Icons.inventory_2_rounded;
      statusColor = Colors.orange;
      progress = 0.25;
    } else if (_orderStatus == "PRINTING") {
      displayStatus = "Card Printed";
      statusIcon = Icons.print_rounded;
      statusColor = Colors.blue;
      progress = 0.5;
    } else if (_orderStatus == "DISPATCHED") {
      displayStatus = "Dispatched";
      statusIcon = Icons.local_shipping_rounded;
      statusColor = Colors.purple;
      progress = 0.75;
    } else if (_orderStatus == "DELIVERED") {
      displayStatus = "Delivered";
      statusIcon = Icons.home_rounded;
      statusColor = colorScheme.primary;
      progress = 1.0;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ordered Card Status",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayStatus,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              CardStatusAnimation(status: _orderStatus),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor, statusColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusLabel("Order Placed", progress >= 0.25, colorScheme),
              _buildStatusLabel("Printed", progress >= 0.5, colorScheme),
              _buildStatusLabel("Dispatched", progress >= 0.75, colorScheme),
              _buildStatusLabel("Delivered", progress >= 1.0, colorScheme),
            ],
          ),
          if (_orderStatus == "DELIVERED") ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  bool? confirm = await _showDeliveryConfirmationSheet();

                  if (confirm != true) return;

                  // Haptic feedback
                  HapticFeedback.heavyImpact();

                  if (!mounted) return;
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    final res =
                        await ApiService.confirmCardReceipt(_authToken!);
                    if (mounted) Navigator.pop(context); // Close loading

                    if (res["success"] == true) {
                      setState(() {
                        _orderStatus = "RECEIVED";
                      });
                      _showCardStatusDialog("Congratulations! Enjoy your card.");
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text(res["error"] ?? "Failed to confirm"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Error: ${e.toString()}"),
                          backgroundColor: Colors.red,
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Confirm Received",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusLabel(String label, bool isActive, ColorScheme colorScheme) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: isActive ? colorScheme.onSurface : colorScheme.onSurfaceVariant.withOpacity(0.5),
      ),
    );
  }

  Widget _buildTransactionItem(dynamic tx, ColorScheme colorScheme, {bool isInsideTile = false}) {
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
        prefix = "- ";
        break;
      case "received":
        icon = Icons.arrow_downward_rounded;
        iconColor = Colors.green;
        iconBgColor = Colors.green.withOpacity(0.1);
        amountColor = Colors.green;
        prefix = "+ ";
        break;
      default: // topup
        icon = Icons.account_balance_wallet_rounded;
        iconColor = const Color(0xFF0284C7);
        iconBgColor = const Color(0xFFE0F2FE);
        amountColor = const Color(0xFF0284C7);
        prefix = "+ ";
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

    return InkWell(
      onTap: () => _showTransactionDetails(tx, colorScheme),
      borderRadius: BorderRadius.circular(isInsideTile ? 0 : 20),
      child: Container(
        margin: isInsideTile ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: isInsideTile
            ? null
            : BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: colorScheme.outlineVariant.withOpacity(isDark ? 0.5 : 0.2),
                ),
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
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> tx, ColorScheme colorScheme) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: (tx["status"].toString().toLowerCase() == "success" ? Colors.green : Colors.orange).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (tx["status"].toString().toLowerCase() == "success" ? Colors.green : Colors.orange).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tx["status"].toString().toLowerCase() == "success" ? Icons.check_circle_rounded : Icons.info_rounded,
                            size: 16,
                            color: tx["status"].toString().toLowerCase() == "success" ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tx["status"].toString().toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: tx["status"].toString().toLowerCase() == "success" ? Colors.green : Colors.orange,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Amount
                    Text(
                      "${tx["type"] == "paid" ? "- " : "+ "}₹${tx["amount"].toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tx["title"],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Details List
                    _buildDetailRow("Transaction ID", tx["id"].toString(), colorScheme),
                    _buildDetailRow("Date & Time", tx["date"], colorScheme),
                    _buildDetailRow("Type", tx["type"].toString().toUpperCase(), colorScheme),
                     _buildDetailRow(
                      tx["type"] == "paid" ? "Merchant" : 
                      tx["type"] == "received" ? "Receiver" : 
                      tx["category"] == "Transit" ? "Service" : "Source",
                      tx["title"], 
                      colorScheme
                    ),
                    _buildDetailRow("Category", tx["category"] ?? "General", colorScheme),
                    if (tx["reference"] != null)
                      _buildDetailRow("Reference", tx["reference"], colorScheme),
                    const SizedBox(height: 40),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final amount = tx["amount"].toStringAsFixed(2);
                              final type = tx["type"].toString().toUpperCase();
                              final date = tx["date"];
                              final title = tx["title"];
                              final status = tx["status"].toString().toUpperCase();
                              final txId = tx["id"];

                              final String shareLabel = 
                                tx["type"] == "paid" ? "Merchant" : 
                                tx["type"] == "received" ? "Receiver" : 
                                tx["category"] == "Transit" ? "Service" : "Source";

                              final String shareText = 
                                "LUME Transaction Receipt\n\n"
                                "$shareLabel: $title\n"
                                "Amount: ₹$amount\n"
                                "Type: $type\n"
                                "Status: $status\n"
                                "Date: $date\n"
                                "Transaction ID: $txId\n\n"
                                "Generated by Lume App";

                              Share.share(shareText);
                            },
                            icon: const Icon(Icons.share_rounded, size: 18),
                            label: const Text("Share Receipt"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: colorScheme.outlineVariant),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); // Close sheet
                              Navigator.pushNamed(context, "/help-support");
                            },
                            icon: const Icon(Icons.help_outline_rounded, size: 18),
                            label: const Text("Need Help?"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
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

class _TabKeepAliveWrapperState extends State<_TabKeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
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
      0,
      3.14159,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.9),
      0,
      3.14159,
      false,
      paint,
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
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );

    // Horizontal lines dividing into rows
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, 2 * size.height / 3),
      Offset(0, 2 * size.height / 3),
      paint,
    ); // Optimization error in my head, wait

    // Correcting lines for vertical chip
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, 2 * size.height / 3),
      Offset(size.width, 2 * size.height / 3),
      paint,
    );

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
      size.width * 0.15,
      size.height * 0.2,
      size.width * 0.25,
      size.height * 0.9,
      size.width * 0.4,
      size.height * 0.4,
    );
    path.cubicTo(
      size.width * 0.5,
      size.height * 0.1,
      size.width * 0.6,
      size.height * 0.8,
      size.width * 0.75,
      size.height * 0.5,
    );
    path.cubicTo(
      size.width * 0.85,
      size.height * 0.3,
      size.width * 0.92,
      size.height * 0.6,
      size.width,
      size.height * 0.5,
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
      canvas.drawLine(Offset(x, i), Offset((x + 100) % size.width, i), paint);
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

    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.15),
      60,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.45),
      40,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.8),
      80,
      dotPaint,
    );
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
    final paint = Paint()
      ..color = color.withOpacity(isDark ? 0.12 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // 1. Draw stylized "Home" shapes
    for (int i = 0; i < 6; i++) {
      final double xPos = size.width * (0.15 + (i % 2) * 0.6);
      final double yPos = size.height * (0.1 + i * 0.15);

      canvas.save();
      canvas.translate(xPos, yPos);
      canvas.rotate(0.15 * (i + 1));

      // Draw simplified house outline
      final path = Path();
      path.moveTo(-30, 10);
      path.lineTo(-30, 40);
      path.lineTo(30, 40);
      path.lineTo(30, 10);
      path.lineTo(0, -20);
      path.close();
      canvas.drawPath(path, paint);

      // Draw a window detail
      canvas.drawRect(const Rect.fromLTWH(-12, 10, 10, 10), paint);
      canvas.drawRect(const Rect.fromLTWH(2, 10, 10, 10), paint);

      canvas.restore();
    }

    // 2. Soft decorative circles
    final dotPaint = Paint()
      ..color = color.withOpacity(isDark ? 0.06 : 0.04)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.2), 80, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.7), 100, dotPaint);
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
    final paint = Paint()
      ..color = color.withOpacity(isDark ? 0.12 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // 1. Draw stylized "Gift" shapes
    for (int i = 0; i < 6; i++) {
      final double xPos = size.width * (0.2 + (i % 2) * 0.5);
      final double yPos = size.height * (0.1 + i * 0.15);

      canvas.save();
      canvas.translate(xPos, yPos);
      canvas.rotate(0.2 * (i + 1));

      // Draw box outline
      final rect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-30, -20, 60, 50),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, paint);

      // Draw Ribbon crossing
      canvas.drawLine(const Offset(-30, 5), const Offset(30, 5), paint);
      canvas.drawLine(const Offset(0, -20), const Offset(0, 30), paint);

      canvas.restore();
    }

    // 2. Soft decorative circles
    final dotPaint = Paint()
      ..color = color.withOpacity(isDark ? 0.06 : 0.04)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.2), 90, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.8), 120, dotPaint);
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
    final paint = Paint()
      ..color = color.withOpacity(isDark ? 0.12 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // 1. Draw stylized "Ticket" shapes
    for (int i = 0; i < 6; i++) {
      final double xPos = size.width * (0.15 + (i % 2) * 0.6);
      final double yPos = size.height * (0.1 + i * 0.15);

      canvas.save();
      canvas.translate(xPos, yPos);
      canvas.rotate(-0.1 * (i + 1));

      // Draw ticket outline
      final rect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-40, -20, 80, 40),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, paint);

      // Draw "magnetic stripe" or dashed line
      final stripePaint = Paint()
        ..color = color.withOpacity(isDark ? 0.1 : 0.05)
        ..style = PaintingStyle.fill;
      canvas.drawRect(const Rect.fromLTWH(-40, -10, 80, 10), stripePaint);

      canvas.restore();
    }

    // 2. Soft decorative circles
    final dotPaint = Paint()
      ..color = color.withOpacity(isDark ? 0.06 : 0.04)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.1), 100, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.9), 80, dotPaint);
  }

  @override
  bool shouldRepaint(covariant TransitBackgroundPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isDark != isDark;
}


class CardPatternPainter extends CustomPainter {
  final Color color;
  CardPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    
    // Draw decorative geometric lines
    for (var i = 0; i < 5; i++) {
      path.moveTo(size.width * (0.2 * i), 0);
      path.lineTo(size.width, size.height * (1 - 0.2 * i));
    }
    
    for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset(size.width * 0.8, size.height * 0.2),
          20.0 * (i + 1),
          paint..color = color.withOpacity(0.1 * (3 - i)),
        );
    }

    canvas.drawPath(path, paint..color = color.withOpacity(0.2));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class CardStatusAnimation extends StatefulWidget {
  final String status;
  const CardStatusAnimation({super.key, required this.status});

  @override
  State<CardStatusAnimation> createState() => _CardStatusAnimationState();
}

class _CardStatusAnimationState extends State<CardStatusAnimation>
    with TickerProviderStateMixin {
  late AnimationController _boxController;
  late AnimationController _truckController;

  @override
  void initState() {
    super.initState();
    _boxController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _truckController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _boxController.dispose();
    _truckController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == "ORDERED" || widget.status == "PRINTING") {
      // Packing Animation
      return AnimatedBuilder(
        animation: _boxController,
        builder: (context, child) {
          final double cardY = (_boxController.value * 25) - 15;
          final double boxScale = 1.0 +
              (Curves.easeInOut.transform(_boxController.value) * 0.08);
          final bool isPrinting = widget.status == "PRINTING";
          final Color themeColor = isPrinting ? Colors.blue : Colors.orange;

          return SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glowing Background
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withOpacity(0.15),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                // Box
                Transform.scale(
                  scale: boxScale,
                  child: Icon(
                    isPrinting ? Icons.print_rounded : Icons.inventory_2_rounded,
                    color: themeColor.withOpacity(0.4),
                    size: 44,
                  ),
                ),
                // Card moving in
                if (!isPrinting)
                  Transform.translate(
                    offset: Offset(0, cardY),
                    child: Opacity(
                      opacity: (1.2 - _boxController.value * 1.5).clamp(0.0, 1.0),
                      child: Container(
                        width: 24,
                        height: 15,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: Colors.white24, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    } else if (widget.status == "DISPATCHED") {
      // Delivery Animation
      return AnimatedBuilder(
        animation: _truckController,
        builder: (context, child) {
          final double truckBounce = Curves.easeInOut
                  .transform((_truckController.value * 2) % 1.0) *
              2;
          return SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Speed lines
                ...List.generate(
                    3,
                    (i) => Positioned(
                          right: 15 +
                              (1.0 - _truckController.value) * 40 +
                              (i * 12),
                          top: 25.0 + (i * 10),
                          child: Opacity(
                            opacity: (1.0 - _truckController.value).clamp(0.0, 1.0),
                            child: Container(
                              width: 14 - (i * 2.0),
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        )),
                // Truck
                Transform.translate(
                  offset: Offset(0, -truckBounce),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: Colors.purple,
                    size: 42,
                  ),
                ),
                // Ground smoke/dust
                Positioned(
                  bottom: 18,
                  left: 15,
                  child: Opacity(
                    opacity: (_truckController.value).clamp(0.0, 0.4),
                    child: Icon(Icons.cloud_rounded,
                        color: Colors.grey.withOpacity(0.2), size: 16),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else if (widget.status == "DELIVERED" || widget.status == "RECEIVED") {
      return SizedBox(
        width: 70,
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 38,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox(width: 70, height: 70);
  }
}

