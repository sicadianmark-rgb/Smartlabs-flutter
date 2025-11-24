// lib/home/services/teacher_service.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class TeacherService extends ChangeNotifier {
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get teachers => _teachers;
  bool get isLoading => _isLoading;

  Future<void> loadTeachers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final DatabaseReference usersRef = FirebaseDatabase.instance.ref().child(
        'users',
      );
      final DatabaseEvent event = await usersRef.once();

      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> usersData =
            event.snapshot.value as Map<dynamic, dynamic>;

        List<Map<String, dynamic>> teachers = [];

        usersData.forEach((userId, userData) {
          if (userData is Map && userData['role'] == 'teacher') {
            teachers.add({
              'id': userId,
              'name': userData['name'] ?? 'Unknown Teacher',
              'email': userData['email'] ?? '',
            });
          }
        });

        // Sort teachers by name
        teachers.sort(
          (a, b) => a['name'].toString().compareTo(b['name'].toString()),
        );

        _teachers = teachers;
      }
    } catch (e) {
      // Handle error silently or add error state if needed
      debugPrint('Failed to load teachers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearTeachers() {
    _teachers.clear();
    notifyListeners();
  }
}
