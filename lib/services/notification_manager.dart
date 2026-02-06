import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

/// Service for managing notification preferences and sending test notifications
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final NotificationService _notificationService = NotificationService();

  /// Get current FCM token
  String? get currentToken => _notificationService.fcmToken;

  /// Subscribe to smartlab notifications
  Future<void> subscribeToSmartlabNotifications() async {
    await _notificationService.subscribeToTopic('smartlab_users');
    await _notificationService.subscribeToTopic('overdue_items');
    await _notificationService.subscribeToTopic('borrow_requests');
    
    if (kDebugMode) {
      print('Subscribed to Smartlab notification topics');
    }
  }

  /// Unsubscribe from smartlab notifications
  Future<void> unsubscribeFromSmartlabNotifications() async {
    await _notificationService.unsubscribeFromTopic('smartlab_users');
    await _notificationService.unsubscribeFromTopic('overdue_items');
    await _notificationService.unsubscribeFromTopic('borrow_requests');
    
    if (kDebugMode) {
      print('Unsubscribed from Smartlab notification topics');
    }
  }

  /// Send test notification (for development)
  /// This would typically be done from a backend service
  void sendTestNotification() {
    if (kDebugMode) {
      // This is just for testing - in production, notifications come from your backend
      final RemoteMessage testMessage = RemoteMessage(
        notification: RemoteNotification(
          title: 'Test Notification',
          body: 'This is a test notification from Smartlab',
        ),
        data: {
          'screen': 'home',
          'type': 'test',
        },
      );
      
      // Simulate receiving a message for testing
      _notificationService.simulateMessage(testMessage);
      
      if (kDebugMode) {
        print('Test notification sent');
      }
    }
  }

  /// Handle notification stream for UI updates
  void listenToNotifications(Function(RemoteMessage) onMessageReceived) {
    _notificationService.messageStream.listen(onMessageReceived);
  }

  /// Handle token stream for backend updates
  void listenToTokenChanges(Function(String) onTokenChanged) {
    _notificationService.tokenStream.listen(onTokenChanged);
  }

  /// Example notification data structures for different types
  static Map<String, String> overdueItemsNotification(String itemCount) {
    return {
      'title': 'Overdue Items Alert',
      'body': 'You have $itemCount overdue item(s) that need to be returned',
      'screen': 'overdue_items',
      'type': 'overdue_alert',
      'count': itemCount,
    };
  }

  static Map<String, String> borrowRequestNotification(String itemName, String requesterName) {
    return {
      'title': 'New Borrow Request',
      'body': '$requesterName wants to borrow $itemName',
      'screen': 'borrow_requests',
      'type': 'borrow_request',
      'item_name': itemName,
      'requester': requesterName,
    };
  }

  static Map<String, String> equipmentAvailableNotification(String equipmentName) {
    return {
      'title': 'Equipment Available',
      'body': '$equipmentName is now available for borrowing',
      'screen': 'equipment',
      'type': 'equipment_available',
      'equipment_name': equipmentName,
    };
  }

  static Map<String, String> announcementNotification(String announcementTitle) {
    return {
      'title': 'New Announcement',
      'body': announcementTitle,
      'screen': 'announcements',
      'type': 'announcement',
      'announcement_title': announcementTitle,
    };
  }
}
