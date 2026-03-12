import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ScholarScreen extends StatefulWidget {
  const ScholarScreen({super.key});

  @override
  State<ScholarScreen> createState() => _ScholarScreenState();
}

class _ScholarScreenState extends State<ScholarScreen> {
  // ================= TYPING TEXT =================
  final String fullText =
  "Dream big.\nStudy smarter.\nReach your ideal college with LUME.";
  String visibleText = "";
  int charIndex = 0;
  Timer? _typingTimer;
  Timer? _restartTimer;
  final bool _isUserInteracting = false;
  String userName = "";
  bool hasApplication = false;
  String? applicationStatus;

  // ================= HEADER CAROUSEL =================
  late PageController _headerPageController;
  Timer? _headerAutoScrollTimer;
  int _currentHeaderPage = 0;




  // ================= AUTO PAGE SWAP =================
  final PageController _pageController =
    PageController(viewportFraction: 1.0, initialPage: 1000);

  Timer? _pageTimer;
  int _currentPage = 1000;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _startTyping();
    _startPageTimer();
    _loadApplicationStatus();
    _headerPageController = PageController(initialPage: 400);
    _startHeaderAutoScroll();
  }

  void _startHeaderAutoScroll() {
    _headerAutoScrollTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (_headerPageController.hasClients) {
        _headerPageController.nextPage(
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }
  
  Future<void> _loadApplicationStatus() async {
  final prefs = await SharedPreferences.getInstance();
  final regId = prefs.getInt("reg_id");

  if (regId == null) return;

  final res = await ApiService.getScholarApplicationStatus(regId);

  setState(() {
    hasApplication = res["hasApplication"] == true;
    applicationStatus = res["status"];
  });
}

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString("full_name") ??
                prefs.getString("user_name") ??
                "User";
    });
  }


  @override
  void dispose() {
    _typingTimer?.cancel();
    _restartTimer?.cancel();
    _pageTimer?.cancel();
    _headerAutoScrollTimer?.cancel();
    _pageController.dispose();
    _headerPageController.dispose();
    super.dispose();
  }

  // ================= AUTO TYPING WITH 3s PAUSE =================
  void _startTyping() {
    _typingTimer?.cancel();
    visibleText = "";
    charIndex = 0;

    _typingTimer =
        Timer.periodic(const Duration(milliseconds: 70), (timer) {
      if (charIndex < fullText.length) {
        setState(() {
          visibleText += fullText[charIndex];
          charIndex++;
        });
      } else {
        timer.cancel(); 
      }
    });
  }

  // ================= AUTO PAGE SWAP =================
  void _startPageTimer() {
  _pageTimer?.cancel();
  _pageTimer = Timer.periodic(const Duration(seconds: 5), (_) {
    if (!_pageController.hasClients || _isUserInteracting) return;

    _currentPage++;

    _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
    );
  });
}


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
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
                    colorScheme.secondary.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Dynamic Premium Header
              SliverAppBar(
                expandedHeight: size.height * 0.35,
                pinned: true,
                stretch: true,
                backgroundColor: colorScheme.primary,
                elevation: 0,
                leadingWidth: 70,
                centerTitle: true,
                leading: Center(
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  expandedTitleScale: 1.0,
                  titlePadding: EdgeInsets.zero,
                  title: LayoutBuilder(
                    builder: (context, constraints) {
                      final double top = constraints.biggest.height;
                      final double expandedHeight = size.height * 0.35;
                      final double collapsedHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
                      final double delta = expandedHeight - collapsedHeight;
                      final double progress = ((top - collapsedHeight) / delta).clamp(0.0, 1.0);

                      final double fontSize = 18 + (14 * progress);
                      
                      return Container(
                        padding: EdgeInsets.only(
                          left: 25 * (1 - progress) + (20 * progress),
                          bottom: 25 * progress,
                        ),
                        alignment: Alignment.lerp(
                          Alignment.center,
                          Alignment.bottomLeft,
                          progress,
                        ),
                        child: Text(
                          "Scholar Hub",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5 * progress,
                          ),
                        ),
                      );
                    },
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Dynamic Animated Background
                      PageView.builder(
                        controller: _headerPageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentHeaderPage = index % 3;
                          });
                        },
                        itemBuilder: (context, index) {
                          final int realIndex = index % 3;
                          return _buildHeaderSlide(realIndex, colorScheme);
                        },
                      ),

                      // Overlay Gradient for text readability
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.35),
                              Colors.transparent,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),

                      // Indicators
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 20,
                        right: 25,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (index) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(left: 4),
                              height: 4,
                              width: _currentHeaderPage == index ? 12 : 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(_currentHeaderPage == index ? 0.9 : 0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(20),
                  child: Container(
                    height: 20,
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
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ================= COLORFUL AUTO TYPING TEXT =================
                      SizedBox(
                        height: 160,
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFF4C6EF5),
                              Color(0xFF00C2FF),
                              Color(0xFFFFC107),
                            ],
                          ).createShader(bounds),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1.4,
                                letterSpacing: 0.4,
                              ),
                              children: [
                                TextSpan(
                                  text: '${visibleText.split('\n').take(2).join('\n')}\n',
                                ),
                                TextSpan(
                                  text: visibleText.split('\n').length > 2
                                      ? visibleText.split('\n')[2]
                                      : '',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ================= AUTO SWAPPING STATS =================
                      SizedBox(
                        height: 170,
                        child: PageView.builder(
                          controller: _pageController,
                          scrollDirection: Axis.horizontal,
                          physics: const PageScrollPhysics(),
                          onPageChanged: (index) {
                            _currentPage = index;
                          },
                          itemBuilder: (_, index) {
                            final items = [
                              const _ScholarStatCard(
                                logoPath: "assets/logos/university.png",
                                value: "5+",
                                label: "Partner Universities",
                              ),
                              const _ScholarStatCard(
                                logoPath: "assets/logos/students.png",
                                value: "1 Lakh+",
                                label: "Students Guided",
                              ),
                              const _ScholarStatCard(
                                logoPath: "assets/logos/loan.png",
                                value: "₹2 Cr+",
                                label: "Loans Processed",
                              ),
                            ];

                            return items[index % items.length];
                          },
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ================= LENDING PARTNER OFFERINGS =================
                      _LendingPartnersSection(
                        userName: userName,
                        hasApplication: hasApplication,
                        applicationStatus: applicationStatus,
                        onApplicationSubmitted: () async {
                          await _loadApplicationStatus();
                          setState(() {});
                        },
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
      );
  }

  Widget _buildHeaderSlide(int index, ColorScheme colorScheme) {
    switch (index) {
      case 0:
        return _buildSlideBase(
          color1: colorScheme.primary,
          color2: colorScheme.secondary,
          icon: Icons.school_rounded,
          title: "Premium Education",
          subtitle: "Unlock your potential with Lume's exclusive scholar programs.",
        );
      case 1:
        return _buildSlideBase(
          color1: const Color(0xFF1E1B4B),
          color2: const Color(0xFF4338CA),
          icon: Icons.account_balance_rounded,
          title: "Global Reach",
          subtitle: "Connect with top-tier universities across the globe.",
        );
      case 2:
        return _buildSlideBase(
          color1: const Color(0xFF0F172A),
          color2: const Color(0xFF334155),
          icon: Icons.payments_rounded,
          title: "Smart Funding",
          subtitle: "Quick and easy education loans with partner banks.",
        );
      default:
        return Container(color: colorScheme.primary);
    }
  }

  Widget _buildSlideBase({
    required Color color1,
    required Color color2,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(icon, size: 180, color: Colors.white.withOpacity(0.08)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(25, 60, 25, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white.withOpacity(0.9), size: 32),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 220,
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= STAT CARD =================
class _ScholarStatCard extends StatelessWidget {
  final String logoPath;
  final String value;
  final String label;

  const _ScholarStatCard({
  required this.logoPath,
  required this.value,
  required this.label,
});

  @override
  Widget build(BuildContext context) {
    return Container(
    margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, 
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5), 
        ),
      ),

        child: Row(
          children: [
            const SizedBox(width: 20),

            // -------- LEFT TEXT --------
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFC107),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            // -------- RIGHT ICON --------
            Container(
              height: 72,
              width: 72,
              margin: const EdgeInsets.only(right: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Image.asset(
                logoPath,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LendingPartnersSection extends StatelessWidget {
  final String userName;
  final bool hasApplication;
  final String? applicationStatus;
  final VoidCallback onApplicationSubmitted; 
  const _LendingPartnersSection({
    required this.userName,
    required this.hasApplication,
    required this.applicationStatus,
    required this.onApplicationSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              "assets/images/lend.png",
              height: 22,
              width: 22,
            ),
            const SizedBox(width: 8),
            const Text(
              "Our Lending Partner Offerings",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),


    const SizedBox(height: 12),
        _LendingTable(),
        const SizedBox(height: 24),
      _UserApplicationCard(
      userName: userName,
      hasApplication: hasApplication,
      applicationStatus: applicationStatus,
      onApplicationSubmitted: onApplicationSubmitted,
    ),

      ],
    );
  }
}

class _LendingTable extends StatefulWidget {
  @override
  State<_LendingTable> createState() => _LendingTableState();
}
class _LendingTableState extends State<_LendingTable> {
  int? _selectedIndex;

    @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: 700,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            _TableHeader(),

            _buildRow(
              index: 0,
              logo: "assets/banks/pnb.png",
              name: "PNB",
              amount: "Up to ₹2 Crore",
              rate: "8.5% – 10%",
              time: "5–7 Days",
              fee: "₹5,000",
            ),

            _buildRow(
              index: 1,
              logo: "assets/banks/credila.png",
              name: "Credila",
              amount: "Up to ₹2 Crore",
              rate: "9% – 11%",
              time: "3–5 Days",
              fee: "₹4,500",
            ),

            _buildRow(
              index: 2,
              logo: "assets/banks/idfc.png",
              name: "IDFC First Bank",
              amount: "Up to ₹2 Crore",
              rate: "8% – 9.5%",
              time: "2–4 Days",
              fee: "₹6,000",
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildRow({
    required int index,
    required String logo,
    required String name,
    required String amount,
    required String rate,
    required String time,
    required String fee,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index; 
        });
      },
      child: _LendingRow(
        logo: logo,
        name: name,
        amount: amount,
        rate: rate,
        time: time,
        fee: fee,
        highlighted: _selectedIndex == index,
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text("Bank Name", style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onPrimaryContainer))),
          Expanded(child: Text("Loan Amount", style: TextStyle(color: colorScheme.onPrimaryContainer))),
          Expanded(child: Text("Interest", style: TextStyle(color: colorScheme.onPrimaryContainer))),
          Expanded(child: Text("Processing Time", style: TextStyle(color: colorScheme.onPrimaryContainer))),
          Expanded(child: Text("Processing Fee", style: TextStyle(color: colorScheme.onPrimaryContainer))),
        ],
      ),
    );
  }
}
class _LendingRow extends StatelessWidget {
  final String logo;
  final String name;
  final String amount;
  final String rate;
  final String time;
  final String fee;
  final bool highlighted;

  const _LendingRow({
    required this.logo,
    required this.name,
    required this.amount,
    required this.rate,
    required this.time,
    required this.fee,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: highlighted 
          ? colorScheme.secondaryContainer
          : colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                SizedBox(
                width: 32,
                height: 32,
                child: Image.asset(
                  logo,
                  fit: BoxFit.contain,
                ),
              ),
                const SizedBox(width: 8),
               Flexible(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary, 
                ),
              ),
            ),

              ],
            ),
          ),
          Expanded(child: Text(amount, style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
          Expanded(child: Text(rate, style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
          Expanded(child: Text(time, style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
          Expanded(child: Text(fee, style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
        ],
      ),
    );
  }
}

class _UserApplicationCard extends StatelessWidget {
  final String userName;
  final bool hasApplication;
  final String? applicationStatus;
  final VoidCallback onApplicationSubmitted;

  const _UserApplicationCard({
    required this.userName,
    required this.hasApplication,
    required this.applicationStatus,
    required this.onApplicationSubmitted,
  });


bool get canCreateNewApplication {
  if (!hasApplication) return true;
  if (applicationStatus == "completed") return true;
  return false; 
}


  Widget _buildStatusText(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (!hasApplication) {
      return Text(
        "No application found. Please apply.",
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      );
    }

    if (applicationStatus == "pending") {
      return Text(
        "Application under review",
        style: TextStyle(
          color: isDark ? Colors.orangeAccent : Colors.orange,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (applicationStatus == "completed") {
      return Text(
        "Application Reviewed. You can apply again.",
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      );
    }

  return const SizedBox.shrink();
}


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hi $userName,",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: canCreateNewApplication
                ? () async {
                    final result = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      enableDrag: false,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const _CreateApplicationSheet(),
                    );

                    if (!context.mounted) return;

                    if (result == true) {
                      onApplicationSubmitted();
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,           
            disabledForegroundColor: Colors.white70,  
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                hasApplication && applicationStatus == "completed"
                    ? "Apply Again"
                    : "Create New Application",
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),

          const SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: _buildStatusText(context),
          ),
        ],
      ),
    );
  }
}

class _CreateApplicationSheet extends StatefulWidget {
  const _CreateApplicationSheet();

  @override
  State<_CreateApplicationSheet> createState() =>
      _CreateApplicationSheetState();
}
class _CreateApplicationSheetState extends State<_CreateApplicationSheet> {
  final _formKey = GlobalKey<FormState>();

  String? country;
  String? admissionStatus;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _loanController = TextEditingController();
  final _cityController = TextEditingController();
  final _intakeController = TextEditingController();


  final List<String> countries = [
    "USA",
    "UK",
    "Canada",
    "Australia",
    "Germany",
    "Ireland",
    "France",
    "India",
    "UAE",
    "New Zealand",
    "Others",
  ];

  final List<String> admissionStatuses = [
    "Not Applied",
    "Applied",
    "Confirmed",
  ];
bool get _isFormValid {
  return _formKey.currentState?.validate() == true &&
      country != null &&
      admissionStatus != null;
}
@override
void initState() {
  super.initState();
  country = null;
  admissionStatus = null;
}
@override
void dispose() {
  _nameController.dispose();
  _emailController.dispose();
  _phoneController.dispose();
  _loanController.dispose();
  _cityController.dispose();
  _intakeController.dispose();
  super.dispose();
}


Future<bool?> _showSuccessDialog(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 12),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.secondary,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                "Application Submitted",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "Our team will contact you shortly to guide you further.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 20),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "Great, Continue",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
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
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ===== Drag Handle =====
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          const SizedBox(height: 12),

          // ===== Header =====
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ===== Highlight Text =====
          Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: isDark ? colorScheme.surfaceContainerHighest : colorScheme.primaryContainer.withValues(alpha: 0.3),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        "assets/images/reach.png", 
        height: 16,          
        fit: BoxFit.contain,
      ),
      const SizedBox(width: 6),
      const Text(
        "We reach out within minutes",
        style: TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  ),
),


          const SizedBox(height: 16),

          const Text(
            "Start Early, Avoid Last Minute Stress",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            "Help us with a few details below and we'll find the best education loan for you",
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),

          const SizedBox(height: 20),

          // ===== FORM =====
          Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _InputField(
                    label: "FULL NAME*",
                    hint: "Full Name",
                    controller: _nameController,
                  ),

              _InputField(
                label: "EMAIL*",
                hint: "Email",
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Required";
                      final emailRegex =
                          RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(value)) {
                        return "Enter a valid email";
                      }
                      return null;
                    },
                  ),

                  _InputField(
                    label: "PHONE NUMBER*",
                    hint: "Mobile Number",
                    controller: _phoneController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Required";
                      if (value.length != 10) return "Enter 10-digit number";
                      return null;
                    },
                  ),

                 _InputField(
                    label: "LOAN AMOUNT*",
                    hint: "Enter Amount",
                    controller: _loanController,
                    keyboardType: TextInputType.number,
                  ),

                  _InputField(
                    label: "PERMANENT CITY*",
                    hint: "Permanent City",
                    controller: _cityController,
                  ),

                _DropdownField(
                  label: "COUNTRY OF STUDY*",
                  hint: "Select Country",
                  value: country,
                  items: countries,
                  onChanged: (value) {
                    setState(() => country = value);
                  },
                ),

                _DropdownField(
                  label: "ADMISSION STATUS*",
                  hint: "Select Status",
                  value: admissionStatus,
                  items: admissionStatuses,
                  onChanged: (value) {
                    setState(() => admissionStatus = value);
                  },
                ),


                 _InputField(
                    label: "TARGET INTAKE*",
                    hint: "MM/YYYY",
                    controller: _intakeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [MonthYearInputFormatter()],
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Required";

                      final regex = RegExp(r'^(0[1-9]|1[0-2])\/\d{4}$');
                      if (!regex.hasMatch(value)) {
                        return "Format should be MM/YYYY";
                      }
                      return null;
                    },
                  ),

                ],
              ),
            ),
          ),
          ),
          const SizedBox(height: 12),

          // ===== CONTINUE BUTTON =====
         SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
            backgroundColor: _isFormValid
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            foregroundColor: _isFormValid ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16), 
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
            onPressed: _isFormValid
              ? () async {
                  final prefs = await SharedPreferences.getInstance();
                  final regId = prefs.getInt("reg_id");

                  final payload = {
                    "registered_student_id": regId,
                    "full_name": _nameController.text.trim(),
                    "email": _emailController.text.trim(),
                    "phone": _phoneController.text.trim(),
                    "loan_amount": _loanController.text.trim(),
                    "city": _cityController.text.trim(),
                    "country": country,
                    "admission_status": admissionStatus,
                    "target_intake": _intakeController.text.trim(),
                  };


                  final success =
                      await ApiService.submitScholarApplication(payload);

                  if (!context.mounted) return;

                  if (success) {
                    final bool? confirmed = await _showSuccessDialog(context);

                    if (!context.mounted) return;

                    if (confirmed == true) {
                      if (!context.mounted) return;
                      Navigator.pop(context, true); 
                    }
                  } else {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Something went wrong"),
                        backgroundColor: colorScheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              : null,

            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "Continue",
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),

          const SizedBox(height: 8),

          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              children: [
                const TextSpan(text: "By submitting you agree to our "),
                TextSpan(
                  text: "Terms & Conditions",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: Theme.of(context).colorScheme.primary,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.pushNamed(context, '/terms');
                    },
                ),
                const TextSpan(text: " and "),
                TextSpan(
                  text: "Privacy Policy",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: Theme.of(context).colorScheme.primary,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.pushNamed(context, '/privacy');
                    },
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController? controller; 
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _InputField({
    required this.label,
    required this.hint,
    this.controller, 
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
  });


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator ?? (value) {
              if (value == null || value.trim().isEmpty) {
                return "Required";
              }
              return null;
            },

            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _DropdownField extends StatelessWidget {
  final String label;
  final String hint;
  final List<String> items;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.hint,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: value,
            hint: Text(
              hint,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            ),
            items: items
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e),
                  ),
                )
                .toList(),
            onChanged: onChanged,
            validator: (value) =>
                value == null ? "Required" : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MonthYearInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length > 6) {
      digitsOnly = digitsOnly.substring(0, 6);
    }

    String formatted = digitsOnly;

    if (digitsOnly.length >= 3) {
      formatted =
          '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
