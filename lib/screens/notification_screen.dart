import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/app_notification.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.checkCheck),
            onPressed: () {
              firestore.markAllNotificationsAsRead(auth.currentUserId ?? '');
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All notifications marked as read')));
            },
            tooltip: 'Mark all as read',
          )
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: firestore.streamUserNotifications(auth.currentUserId ?? ''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.bellOff, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No notifications yet', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              return Card(
                elevation: n.isRead ? 0 : 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: n.isRead ? Colors.grey.shade50 : Colors.white,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: n.type == 'approval' ? Colors.green.shade50 : Colors.blue.shade50,
                    child: Icon(
                      n.type == 'approval' ? LucideIcons.checkCircle : LucideIcons.bell,
                      color: n.type == 'approval' ? Colors.green : Colors.blue,
                      size: 20,
                    ),
                  ),
                  title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.body),
                      const SizedBox(height: 4),
                      Text(
                        '${n.createdAt.hour}:${n.createdAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                  onTap: () {
                    firestore.markNotificationAsRead(n.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
