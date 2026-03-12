import 'package:flutter/material.dart';

class NcmcDetailsScreen extends StatelessWidget {
  const NcmcDetailsScreen({super.key});

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
            expandedHeight: size.height * 0.25,
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
                  final double expandedHeight = size.height * 0.25;
                  final double collapsedHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
                  final double delta = expandedHeight - collapsedHeight;
                  final double progress = ((top - collapsedHeight) / delta).clamp(0.0, 1.0);

                  final double fontSize = 18 + (14 * progress);
                  
                  return Container(
                    padding: EdgeInsets.only(
                      left: 25 * (1 - progress) + (20 * progress), // Nudge right when collapsed
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
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -10,
                    right: 20,
                    child: Icon(
                      Icons.directions_transit_rounded,
                      size: 110,
                      color: Colors.white.withValues(alpha: 0.1),
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
                        color: Colors.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.withOpacity(0.1)),
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

