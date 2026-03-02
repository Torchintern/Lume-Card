import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            onPressed: () {}, // Mark all as read
            tooltip: "Mark all as read",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildNotificationGroup("Today"),
          _buildNotificationItem(
            context,
            icon: Icons.notifications_active_rounded,
            title: "Security Alert",
            message: "New login detected on iPhone 15 Pro.",
            time: "2h ago",
            isUnread: true,
            color: Colors.orange,
          ),
          _buildNotificationItem(
            context,
            icon: Icons.card_giftcard_rounded,
            title: "New Reward!",
            message: "You've earned 50 points for your last trip.",
            time: "5h ago",
            isUnread: true,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 20),
          _buildNotificationGroup("Yesterday"),
          _buildNotificationItem(
            context,
            icon: Icons.payments_rounded,
            title: "Transaction Successful",
            message: "₹500.00 added to your Lume Card.",
            time: "1d ago",
            isUnread: false,
            color: Colors.green,
          ),
          _buildNotificationItem(
            context,
            icon: Icons.info_outline_rounded,
            title: "System Update",
            message: "Lume Student App is now on version 1.0.0.",
            time: "1d ago",
            isUnread: false,
            color: Colors.blue,
          ),
          const SizedBox(height: 20),
          _buildNotificationGroup("Earlier"),
          _buildNotificationItem(
            context,
            icon: Icons.directions_bus_rounded,
            title: "Bus Delayed",
            message: "Route 101 is running 15 mins late today.",
            time: "3d ago",
            isUnread: false,
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationGroup(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String time,
    required bool isUnread,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUnread) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
