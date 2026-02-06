import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize notification service
  await NotificationService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smartlab',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // Global navigator key for notifications
      home: const AuthGate(),
      routes: {
        '/home': (context) => const AuthGate(), // Will be replaced with actual home page
        '/overdue-items': (context) => const AuthGate(), // Will be replaced with actual page
        '/borrow-requests': (context) => const AuthGate(), // Will be replaced with actual page
        '/equipment': (context) => const AuthGate(), // Will be replaced with actual page
        '/equipment-detail': (context) => const AuthGate(), // Will be replaced with actual page
        '/announcements': (context) => const AuthGate(), // Will be replaced with actual page
        '/analytics': (context) => const AuthGate(), // Will be replaced with actual page
      },
    );
  }
}
