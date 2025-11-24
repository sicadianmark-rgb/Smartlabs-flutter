// lib/services/equipment_service.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/equipment_models.dart';

class EquipmentService {
  static final _database = FirebaseDatabase.instance;

  // Get all equipment categories
  static Future<List<EquipmentCategory>> getCategories() async {
    List<EquipmentCategory> categories = [];

    try {
      final snapshot =
          await _database.ref().child('equipment_categories').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        for (var entry in data.entries) {
          final categoryId = entry.key;
          final categoryData = entry.value as Map<dynamic, dynamic>;

          // Calculate total count by summing quantities (consistent with _updateCategoryCounts)
          int totalCount = 0;
          int availableCount = 0;
          if (categoryData['equipments'] != null) {
            final equipments =
                categoryData['equipments'] as Map<dynamic, dynamic>;
            
            for (var itemData in equipments.values) {
              final item = itemData as Map<dynamic, dynamic>;
              final quantity =
                  int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
              final quantityBorrowed =
                  int.tryParse(item['quantity_borrowed']?.toString() ?? '0') ?? 0;
              
              totalCount += quantity;
              
              if (item['status']?.toString().toLowerCase() == 'available') {
                // Available = total quantity - quantity borrowed
                final available = (quantity - quantityBorrowed).clamp(0, quantity);
                availableCount += available;
              }
            }
          }

          // Create category with calculated counts
          final category = EquipmentCategory.fromMap(categoryId, categoryData);
          final updatedCategory = EquipmentCategory(
            id: category.id,
            title: category.title,
            availableCount: availableCount, // Use calculated value instead of stored
            totalCount: totalCount,
            icon: category.icon,
            color: category.color,
            createdAt: category.createdAt,
            updatedAt: category.updatedAt,
            labId: category.labId,
            labRecordId: category.labRecordId,
            labName: category.labName,
          );

          categories.add(updatedCategory);
        }
      }
    } catch (e) {
      debugPrint('Error loading equipment categories: $e');
      rethrow;
    }

