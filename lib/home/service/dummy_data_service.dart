// lib/home/service/dummy_data_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'equipment_service.dart';
import 'laboratory_service.dart';
import 'teacher_service.dart';
import '../models/equipment_models.dart';

class DummyDataService {
  static final _database = FirebaseDatabase.instance;

  /// Insert dummy borrow requests to test association rule mining
  /// Creates patterns where certain items are borrowed together
  static Future<void> insertDummyBorrowRequests({
    int numUsers = 50,
    int requestsPerUser = 3,
  }) async {
    try {
      debugPrint('Starting dummy data insertion...');

      // Step 1: Fetch equipment items
      final allItems = await EquipmentService.getAllItems();
      if (allItems.isEmpty) {
        debugPrint('No equipment items found. Please add equipment first.');
        return;
      }

      debugPrint('Found ${allItems.length} equipment items');

      // Step 2: Fetch category names
      final categoryNames = <String, String>{};
      final categoriesSnapshot =
          await _database.ref().child('equipment_categories').get();
      if (categoriesSnapshot.exists) {
        final categoriesData =
            categoriesSnapshot.value as Map<dynamic, dynamic>;
        for (var entry in categoriesData.entries) {
          final categoryId = entry.key;
          final categoryData = entry.value as Map<dynamic, dynamic>;
          categoryNames[categoryId] =
              categoryData['title'] ?? 'Unknown Category';
        }
      }

      // Step 3: Fetch laboratories
      final labService = LaboratoryService();
      await labService.loadLaboratories();
      final labs = labService.laboratories;
      if (labs.isEmpty) {
        debugPrint('No laboratories found. Using default.');
        return;
      }

      debugPrint('Found ${labs.length} laboratories');

      // Step 4: Fetch teachers
      final teacherService = TeacherService();
      await teacherService.loadTeachers();
      final teachers = teacherService.teachers;
      if (teachers.isEmpty) {
        debugPrint('No teachers found. Please add teachers first.');
        return;
      }

      debugPrint('Found ${teachers.length} teachers');

      // Step 5: Get or create dummy users
      final dummyUsers = await _getOrCreateDummyUsers(numUsers);

      debugPrint('Created/found ${dummyUsers.length} dummy users');

      // Step 6: Define common equipment pairs/patterns for association rules
      final patterns = _getEquipmentPatterns(allItems);

      debugPrint('Using ${patterns.length} equipment patterns');

      // Step 7: Create borrow requests with patterns
      int totalRequests = 0;
      final now = DateTime.now();

      for (int userIndex = 0; userIndex < dummyUsers.length; userIndex++) {
        final user = dummyUsers[userIndex];
        final userRequestCount = requestsPerUser;

        // Select a pattern for this user (rotate through patterns)
        final patternIndex = userIndex % patterns.length;

        // Get random teacher and lab
        final teacher = teachers[userIndex % teachers.length];
        final lab = labs[userIndex % labs.length];

        // Create requests for this user following the pattern
        // All items in the pattern are borrowed together by the same user
        // This creates the association pattern
        for (int i = 0; i < userRequestCount; i++) {
          final daysAgo = 30 - (i * 10); // Requests from 30, 20, 10 days ago
          final requestDate = now.subtract(Duration(days: daysAgo));
          final dateToBeUsed = requestDate.add(const Duration(days: 1));
          final dateToReturn = dateToBeUsed.add(const Duration(days: 7));

          // Get items from the pattern (use different patterns each time)
          final patternItems = patterns[(patternIndex + i) % patterns.length];
          if (patternItems.isEmpty) continue;

          // Create a request for each item in the pattern
          // All these requests have same date, so they're borrowed together
          for (final item in patternItems) {
            final categoryName =
                categoryNames[item.categoryId] ?? 'Unknown Category';

            final requestData = {
              'userId': user['id'],
              'userEmail': user['email'],
              'itemId': item.id,
              'categoryId': item.categoryId,
              'itemName': item.name,
              'categoryName': categoryName,
              'itemNo':
                  'LAB-${item.id.substring(0, item.id.length > 5 ? 5 : item.id.length).toUpperCase()}',
              'laboratory': lab.labName,
              'labId': lab.labId,
              'labRecordId': lab.id,
              'quantity': 1,
              'dateToBeUsed': dateToBeUsed.toIso8601String(),
              'dateToReturn': dateToReturn.toIso8601String(),
              'adviserName': teacher['name'],
              'adviserId': teacher['id'],
              'status':
                  'approved', // Mark as approved so association rules can use them
              'requestedAt': requestDate.toIso8601String(),
              'processedAt':
                  requestDate.add(const Duration(hours: 1)).toIso8601String(),
              'processedBy': teacher['id'],
            };

            final requestRef = _database.ref().child('borrow_requests').push();
            final requestId = requestRef.key!;
            requestData['requestId'] = requestId;

            await requestRef.set(requestData);
            totalRequests++;
          }
        }

        // Progress update every 10 users
        if ((userIndex + 1) % 10 == 0) {
          debugPrint(
            'Processed ${userIndex + 1}/${dummyUsers.length} users...',
          );
        }
      }

      debugPrint('Successfully inserted $totalRequests dummy borrow requests!');
      debugPrint(
        'Patterns created: ${patterns.length} different equipment combinations',
      );
    } catch (e) {
      debugPrint('Error inserting dummy data: $e');
      rethrow;
    }
  }

