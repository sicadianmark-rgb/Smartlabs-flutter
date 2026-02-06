import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Global navigator key for navigation from notification service
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Service for handling Firebase Cloud Messaging and local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Stream controllers for handling notification events
  final StreamController<RemoteMessage> _messageStreamController = StreamController<RemoteMessage>.broadcast();
  final StreamController<String> _tokenStreamController = StreamController<String>.broadcast();
  
  // Public streams
  Stream<RemoteMessage> get messageStream => _messageStreamController.stream;
  Stream<String> get tokenStream => _tokenStreamController.stream;
  
  // Current FCM token
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize the notification service
  Future<void> initialize() async {
    // Request notification permissions
    await _requestPermissions();
    
    // Initialize local notifications
    await _initializeLocalNotifications();
    
    // Initialize Firebase Messaging
    await _initializeFirebaseMessaging();
    
    // Get initial message if app was opened from notification
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
    
    // Handle messages when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Get and listen to FCM token changes
    await _getFCMToken();
    _firebaseMessaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      _tokenStreamController.add(token);
      if (kDebugMode) {
        print('FCM Token refreshed: $token');
      }
    });
  }

  /// Request notification permissions for iOS and Android
  Future<void> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('Notification permission status: ${settings.authorizationStatus}');
    }
  }

  /// Initialize local notifications for Android and iOS
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Initialize Firebase Messaging settings
  Future<void> _initializeFirebaseMessaging() async {
    // Set foreground notification presentation options for iOS
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Subscribe to topics if needed
    // await _firebaseMessaging.subscribeToTopic('all_users');
  }

  /// Get FCM token
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      _tokenStreamController.add(_fcmToken ?? '');
      if (kDebugMode) {
        print('FCM Token: $_fcmToken');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
    }
  }

  /// Handle incoming messages when app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    _messageStreamController.add(message);
    
    // Show local notification for foreground messages
    _showLocalNotification(message);
  }

  /// Handle message when app is opened from notification
  void _handleMessage(RemoteMessage message) {
    _messageStreamController.add(message);
    _navigateToScreen(message);
  }

  /// Show local notification for foreground messages
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'smartlab_channel',
      'Smartlab Notifications',
      channelDescription: 'Notifications from Smartlab app',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Smartlab',
      message.notification?.body ?? 'You have a new notification',
      platformChannelSpecifics,
      payload: _buildPayload(message),
    );
  }

  /// Public method for testing - simulate receiving a message
  void simulateMessage(RemoteMessage message) {
    _handleForegroundMessage(message);
  }

  /// Build payload string from message data
  String _buildPayload(RemoteMessage message) {
    final Map<String, String> payload = {
      'screen': message.data['screen'] ?? 'home',
      'data': message.data.toString(),
    };
    return payload.toString();
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      // Parse payload and navigate
      _navigateFromPayload(payload);
    }
  }

  /// Navigate to appropriate screen based on message data
  void _navigateToScreen(RemoteMessage message) {
    final String? screen = message.data['screen'];
    final Map<String, dynamic> data = message.data;
    
    if (kDebugMode) {
      print('Navigating to screen: $screen with data: $data');
    }

    switch (screen) {
      case 'overdue_items':
        navigatorKey.currentState?.pushNamed('/overdue-items');
        break;
      case 'borrow_requests':
        navigatorKey.currentState?.pushNamed('/borrow-requests');
        break;
      case 'equipment':
        final String? equipmentId = data['equipment_id'];
        if (equipmentId != null) {
          navigatorKey.currentState?.pushNamed('/equipment-detail', arguments: equipmentId);
        } else {
          navigatorKey.currentState?.pushNamed('/equipment');
        }
        break;
      case 'announcements':
        navigatorKey.currentState?.pushNamed('/announcements');
        break;
      case 'analytics':
        navigatorKey.currentState?.pushNamed('/analytics');
        break;
      default:
        navigatorKey.currentState?.pushNamed('/home');
    }
  }

  /// Navigate based on payload string
  void _navigateFromPayload(String payload) {
    try {
      // Parse the payload string and extract screen information
      // This is a simplified parser - you might want to use JSON parsing
      if (payload.contains('overdue_items')) {
        navigatorKey.currentState?.pushNamed('/overdue-items');
      } else if (payload.contains('borrow_requests')) {
        navigatorKey.currentState?.pushNamed('/borrow-requests');
      } else if (payload.contains('equipment')) {
        navigatorKey.currentState?.pushNamed('/equipment');
      } else {
        navigatorKey.currentState?.pushNamed('/home');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing notification payload: $e');
      }
      navigatorKey.currentState?.pushNamed('/home');
    }
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    if (kDebugMode) {
      print('Subscribed to topic: $topic');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    if (kDebugMode) {
      print('Unsubscribed from topic: $topic');
    }
  }

  /// Dispose resources
  void dispose() {
    _messageStreamController.close();
    _tokenStreamController.close();
  }
}
