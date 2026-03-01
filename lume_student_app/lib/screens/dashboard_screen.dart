import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../utils/campus_app_picker.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  String _userName = "John Doe"; 
  String _userPhone = "";
  String _userEmail = "";
  String _userRegNo = "";
  String _userDept = "Not Specified";
  String _userInstitute = "Lume Institute";
  String _userDob = "Not Provided";
  String _userBloodGroup = "Not Provided";
  String? _profileImageUrl;
  bool _isUploading = false;
  String _lumeStatus = "Inactive";

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
    _animationController.forward();
    _loadUserProfile(); 
    CampusAppPicker.preload();   
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
            
            String? dept = student["department"];
            _userDept = (dept == null || dept.isEmpty) ? "No Dept in DB" : dept;
            
            String? inst = student["institute_name"];
            _userInstitute = (inst == null || inst.isEmpty) ? "No Inst in DB" : inst;

            _userDob = student["dob"] ?? "Not Provided";
            _userBloodGroup = student["blood_group"] ?? "Not Provided";
            _lumeStatus = (student["lume_status"] ?? "inactive").toString().toLowerCase();

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
    super.dispose();
  }

  void _showImageOptions() {
  showModalBottomSheet(
    context: context,
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
                    }
                  });
                  await _loadUserProfile();
                }),
                  _buildDrawerItem(Icons.credit_card_outlined, "Card Centre", iconColor, () {}),
                  _buildDrawerItem(Icons.card_giftcard_outlined, "Rewards", iconColor, () {}),
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
          
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium App Bar
              SliverAppBar(
                expandedHeight: size.height * 0.25,
                floating: false,
                pinned: true,
                stretch: true,
                elevation: 0,
                backgroundColor: colorScheme.primary,
                leading: IconButton(
                  padding: const EdgeInsets.only(left: 12),
                  icon: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                    ),
                    child: CircleAvatar(
                      key: ValueKey(_profileImageUrl),
                      radius: 24,
                      backgroundColor: colorScheme.primary,
                      backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                      ? NetworkImage("${ApiService.baseUrl}/uploads/profile_pics/$_profileImageUrl")
                      : null,
                      child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                          ? Text(
                              _getInitials(_userName),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                actions: const [
                   SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Header Gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colorScheme.primary, colorScheme.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Floating decorative circles
                      Positioned(
                        bottom: -30,
                        right: 20,
                        child: Icon(Icons.school_rounded, size: 120, color: Colors.white.withOpacity(0.1)),
                      ),
                      Positioned(
                        bottom: 40,
                        left: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "Hey, ${_userName.split(" ")[0]}! 👋",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "Student Profile",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(20),
                  child: Container(
                    height: 30,
                    width: double.infinity,
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
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: colorScheme.primary,
        elevation: 4,
        icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
        label: const Text("Scan ID", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
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
