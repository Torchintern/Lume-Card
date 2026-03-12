import 'dart:async';
import 'package:flutter/material.dart';

class AboutLumeScreen extends StatefulWidget {
  const AboutLumeScreen({super.key});

  @override
  State<AboutLumeScreen> createState() => _AboutLumeScreenState();
}

class _AboutLumeScreenState extends State<AboutLumeScreen> {
  late PageController _headerPageController;
  Timer? _headerAutoScrollTimer;
  int _currentHeaderPage = 0;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _headerAutoScrollTimer?.cancel();
    _headerPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
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
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
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
                  final double collapsedHeight =
                      MediaQuery.of(context).padding.top + kToolbarHeight;
                  final double delta = expandedHeight - collapsedHeight;
                  final double progress =
                      ((top - collapsedHeight) / delta).clamp(0.0, 1.0);

                  final double fontSize = 18 + (12 * progress);

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
                      "About Lume",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1 * progress,
                      ),
                    ),
                  );
                },
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
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
                  
                  // Overlay Gradient
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
                  _buildSectionTitle(context, "OUR MISSION"),
                  const Text(
                    "Lume is dedicated to empowering students by providing a seamless, all-in-one digital campus experience. We bridge the gap between financial needs and academic aspirations with our innovative scholar solutions and integrated campus features.",
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, "APP INFORMATION"),
                  _buildInfoTile(
                    context,
                    Icons.info_outline_rounded,
                    "Version",
                    "1.1.0 (Premium Build)",
                  ),
                  _buildInfoTile(
                    context,
                    Icons.update_rounded,
                    "Last Updated",
                    "March 2026",
                  ),
                  _buildInfoTile(
                    context,
                    Icons.developer_mode_rounded,
                    "Developer",
                    "Lume FinTech Team",
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, "CONNECT WITH US"),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialButton(context, Icons.language_rounded, "Website"),
                      _buildSocialButton(context, Icons.email_rounded, "Support"),
                      _buildSocialButton(context, Icons.share_rounded, "Share"),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "© 2026 Lume Card. All rights reserved.",
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Made with ♥ for Students",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(BuildContext context, IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: colorScheme.primary),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildHeaderSlide(int index, ColorScheme colorScheme) {
    switch (index) {
      case 0:
        return _buildSlideBase(
          color1: colorScheme.primary,
          color2: colorScheme.secondary,
          icon: Icons.lightbulb_rounded,
          title: "Our Vision",
          subtitle: "Empowering every student with seamless digital financial tools.",
        );
      case 1:
        return _buildSlideBase(
          color1: const Color(0xFF0F172A),
          color2: const Color(0xFF334155),
          icon: Icons.auto_graph_rounded,
          title: "Lume Innovation",
          subtitle: "Pioneering NCMC integration for a smarter campus experience.",
        );
      case 2:
        return _buildSlideBase(
          color1: const Color(0xFF1E1B4B),
          color2: const Color(0xFF4338CA),
          icon: Icons.groups_rounded,
          title: "Our Community",
          subtitle: "Built by students, for students, to fuel academic dreams.",
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
          // Lume Logo at Right Side
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: 0.8,
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      "assets/logo.png",
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
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
