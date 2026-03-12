import 'dart:async';
import 'package:flutter/material.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: progress > 0.5
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Help & Support",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5 * progress,
                          ),
                        ),
                        if (progress > 0.5)
                          Opacity(
                            opacity: ((progress - 0.5) * 2).clamp(0.0, 1.0),
                            child: const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                "Talk with Lume Assistant",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                      ],
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
                          Colors.black.withOpacity(0.3),
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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 100),
                    Icon(
                      Icons.construction_rounded,
                      size: 64,
                      color: colorScheme.primary.withOpacity(0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Chat bot under development",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
          icon: Icons.chat_bubble_rounded,
          title: "AI Assistant",
          subtitle: "Get instant answers and resolve issues with our Lume AI.",
        );
      case 1:
        return _buildSlideBase(
          color1: const Color(0xFF0F172A),
          color2: const Color(0xFF334155),
          icon: Icons.contact_support_rounded,
          title: "FAQs & Guides",
          subtitle: "Find step-by-step solutions in our help documentation.",
        );
      case 2:
        return _buildSlideBase(
          color1: const Color(0xFF1E1B4B),
          color2: const Color(0xFF4338CA),
          icon: Icons.headset_mic_rounded,
          title: "Contact Support",
          subtitle: "Connect with our team for personalized assistance.",
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