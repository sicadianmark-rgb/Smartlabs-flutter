// lib/home/service/laboratory_service.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class Laboratory {
  final String id; // Firebase record ID (key)
  final String labId; // Lab code (e.g., "LAB001")
  final String labName; // Lab display name
  final String? description;
  final String? location;

  Laboratory({
    required this.id,
    required this.labId,
    required this.labName,
    this.description,
    this.location,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'labId': labId,
      'labName': labName,
      'description': description,
      'location': location,
    };
  }

  factory Laboratory.fromMap(String recordId, Map<dynamic, dynamic> data) {
    return Laboratory(
      id: recordId,
      labId: data['labId'] ?? data['id'] ?? '',
      labName: data['labName'] ?? data['name'] ?? '',
      description: data['description'],
      location: data['location'],
    );
  }
}

class LaboratoryService extends ChangeNotifier {
  static final LaboratoryService _instance = LaboratoryService._internal();
  factory LaboratoryService() => _instance;
  LaboratoryService._internal();

  List<Laboratory> _laboratories = [];
  bool _isLoading = false;
  String? _error;

  List<Laboratory> get laboratories => List.unmodifiable(_laboratories);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  Future<void> loadLaboratories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final DatabaseReference labsRef =
          FirebaseDatabase.instance.ref().child('laboratories');
      final DatabaseEvent event = await labsRef.once();

      List<Laboratory> labs = [];

      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> labsData =
            event.snapshot.value as Map<dynamic, dynamic>;

        labsData.forEach((recordId, labData) {
          if (labData is Map) {
            try {
              final lab = Laboratory.fromMap(recordId.toString(), labData);
              labs.add(lab);
            } catch (e) {
              debugPrint('Error parsing laboratory $recordId: $e');
            }
          }
        });

        // Sort laboratories by labName
        labs.sort(
          (a, b) => a.labName.compareTo(b.labName),
        );
      }

      // If no laboratories found in database, use fallback default labs
      if (labs.isEmpty) {
        debugPrint(
          'No laboratories found in database. Using default laboratories.',
        );
        labs = _getDefaultLaboratories();
      }

      _laboratories = labs;
    } catch (e) {
      _error = 'Failed to load laboratories: $e';
      debugPrint('Error loading laboratories: $e');

      // Use default labs as fallback on error
      _laboratories = _getDefaultLaboratories();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fallback default laboratories if database is empty or inaccessible
  List<Laboratory> _getDefaultLaboratories() {
    return [
      Laboratory(
        id: 'default-1',
        labId: 'LAB001',
        labName: 'Laboratory 1',
      ),
      Laboratory(
        id: 'default-2',
        labId: 'LAB002',
        labName: 'Laboratory 2',
      ),
      Laboratory(
        id: 'default-3',
        labId: 'LAB003',
        labName: 'Laboratory 3',
      ),
      Laboratory(
        id: 'default-4',
        labId: 'LAB004',
        labName: 'Laboratory 4',
      ),
      Laboratory(
        id: 'default-5',
        labId: 'LAB005',
        labName: 'Laboratory 5',
      ),
    ];
  }

  Laboratory? getLaboratoryById(String labId) {
    try {
      return _laboratories.firstWhere(
        (lab) => lab.labId == labId || lab.id == labId,
      );
    } catch (e) {
      return null;
    }
  }

  Laboratory? getLaboratoryByName(String labName) {
    try {
      return _laboratories.firstWhere(
        (lab) => lab.labName == labName,
      );
    } catch (e) {
      return null;
    }
  }

  void clearLaboratories() {
    _laboratories.clear();
    _error = null;
    notifyListeners();
  }
}

