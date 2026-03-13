import 'dart:async';
import 'package:flutter/material.dart';

class NcmcDetailsScreen extends StatefulWidget {
  const NcmcDetailsScreen({super.key});

  @override
  State<NcmcDetailsScreen> createState() => _NcmcDetailsScreenState();
}

class _NcmcDetailsScreenState extends State<NcmcDetailsScreen> {
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
            expandedHeight: size.height * 0.32,
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
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
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
                  final double expandedHeight = size.height * 0.32;
                  final double collapsedHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
                  final double delta = expandedHeight - collapsedHeight;
                  final double progress = ((top - collapsedHeight) / delta).clamp(0.0, 1.0);

                  final double fontSize = 18 + (14 * progress);
                  
                  return Container(
                    padding: EdgeInsets.only(
                      left: 25 * progress, 
                      bottom: 25 * progress, 
                    ),
                    alignment: Alignment.lerp(
                      Alignment.center, 
                      Alignment.bottomLeft,
                      progress,
                    ),
                    child: Text(
                      "NCMC Details",
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
                    top: MediaQuery.of(context).padding.top + 25,
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
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
              ),
            ),
          ),

          // Content Area 
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surface,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    _sectionTitle(context, "ONE APP - ONE CARD - TWO WALLETS"),
                    _card(
                      Icons.payments_rounded,
                      colorScheme.primary,
                      "Prepaid Wallet",
                      "Tap to pay anywhere - Shop, Fuel, Offline",
                      context: context,
                    ),
                    _card(
                      Icons.directions_train_rounded,
                      Colors.blueAccent,
                      "NCMC Wallet",
                      "Tap to travel anywhere - Metro, Bus, Ferries",
                      context: context,
                    ),
                    Image.asset(
                      "assets/images/ncmc_wallet.png",
                      height: 280,
                      fit: BoxFit.contain,
                    ),
                    
                    const SizedBox(height: 24),
                    _sectionTitle(context, "WHAT IS UNCLAIMED BALANCE?"),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: colorScheme.outlineVariant.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Amount transferred from prepaid to transit wallet but not yet synced to the card chip.",
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Image.asset(
                            "assets/images/ncmc_unclaim.png",
                            height: 160,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    _sectionTitle(context, "HOW TO CLAIM BALANCE"),
                    _card(
                      Icons.support_agent_rounded,
                      Colors.orange,
                      "Metro Station Counter",
                      "Visit customer care and ask to \"Update/Claim Balance\".",
                      context: context,
                    ),
                    _card(
                      Icons.point_of_sale_rounded,
                      Colors.green,
                      "Top-up Machine (AVM)",
                      "Tap card, select \"Claim Balance\", and wait for update.",
                      context: context,
                    ),
                    
                    const SizedBox(height: 16),
                    // Notice Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.withAlpha(25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 20, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Metro and bus agencies can take a few days to post the debit transactions resulting in late updation of the NCMC balance shown on the app.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.withOpacity(0.8),
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
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
          icon: Icons.directions_transit_rounded,
          title: "Transit Ready",
          subtitle: "Use one card for all your metro, bus, and parking needs across India.",
        );
      case 1:
        return _buildSlideBase(
          color1: const Color(0xFF1E1B4B),
          color2: const Color(0xFF4338CA),
          icon: Icons.sync_rounded,
          title: "Offline Sync",
          subtitle: "Balance is safely stored on your card chip for ultra-fast offline entry.",
        );
      case 2:
        return _buildSlideBase(
          color1: const Color(0xFF0F172A),
          color2: const Color(0xFF334155),
          icon: Icons.account_balance_wallet_rounded,
          title: "Dual Wallet",
          subtitle: "Separated funds for transit and shopping for better money management.",
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

  Widget _sectionTitle(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16, top: 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: colorScheme.onSurface.withOpacity(0.6),
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _card(IconData icon, Color color, String title, String subtitle, {required BuildContext context}) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outlineVariant.withOpacity(isDark ? 0.3 : 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800, 
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle, 
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
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
}

