import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _userName = "Loading...";
  String _userRegNo = "";
  String _userPhone = "";
  String _userEmail = "";
  String _institute = "Lume Institute";
  String _department = "Not Specified";
  String _dob = "Not Provided";
  String _bloodGroup = "Not Provided";
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args.containsKey("student")) {
      final student = args["student"];
      setState(() {
        _userName = student["full_name"] ?? _userName;
        _userRegNo = student["reg_no"] ?? _userRegNo;
        _userPhone = student["mobile"] ?? _userPhone;
        _userEmail = student["email"] ?? _userEmail;
        
        String? dept = student["department"];
        _department = (dept == null || dept.isEmpty || dept == "Not Specified") ? "No Dept in DB" : dept;
        
        String? inst = student["institute_name"];
        _institute = (inst == null || inst.isEmpty || inst == "Lume Institute") ? "No Inst in DB" : inst;
        
        _dob = student["dob"] ?? _dob;
        _bloodGroup = student["blood_group"] ?? _bloodGroup;
        _profileImageUrl = student["profile_image"];
      });
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString("full_name") ?? _userName;
        _userRegNo = prefs.getString("user_reg_no") ?? _userRegNo;
        _userPhone = prefs.getString("user_phone") ?? _userPhone;
        _userEmail = prefs.getString("user_email") ?? _userEmail;
        
        String savedDept = prefs.getString("user_dept") ?? "";
        _department = savedDept.isEmpty || savedDept == "Not Specified" ? "No Dept in DB" : savedDept;
        
        String savedInst = prefs.getString("user_institute") ?? "";
        _institute = savedInst.isEmpty || savedInst == "Lume Institute" ? "No Inst in DB" : savedInst;
        
        _dob = prefs.getString("user_dob") ?? "Not Provided";
        _bloodGroup = prefs.getString("user_blood_group") ?? "Not Provided";
        _profileImageUrl = prefs.getString("user_profile_image");
      });
    }
  }

  void _showQRDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Student QR Identity",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: QrImageView(
                  data: "Name: $_userName\nReg No: $_userRegNo\nInstitute: $_institute\nDept: $_department\nEmail: $_userEmail",
                  version: QrVersions.auto,
                  size: 200.0,
                  gapless: false,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _userName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "Reg No: $_userRegNo",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                _institute,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Close"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildVirtualID(colorScheme),
              const SizedBox(height: 24),
              _buildSectionTitle("Personal Information"),
              const SizedBox(height: 16),
              _buildDetailsCard(colorScheme),
              const SizedBox(height: 32),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVirtualID(ColorScheme colorScheme) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative shapes
            Positioned(
              right: -20,
              top: -20,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            ),
            Positioned(
              left: -10,
              bottom: -10,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withOpacity(0.05),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.credit_card_rounded, color: Colors.white, size: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "STUDENT ID",
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                          image: _profileImageUrl != null 
                            ? DecorationImage(
                                image: NetworkImage("${ApiService.baseUrl}/uploads/profile_pics/$_profileImageUrl"),
                                fit: BoxFit.cover,
                              )
                            : null,
                        ),
                        child: _profileImageUrl == null 
                          ? Center(
                              child: Text(
                                _getInitials(_userName),
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            )
                          : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _userName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 18, 
                                fontWeight: FontWeight.w800, 
                                height: 1.1,
                                letterSpacing: -0.2
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Reg No: $_userRegNo",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9), 
                                fontSize: 12, 
                                fontWeight: FontWeight.w500
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _institute,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7), 
                                fontSize: 10, 
                                fontWeight: FontWeight.w400
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Real QR Code on Card
                      InkWell(
                        onTap: _showQRDialog,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 55,
                          height: 55,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: QrImageView(
                            data: "Name: $_userName\nReg No: $_userRegNo\nInstitute: $_institute\nDept: $_department\nEmail: $_userEmail",
                            version: QrVersions.auto,
                            size: 55.0,
                          ),
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
    );
  }

  Widget _buildDetailsCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildInfoRow("Username", _userName, Icons.person_outline_rounded, colorScheme),
            _buildDivider(),
            _buildInfoRow("Phone Number", _userPhone, Icons.phone_iphone_rounded, colorScheme),
            _buildDivider(),
            _buildInfoRow("Email Address", _userEmail.isEmpty ? "Not Provided" : _userEmail, Icons.email_rounded, colorScheme),
            _buildDivider(),
            _buildInfoRow("Department", _department, Icons.school_rounded, colorScheme),
            _buildDivider(),
            _buildInfoRow("Institute", _institute, Icons.account_balance_rounded, colorScheme),
            _buildDivider(),
            _buildInfoRow("Date of Birth", _dob, Icons.cake_rounded, colorScheme),
            _buildDivider(),
            _buildInfoRow("Blood Group", _bloodGroup, Icons.bloodtype_rounded, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 48),
      child: Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
