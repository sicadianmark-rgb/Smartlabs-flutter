import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/notification_manager.dart';

/// Widget for testing and demonstrating notification functionality
class NotificationTestWidget extends StatefulWidget {
  const NotificationTestWidget({super.key});

  @override
  State<NotificationTestWidget> createState() => _NotificationTestWidgetState();
}

class _NotificationTestWidgetState extends State<NotificationTestWidget> {
  final NotificationManager _notificationManager = NotificationManager();
  String? _fcmToken;
  String _notificationStatus = 'No notifications received';

  @override
  void initState() {
    super.initState();
    _initializeNotificationListener();
    _getFCMToken();
  }

  void _initializeNotificationListener() {
    _notificationManager.listenToNotifications((RemoteMessage message) {
      setState(() {
        _notificationStatus = 
            'Received: ${message.notification?.title ?? "No title"}\n'
            'Body: ${message.notification?.body ?? "No body"}\n'
            'Screen: ${message.data['screen'] ?? "home"}\n'
            'Type: ${message.data['type'] ?? "unknown"}';
      });
    });
  }

  void _getFCMToken() {
    setState(() {
      _fcmToken = _notificationManager.currentToken;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FCM Token:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                _fcmToken ?? 'Loading...',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Test Notifications:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _notificationManager.sendTestNotification();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test notification sent!')),
                );
              },
              child: const Text('Send Test Notification'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                await _notificationManager.subscribeToSmartlabNotifications();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Subscribed to Smartlab notifications!')),
                );
              },
              child: const Text('Subscribe to Notifications'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                await _notificationManager.unsubscribeFromSmartlabNotifications();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unsubscribed from notifications')),
                );
              },
              child: const Text('Unsubscribe from Notifications'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Last Notification:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(_notificationStatus),
            ),
            const SizedBox(height: 24),
            const Text(
              'Instructions:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Copy the FCM token above\n'
              '2. Use Firebase Console to send test messages\n'
              '3. Include data fields for navigation:\n'
              '   - screen: "overdue_items", "equipment", etc.\n'
              '4. Test with app in foreground, background, and closed',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