    return categories;
  }

  // Get items for a specific category from the new structure
  static Future<List<EquipmentItem>> getCategoryItems(String categoryId) async {
    List<EquipmentItem> items = [];

    try {
      final snapshot =
          await _database
              .ref()
              .child('equipment_categories')
              .child(categoryId)
              .child('equipments')
              .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        for (var entry in data.entries) {
          final itemId = entry.key;
          final itemData = entry.value as Map<dynamic, dynamic>;

          final item = EquipmentItem.fromMap(itemId, itemData);
          items.add(item);
        }
      }
    } catch (e) {
      debugPrint('Error loading category items: $e');
      rethrow;
    }

    return items;
  }

  // Get all equipment items across all categories
  static Future<List<EquipmentItem>> getAllItems() async {
    List<EquipmentItem> allItems = [];

    try {
      final snapshot =
          await _database.ref().child('equipment_categories').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        for (var categoryEntry in data.entries) {
          final categoryId = categoryEntry.key;
          final categoryData = categoryEntry.value as Map<dynamic, dynamic>;

          if (categoryData['equipments'] != null) {
            final equipments =
                categoryData['equipments'] as Map<dynamic, dynamic>;

            for (var itemEntry in equipments.entries) {
              final itemId = itemEntry.key;
              final itemData = itemEntry.value as Map<dynamic, dynamic>;

              // Add categoryId to item data
              final itemWithCategory = Map<dynamic, dynamic>.from(itemData);
              itemWithCategory['categoryId'] = categoryId;

              final item = EquipmentItem.fromMap(itemId, itemWithCategory);
              allItems.add(item);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading all items: $e');
      rethrow;
    }

    return allItems;
  }

  // Add a new category
  static Future<void> addCategory(EquipmentCategory category) async {
    try {
      final categoryRef = _database.ref().child('equipment_categories').push();
      await categoryRef.set(category.toMap());
    } catch (e) {
      debugPrint('Error adding category: $e');
      rethrow;
    }
  }

  // Update a category
  static Future<void> updateCategory(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      data['updatedAt'] = DateTime.now().toIso8601String();
      await _database
          .ref()
          .child('equipment_categories')
          .child(id)
          .update(data);
    } catch (e) {
      debugPrint('Error updating category: $e');
      rethrow;
    }
  }

  // Delete a category and all its equipment
  static Future<void> deleteCategory(String categoryId) async {
    try {
      await _database
          .ref()
          .child('equipment_categories')
          .child(categoryId)
          .remove();
    } catch (e) {
      debugPrint('Error deleting category: $e');
      rethrow;
    }
  }

  // Add an item to a category
  static Future<void> addItem(EquipmentItem item) async {
    try {
      final itemRef =
          _database
              .ref()
              .child('equipment_categories')
              .child(item.categoryId)
              .child('equipments')
              .push();

      await itemRef.set(item.toMap());

      // Update category counts
      await _updateCategoryCounts(item.categoryId);
    } catch (e) {
      debugPrint('Error adding item: $e');
      rethrow;
    }
  }

  // Update an item
  static Future<void> updateItem(
    String categoryId,
    String itemId,
    Map<String, dynamic> data,
  ) async {
    try {
      data['updatedAt'] = DateTime.now().toIso8601String();
      await _database
          .ref()
          .child('equipment_categories')
          .child(categoryId)
          .child('equipments')
          .child(itemId)
          .update(data);

      // Update category counts if status changed
      if (data.containsKey('status')) {
        await _updateCategoryCounts(categoryId);
      }
    } catch (e) {
      debugPrint('Error updating item: $e');
      rethrow;
    }
  }

  // Delete an item
  static Future<void> deleteItem(String categoryId, String itemId) async {
    try {
      await _database
          .ref()
          .child('equipment_categories')
          .child(categoryId)
          .child('equipments')
          .child(itemId)
          .remove();

      // Update category counts
      await _updateCategoryCounts(categoryId);
    } catch (e) {
      debugPrint('Error deleting item: $e');
      rethrow;
    }
  }

  // Helper method to update category counts
  static Future<void> _updateCategoryCounts(String categoryId) async {
    try {
      final snapshot =
          await _database
              .ref()
              .child('equipment_categories')
              .child(categoryId)
              .child('equipments')
              .get();

      int totalCount = 0;
      int availableCount = 0;

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        for (var itemData in data.values) {
          final item = itemData as Map<dynamic, dynamic>;
          final quantity =
              int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
          final quantityBorrowed =
              int.tryParse(item['quantity_borrowed']?.toString() ?? '0') ?? 0;

          totalCount += quantity;

          if (item['status']?.toString().toLowerCase() == 'available') {
            // Available = total quantity - quantity borrowed
            final available = (quantity - quantityBorrowed).clamp(0, quantity);
            availableCount += available;
          }
        }
      }

      await _database
          .ref()
          .child('equipment_categories')
          .child(categoryId)
          .update({
            'totalCount': totalCount,
            'availableCount': availableCount,
            'updatedAt': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      debugPrint('Error updating category counts: $e');
    }
  }

  // Create a reservation
  static Future<void> createReservation(
    String userId,
    String categoryId,
    String itemId,
    String categoryName,
    String itemName,
  ) async {
    try {
      final reservationRef = _database.ref().child('reservations').push();

      await reservationRef.set({
        'userId': userId,
        'categoryId': categoryId,
        'itemId': itemId,
        'categoryName': categoryName,
        'itemName': itemName,
        'status': 'pending',
        'reservedAt': ServerValue.timestamp,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Update the item status
      await updateItem(categoryId, itemId, {'status': 'Reserved'});
    } catch (e) {
      debugPrint('Error creating reservation: $e');
      rethrow;
    }
  }

  // Search equipment items
  static Future<List<EquipmentItem>> searchItems(String query) async {
    final allItems = await getAllItems();

    if (query.isEmpty) return allItems;

    return allItems.where((item) {
      return item.name.toLowerCase().contains(query.toLowerCase()) ||
          (item.description?.toLowerCase().contains(query.toLowerCase()) ??
              false);
    }).toList();
  }

  // Get items by status
  static Future<List<EquipmentItem>> getItemsByStatus(String status) async {
    final allItems = await getAllItems();

    return allItems.where((item) {
      return item.status.toLowerCase() == status.toLowerCase();
    }).toList();
  }

  // Get categories filtered by labId
  static Future<List<EquipmentCategory>> getCategoriesByLabId(
    String labId,
  ) async {
    final allCategories = await getCategories();

    return allCategories.where((category) {
      return category.labId == labId || category.labRecordId == labId;
    }).toList();
  }

  // Get items filtered by labId
  static Future<List<EquipmentItem>> getItemsByLabId(String labId) async {
    final allItems = await getAllItems();

    return allItems.where((item) {
      return item.labId == labId;
    }).toList();
  }

  // Get categories for a specific lab (by labRecordId)
  static Future<List<EquipmentCategory>> getCategoriesByLabRecordId(
    String labRecordId,
  ) async {
    final allCategories = await getCategories();

    return allCategories.where((category) {
      return category.labRecordId == labRecordId;
    }).toList();
  }

  // Recalculate counts for all categories (one-time fix)
  static Future<void> recalculateAllCategoryCounts() async {
    try {
      final snapshot =
          await _database.ref().child('equipment_categories').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        for (var categoryId in data.keys) {
          await _updateCategoryCounts(categoryId);
          debugPrint('Updated counts for category: $categoryId');
        }

        debugPrint('All category counts recalculated successfully!');
      }
    } catch (e) {
      debugPrint('Error recalculating category counts: $e');
      rethrow;
    }
  }
}
