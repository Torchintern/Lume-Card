import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

class TransactionsScreen extends StatefulWidget {
  final int initialTab;
  const TransactionsScreen({super.key, this.initialTab = 0});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _transactions = [];
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  late PageController _headerPageController;
  Timer? _headerAutoScrollTimer;
  int _currentHeaderPage = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      if (mounted) {
        if (_tabController.index == 1 && _selectedFilter == 'Received') {
          _selectedFilter = 'All'; // Reset filter when switching to Transit
        }
        setState(() {}); // Repaint filters layout 
      }
    });
    _headerPageController = PageController(initialPage: 400);
    _startHeaderAutoScroll();
    _fetchTransactions();
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
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;

      final res = await ApiService.getTransactions(token);
      if (mounted) {
        setState(() {
          _transactions = res;
        });
      }
    } catch (e) {
      debugPrint("Error fetching transactions: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    
    final List<String> currentFilters = _tabController.index == 1 
      ? ['All', 'Paid', 'Topup'] 
      : ['All', 'Paid', 'Received', 'Topup'];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. Dynamic Premium Header (Flying Title)
                SliverAppBar(
                expandedHeight: size.height * 0.3,
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
                      final double expandedHeight = size.height * 0.3;
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
                          "Transactions",
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

                // 2. Pinned Controls (Tabs, Search, Filters)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedHeaderDelegate(
                    height: 230,
                    child: Container(
                      color: colorScheme.surface,
                      child: Column(
                        children: [
                          // Sticky Rounded Top Transition
                          Container(
                            height: 20,
                            transform: Matrix4.translationValues(0, -19, 0),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(30),
                                topRight: Radius.circular(30),
                              ),
                            ),
                          ),
                          // Tabs
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                indicator: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withOpacity(isDark ? 0.3 : 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                labelColor: Colors.white,
                                unselectedLabelColor:
                                    isDark ? Colors.white70 : const Color(0xFF64748B),
                                labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 14),
                                unselectedLabelStyle: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                                tabs: const [
                                  Tab(text: "Lume Card"),
                                  Tab(text: "Transit (NCMC)"),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Search Bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) =>
                                    setState(() => _searchQuery = value),
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Search transactions...",
                                  hintStyle: TextStyle(
                                    color: isDark ? Colors.white38 : Colors.black38,
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: colorScheme.primary.withOpacity(0.7),
                                    size: 20,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 18),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Horizontal Filters
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: currentFilters.map((filter) {
                                bool isSelected = _selectedFilter == filter;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: ChoiceChip(
                                    label: Text(filter),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _selectedFilter = filter);
                                      }
                                    },
                                    backgroundColor: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : const Color(0xFFF1F5F9),
                                    selectedColor: colorScheme.primary,
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : const Color(0xFF64748B)),
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide.none,
                                    ),
                                    showCheckmark: false,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Independent Scrollable Transactions List
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTransactionsList(colorScheme, isDark, "card"),
                      _buildTransactionsList(colorScheme, isDark, "transit"),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTransactionsList(ColorScheme colorScheme, bool isDark, String tabType) {
    return RefreshIndicator(
      onRefresh: _fetchTransactions,
      child: Builder(
        builder: (context) {
          final filteredTransactions = _transactions.where((tx) {
            // Category Filter based on Tab
            final category = tx["category"]?.toString() ?? "Card";
            bool matchesTab = tabType == "transit" 
              ? category.toLowerCase() == "transit" 
              : category.toLowerCase() != "transit";

            bool matchesType = _selectedFilter == 'All' || 
              tx['type'].toString().toLowerCase() == _selectedFilter.toLowerCase();
            
            bool matchesSearch = _searchQuery.isEmpty || 
              tx['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
              tx['amount'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
              tx['status'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
              tx['type'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
              tx['date'].toString().toLowerCase().contains(_searchQuery.toLowerCase());

            return matchesTab && matchesType && matchesSearch;
          }).toList();

          if (filteredTransactions.isEmpty) {
            return _buildEmptyState(
              colorScheme, 
              filterActive: _selectedFilter != 'All' || _searchQuery.isNotEmpty,
              isTransit: tabType == "transit" && _selectedFilter == 'All' && _searchQuery.isEmpty
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            physics: const BouncingScrollPhysics(),
            itemCount: filteredTransactions.length,
            itemBuilder: (context, index) {
              return _buildTransactionItem(filteredTransactions[index], colorScheme, isDark);
            },
          );
        }
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, {bool filterActive = false, bool isTransit = false}) {
    IconData icon = filterActive ? Icons.filter_list_off_rounded : Icons.receipt_long_rounded;
    String text = filterActive ? "No matching transactions" : "No transactions yet";

    if (isTransit) {
      icon = Icons.directions_transit_rounded;
      text = "No transit history found";
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: 400,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
            const SizedBox(height: 20),
            Text(
              text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx, ColorScheme colorScheme, bool isDark) {
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
      onTap: () => _showTransactionDetails(tx, colorScheme, isDark),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
                    tx["title"] ?? "Transaction",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tx["date"] ?? "Date N/A",
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
                  "$prefix₹${(tx["amount"] ?? 0.0).toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tx["status"] ?? "Status",
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

  void _showTransactionDetails(Map<String, dynamic> tx, ColorScheme colorScheme, bool isDark) {
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

  Widget _buildHeaderSlide(int index, ColorScheme colorScheme) {
    switch (index) {
      case 0:
        return _buildSlideBase(
          color1: colorScheme.primary,
          color2: colorScheme.secondary,
          icon: Icons.insights_rounded,
          title: "Spending Analysis",
          subtitle: "Track where your money goes across all your expenses.",
        );
      case 1:
        return _buildSlideBase(
          color1: const Color(0xFF1E1B4B),
          color2: const Color(0xFF4338CA),
          icon: Icons.credit_card_rounded,
          title: "Card Management",
          subtitle: "Quickly view and filter transactions for your Virtual Card.",
        );
      case 2:
        return _buildSlideBase(
          color1: const Color(0xFF0F172A),
          color2: const Color(0xFF334155),
          icon: Icons.directions_bus_rounded,
          title: "Transit History",
          subtitle: "Effortlessly track your NCMC and transit spends.",
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

// Delegate for the Pinned Header containing Tabs, Search, and Filters
class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _PinnedHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}