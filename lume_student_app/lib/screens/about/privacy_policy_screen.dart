import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
            expandedHeight: size.height * 0.22,
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
                  final double expandedHeight = size.height * 0.22;
                  final double collapsedHeight =
                      MediaQuery.of(context).padding.top + kToolbarHeight;
                  final double delta = expandedHeight - collapsedHeight;
                  final double progress =
                      ((top - collapsedHeight) / delta).clamp(0.0, 1.0);

                  final double fontSize = 18 + (10 * progress);

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
                      "Privacy Policy",
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
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildSection("1. Data Collection",
                      "Lume collects personal information such as name, email, mobile number, and student credentials. Financial data is encrypted and handled by PCI-DSS compliant partners."),
                  _buildSection("2. How We Use Data",
                      "Your information is used to facilitate payments, manage student rewards, and provide a secure campus experience. We do not sell your personal data."),
                  _buildSection("3. Data Security",
                      "We use industry-standard encryption protocols (SSL/TLS) and multi-factor authentication to protect your sensitive data from unauthorized access."),
                  _buildSection("4. Cookies & Tracking",
                      "We use minimal tracking to improve app performance and provide personalized experiences. You can manage tracking preferences in app settings."),
                  _buildSection("5. Third-Party Services",
                      "Lume integrates with certain student platforms and payment gateways. These partners adhere to strict privacy standards."),
                  _buildSection("6. Your Rights",
                      "You have the right to access, update, or delete your account information at any time. Contact support for data portability requests."),
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      "Version: 1.0.0 | March 2026",
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
