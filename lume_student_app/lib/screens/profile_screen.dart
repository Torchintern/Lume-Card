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
  String _institute = "";
  String _department = "";
  String _dob = "";
  String _bloodGroup = "";
  String _batch = "";
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
        _department = student["department"] ?? "";
        _institute = student["institute_name"] ?? "";
        _dob = student["dob"] ?? "";
        _bloodGroup = student["blood_group"] ?? "";
        _profileImageUrl = student["profile_image"];

        final batchStart = student["batch_start_year"]?.toString() ?? "";
        final batchEnd = student["batch_end_year"]?.toString() ?? "";
        if (batchStart.isNotEmpty && batchEnd.isNotEmpty) {
          _batch = "$batchStart - $batchEnd";
        } else if (batchStart.isNotEmpty) {
          _batch = batchStart;
        }
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
        _department = prefs.getString("user_dept") ?? "";
        _institute = prefs.getString("user_institute") ?? "";
        _dob = prefs.getString("user_dob") ?? "";
        _bloodGroup = prefs.getString("user_blood_group") ?? "";
        _batch = prefs.getString("user_batch") ?? "";
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Using premium dashboard colors
    final Color cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final Color textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subTextColor = isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF475569);
    
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: colorScheme.primary.withOpacity(0.2),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Student-themed background painter
            Positioned.fill(
              child: CustomPaint(
                painter: StudentIdBackgroundPainter(
                  color: colorScheme.primary,
                  isDark: isDark,
                ),
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
                      Text(
                        "LUME IDENTITY",
                        style: TextStyle(
                          color: colorScheme.primary.withOpacity(0.8), 
                          fontSize: 12, 
                          fontWeight: FontWeight.w900, 
                          letterSpacing: 1.5
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                        ),
                        child: Text(
                          "STUDENT",
                          style: TextStyle(
                            color: colorScheme.primary, 
                            fontSize: 10, 
                            fontWeight: FontWeight.w900, 
                            letterSpacing: 1
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.05),
                          shape: BoxShape.circle,
                          border: Border.all(color: colorScheme.primary.withOpacity(0.3), width: 2),
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
                                style: TextStyle(
                                  color: colorScheme.primary, 
                                  fontSize: 28, 
                                  fontWeight: FontWeight.w900
                                ),
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
                              style: TextStyle(
                                color: textColor, 
                                fontSize: 20, 
                                fontWeight: FontWeight.w900, 
                                height: 1.1,
                                letterSpacing: -0.5
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _userRegNo,
                                style: TextStyle(
                                  color: colorScheme.primary, 
                                  fontSize: 13, 
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _institute,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: subTextColor, 
                                fontSize: 11, 
                                fontWeight: FontWeight.w600
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Glassmorphism QR Container
                      InkWell(
                        onTap: _showQRDialog,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 65,
                          height: 65,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.primary.withOpacity(0.2),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: "Name: $_userName\nReg No: $_userRegNo\nInstitute: $_institute\nDept: $_department\nEmail: $_userEmail",
                            version: QrVersions.auto,
                            size: 65.0,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: colorScheme.primary,
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: colorScheme.primary.withOpacity(0.8),
                            ),
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
            _buildInfoRow("Phone Number", _userPhone.isEmpty ? "-" : _userPhone, Icons.phone_iphone_rounded, colorScheme),
            _buildDivider(),
            _buildInfoRow("Email Address", _userEmail.isEmpty ? "-" : _userEmail, Icons.email_rounded, colorScheme),
            _buildDivider(),
            _buildInfoRow("Department", _department.isEmpty ? "-" : _department, Icons.school_rounded, colorScheme),
            _buildDivider(),
            _buildInfoRow("Batch", _batch.isEmpty ? "-" : _batch, Icons.calendar_today_rounded, colorScheme),
            _buildDivider(),
            _buildInfoRow("Institute", _institute.isEmpty ? "-" : _institute, Icons.account_balance_rounded, colorScheme),
            _buildDivider(),
            _buildInfoRow("Date of Birth", _dob.isEmpty ? "-" : _dob, Icons.cake_rounded, colorScheme),
            _buildDivider(),
            _buildInfoRow("Blood Group", _bloodGroup.isEmpty ? "-" : _bloodGroup, Icons.bloodtype_rounded, colorScheme),
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

class StudentIdBackgroundPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  StudentIdBackgroundPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Geometric Pattern (Matching Dashboard CardPatternPainter)
    final patternPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withOpacity(isDark ? 0.08 : 0.05);

    final path = Path();
    for (var i = 0; i < 6; i++) {
      path.moveTo(size.width * (0.15 * i), 0);
      path.lineTo(size.width, size.height * (1 - 0.15 * i));
    }
    canvas.drawPath(path, patternPaint);

    // 2. Draw subtle student-related icons
    final iconPaint = Paint()
      ..color = color.withOpacity(isDark ? 0.1 : 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 4; i++) {
      final double xPos = size.width * (0.15 + (i % 2) * 0.65);
      final double yPos = size.height * (0.2 + i * 0.2);

      canvas.save();
      canvas.translate(xPos, yPos);
      canvas.rotate(0.15 * (i + 1));

      if (i % 2 == 0) {
        // Graduation Cap
        final capPath = Path();
        capPath.moveTo(-12, 0);
        capPath.lineTo(0, -6);
        capPath.lineTo(12, 0);
        capPath.lineTo(0, 6);
        capPath.close();
        canvas.drawPath(capPath, iconPaint);
        canvas.drawLine(const Offset(0, 6), const Offset(0, 12), iconPaint);
      } else {
        // Book
        canvas.drawRect(const Rect.fromLTWH(-10, -8, 20, 16), iconPaint);
        canvas.drawLine(const Offset(0, -8), const Offset(0, 8), iconPaint);
      }

      canvas.restore();
    }

    // 3. Premium abstract accents
    final accentPaint = Paint()
      ..color = color.withOpacity(isDark ? 0.06 : 0.03)
      ..style = PaintingStyle.fill;

    // Top Right Accent
    final accentPath = Path();
    accentPath.moveTo(size.width * 0.6, 0);
    accentPath.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.3,
      size.width,
      size.height * 0.1,
    );
    accentPath.lineTo(size.width, 0);
    accentPath.close();
    canvas.drawPath(accentPath, accentPaint);

    // Bottom Circle
    canvas.drawCircle(
      Offset(size.width * 0.05, size.height * 0.9),
      80,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant StudentIdBackgroundPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isDark != isDark;
  }
}
