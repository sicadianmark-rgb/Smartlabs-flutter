# Firebase Cloud Messaging (FCM) Setup for Smartlab

This document explains how to set up and use push notifications in the Smartlab Flutter app using Firebase Cloud Messaging.

## Features Implemented

✅ **Firebase Cloud Messaging Integration**
- FCM token management
- Permission handling for Android and iOS
- Topic-based subscriptions
- Foreground, background, and terminated app state handling

✅ **Local Notifications**
- Display notifications when app is in foreground
- Custom notification channels (Android)
- Sound, badge, and alert support

✅ **Navigation Routing**
- Dynamic navigation based on notification data
- Support for different screens (overdue items, equipment, announcements, etc.)
- Deep linking from notifications

✅ **Cross-Platform Support**
- Android permissions and services configured
- iOS background modes and capabilities
- Platform-specific notification handling

## Setup Instructions

### 1. Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (smartlab-e2107)
3. Enable Cloud Messaging API
4. Download the latest `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

### 2. Android Setup

The Android manifest is already configured with:
- Required permissions (POST_NOTIFICATIONS, WAKE_LOCK, VIBRATE)
- FCM service and receiver
- Intent filters for notification taps

### 3. iOS Setup

The iOS Info.plist is configured with:
- Background modes for remote notifications
- Required capabilities for push notifications

### 4. Install Dependencies

```bash
flutter pub get
```

## Usage

### Basic Initialization

The notification service is automatically initialized in `main.dart`:

```dart
await NotificationService().initialize();
```

### Getting FCM Token

```dart
final notificationService = NotificationService();
String? token = notificationService.fcmToken;
print('FCM Token: $token');
```

### Subscribing to Topics

```dart
final notificationManager = NotificationManager();

// Subscribe to all Smartlab notifications
await notificationManager.subscribeToSmartlabNotifications();

// Or subscribe to specific topics
await notificationService.subscribeToTopic('overdue_items');
await notificationService.subscribeToTopic('borrow_requests');
```

### Listening to Notifications

```dart
final notificationManager = NotificationManager();

// Listen to incoming messages
notificationManager.listenToNotifications((RemoteMessage message) {
  print('Received notification: ${message.notification?.title}');
  // Handle UI updates, show badges, etc.
});

// Listen to token changes
notificationManager.listenToTokenChanges((String token) {
  // Send token to your backend
  print('New FCM token: $token');
});
```

## Notification Data Structure

Notifications should include the following data for proper routing:

```json
{
  "notification": {
    "title": "Notification Title",
    "body": "Notification body text"
  },
  "data": {
    "screen": "target_screen_name",
    "type": "notification_type",
    "additional_data": "custom_data"
  }
}
```

### Supported Screen Routes

- `home` - Navigate to home screen
- `overdue_items` - Navigate to overdue items page
- `borrow_requests` - Navigate to borrow requests page
- `equipment` - Navigate to equipment list
- `equipment_detail` - Navigate to specific equipment (requires `equipment_id`)
- `announcements` - Navigate to announcements page
- `analytics` - Navigate to analytics page

## Notification Types

### Overdue Items Alert
```dart
final data = NotificationManager.overdueItemsNotification('3');
```

### Borrow Request
```dart
final data = NotificationManager.borrowRequestNotification('Microscope', 'John Doe');
```

### Equipment Available
```dart
final data = NotificationManager.equipmentAvailableNotification('Centrifuge');
```

### New Announcement
```dart
final data = NotificationManager.announcementNotification('Lab Closed Tomorrow');
```

## Testing

### Test Notification (Development Only)

```dart
final notificationManager = NotificationManager();
notificationManager.sendTestNotification();
```

### Backend Testing

Use your Firebase console or backend service to send test notifications:

1. Go to Firebase Console → Cloud Messaging
2. Create new campaign
3. Target your app (use FCM token or topic)
4. Include proper data fields for routing

## Backend Integration

To send notifications from your backend:

### Using Firebase Admin SDK

```javascript
const admin = require('firebase-admin');

// Send to specific token
await admin.messaging().send({
  token: 'user_fcm_token',
  notification: {
    title: 'Overdue Items',
    body: 'You have 2 overdue items',
  },
  data: {
    screen: 'overdue_items',
    type: 'overdue_alert',
    count: '2',
  },
});

// Send to topic
await admin.messaging().send({
  topic: 'overdue_items',
  notification: {
    title: 'Equipment Available',
    body: 'Microscope is now available',
  },
  data: {
    screen: 'equipment',
    type: 'equipment_available',
    equipment_name: 'Microscope',
  },
});
```

## Troubleshooting

### Common Issues

1. **Notifications not appearing**
   - Check permissions on device
   - Verify FCM token is registered with backend
   - Check app notification settings

2. **Navigation not working**
   - Verify screen names match routes in main.dart
   - Check data payload structure
   - Ensure navigatorKey is properly set

3. **iOS notifications not working**
   - Check APNs certificates in Firebase Console
   - Verify bundle identifier matches
   - Ensure device is registered for remote notifications

### Debug Logging

Enable debug logging to troubleshoot:

```dart
// In notification_service.dart, debug prints are already included
// They will show when kDebugMode is true
```

## Security Considerations

- FCM tokens should be sent to your backend over HTTPS
- Validate notification data before processing
- Don't include sensitive information in notification payloads
- Use topic subscriptions carefully to avoid spam

## Next Steps

1. Integrate with your existing backend service
2. Set up automated notifications for:
   - Overdue item reminders
   - Borrow request updates
   - Equipment availability changes
   - New announcements
3. Add notification preferences in user settings
4. Implement notification history/log
5. Add badge count management

## Files Modified/Created

- `pubspec.yaml` - Added FCM dependencies
- `lib/main.dart` - Initialize notification service
- `lib/services/notification_service.dart` - Core FCM handling
- `lib/services/notification_manager.dart` - High-level API
- `android/app/src/main/AndroidManifest.xml` - Android permissions
- `ios/Runner/Info.plist` - iOS capabilities