  /// Get or create dummy users for testing
  static Future<List<Map<String, dynamic>>> _getOrCreateDummyUsers(
    int count,
  ) async {
    final users = <Map<String, dynamic>>[];

    try {
      // Check if dummy users already exist
      final usersSnapshot = await _database.ref().child('users').get();

      if (usersSnapshot.exists) {
        final usersData = usersSnapshot.value as Map<dynamic, dynamic>;

        // Find existing dummy users (users with email containing "dummy")
        for (var entry in usersData.entries) {
          final userData = entry.value;
          if (userData is Map &&
              userData['email'] != null &&
              (userData['email'] as String).contains('dummy')) {
            users.add({
              'id': entry.key,
              'email': userData['email'],
              'name': userData['name'] ?? 'Dummy User',
            });
          }
        }
      }

      // Create additional dummy users if needed
      for (int i = users.length; i < count; i++) {
        final userId = _database.ref().child('users').push().key!;
        final userData = {
          'name': 'Dummy User ${i + 1}',
          'email': 'dummy.user${i + 1}@test.com',
          'role': 'student',
          'course': 'Computer Science',
          'yearLevel': ((i % 4) + 1).toString(),
          'section': String.fromCharCode(65 + (i % 4)), // A, B, C, D
        };

        await _database.ref().child('users').child(userId).set(userData);

        users.add({
          'id': userId,
          'email': userData['email'],
          'name': userData['name'],
        });
      }

      return users.take(count).toList();
    } catch (e) {
      debugPrint('Error getting/creating dummy users: $e');
      return users;
    }
  }

  /// Define equipment patterns that should be borrowed together
  /// These patterns will create association rules
  static List<List<EquipmentItem>> _getEquipmentPatterns(
    List<EquipmentItem> allItems,
  ) {
    final patterns = <List<EquipmentItem>>[];

    if (allItems.isEmpty) return patterns;

    // Group items by category
    final itemsByCategory = <String, List<EquipmentItem>>{};
    for (var item in allItems) {
      itemsByCategory.putIfAbsent(item.categoryId, () => []);
      itemsByCategory[item.categoryId]!.add(item);
    }

    // Pattern 1: Items from same category (2-3 items)
    for (var categoryItems in itemsByCategory.values) {
      if (categoryItems.length >= 2) {
        // Take first 2-3 items from this category
        final patternSize = categoryItems.length >= 3 ? 3 : 2;
        patterns.add(categoryItems.take(patternSize).toList());
      }
    }

    // Pattern 2: Mix items from different categories (2 items)
    final categoryList = itemsByCategory.values.toList();
    for (int i = 0; i < categoryList.length - 1 && i < 10; i++) {
      if (categoryList[i].isNotEmpty && categoryList[i + 1].isNotEmpty) {
        patterns.add([categoryList[i].first, categoryList[i + 1].first]);
      }
    }

    // Pattern 3: Single items (to create variety)
    for (var item in allItems.take(10)) {
      patterns.add([item]);
    }

    // Limit patterns to avoid too many combinations
    return patterns.take(20).toList();
  }

  /// Clear all dummy borrow requests (for cleanup)
  static Future<void> clearDummyBorrowRequests() async {
    try {
      final snapshot = await _database.ref().child('borrow_requests').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        int deleted = 0;

        for (var entry in data.entries) {
          final requestData = entry.value;
          if (requestData is Map) {
            final userEmail = requestData['userEmail'] as String?;
            if (userEmail != null && userEmail.contains('dummy')) {
              await _database
                  .ref()
                  .child('borrow_requests')
                  .child(entry.key)
                  .remove();
              deleted++;
            }
          }
        }

        debugPrint('Deleted $deleted dummy borrow requests');
      }
    } catch (e) {
      debugPrint('Error clearing dummy data: $e');
      rethrow;
    }
  }
}
