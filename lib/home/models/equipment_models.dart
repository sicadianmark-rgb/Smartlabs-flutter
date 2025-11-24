// lib/models/equipment_models.dart
import 'package:flutter/material.dart';

class EquipmentCategory {
  final String id;
  final String title;
  final int availableCount;
  final IconData icon;
  final Color color;
  final String? createdAt;
  final int totalCount; // Total number of equipment items
  final String? updatedAt;
  final String? labId; // Lab code (e.g., "LAB001")
  final String? labRecordId; // Firebase record ID of the laboratory
  final String? labName; // Laboratory display name

  EquipmentCategory({
    required this.id,
    required this.title,
    required this.availableCount,
    required this.icon,
    required this.color,
    this.createdAt,
    this.totalCount = 0,
    this.updatedAt,
    this.labId,
    this.labRecordId,
    this.labName,
  });

  static IconData getIconFromString(String iconName) {
    switch (iconName) {
      case 'science':
        return Icons.science;
      case 'biotech':
        return Icons.biotech;
      case 'electrical_services':
        return Icons.electrical_services;
      case 'straighten':
        return Icons.straighten;
      case 'health_and_safety':
        return Icons.health_and_safety;
      default:
        return Icons.science;
    }
  }

  static String getIconString(IconData icon) {
    if (icon == Icons.science) return 'science';
    if (icon == Icons.biotech) return 'biotech';
    if (icon == Icons.electrical_services) return 'electrical_services';
    if (icon == Icons.straighten) return 'straighten';
    if (icon == Icons.health_and_safety) return 'health_and_safety';
    return 'science';
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'availableCount': availableCount,
      'icon': getIconString(icon),
      'colorHex': color.toARGB32().toRadixString(16).substring(2),
      'totalCount': totalCount,
      'createdAt': createdAt ?? DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory EquipmentCategory.fromMap(String id, Map<dynamic, dynamic> data) {
    Color categoryColor = const Color(0xFF2AA39F);
    if (data['colorHex'] != null) {
      try {
        categoryColor = Color(
          int.parse(data['colorHex'], radix: 16) + 0xFF000000,
        );
      } catch (e) {
        debugPrint('Error parsing color: $e');
      }
    }

    return EquipmentCategory(
      id: id,
      title: data['title'] ?? 'Unknown',
      availableCount: data['availableCount'] ?? 0,
      totalCount: data['totalCount'] ?? 0,
      icon: getIconFromString(data['icon'] ?? 'science'),
      color: categoryColor,
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
      labId: data['labId'],
      labRecordId: data['labRecordId'],
      labName: data['labName'],
    );
  }
}

class EquipmentItem {
  final String id;
  final String name;
  final String status;
  final String categoryId;
  final String? description;
  final String quantity;
  final int? quantityBorrowed; // Number of items currently borrowed
  final String? createdAt;
  final String? updatedAt;
  final String? model;
  final String? serialNumber;
  final String? condition;
  final String? location;
  final String? labId;
  final String? assignedTo;
  final String? imageUrl;

  EquipmentItem({
    required this.id,
    required this.name,
    required this.status,
    required this.categoryId,
    this.description,
    this.quantity = '1',
    this.quantityBorrowed,
    this.createdAt,
    this.updatedAt,
    this.model,
    this.serialNumber,
    this.condition,
    this.location,
    this.labId,
    this.assignedTo,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'status': status,
      'categoryId': categoryId,
      'description': description ?? '',
      'quantity': quantity,
      'quantity_borrowed': quantityBorrowed ?? 0,
      'model': model ?? '',
      'serialNumber': serialNumber ?? '',
      'condition': condition ?? '',
      'location': location ?? '',
      'labId': labId ?? '',
      'assignedTo': assignedTo ?? '',
      'imageUrl': imageUrl ?? '',
      'createdAt': createdAt ?? DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory EquipmentItem.fromMap(String id, Map<dynamic, dynamic> data) {
    // Parse quantity_borrowed (can be int, string, or null)
    int? quantityBorrowed;
    if (data['quantity_borrowed'] != null) {
      if (data['quantity_borrowed'] is int) {
        quantityBorrowed = data['quantity_borrowed'] as int;
      } else if (data['quantity_borrowed'] is String) {
        quantityBorrowed = int.tryParse(data['quantity_borrowed']);
      }
    }

    return EquipmentItem(
      id: id,
      name: data['name'] ?? 'Unknown Item',
      status: data['status'] ?? 'Available',
      categoryId: data['categoryId'] ?? '',
      description: data['description'],
      quantity: data['quantity']?.toString() ?? '1',
      quantityBorrowed: quantityBorrowed,
      model: data['model'],
      serialNumber: data['serialNumber'],
      condition: data['condition'],
      location: data['location'],
      labId: data['labId'],
      assignedTo: data['assignedTo'],
      imageUrl: data['imageUrl'],
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  bool get isAvailable => status.toLowerCase() == 'available';

  // Get available quantity (total quantity - quantity borrowed)
  int get availableQuantity {
    final totalQty = int.tryParse(quantity) ?? 0;
    final borrowed = quantityBorrowed ?? 0;
    return (totalQty - borrowed).clamp(0, totalQty);
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'reserved':
        return Colors.orange;
      case 'in use':
        return Colors.blue;
      case 'maintenance':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
