import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:app/home/service/cart_service.dart';
import 'package:app/home/service/teacher_service.dart';
import 'package:app/home/service/laboratory_service.dart';
import 'package:app/home/service/notification_service.dart';
import 'package:app/home/service/borrow_history_service.dart';
import 'package:app/home/widgets/signature_pad.dart';
import 'package:intl/intl.dart';

class BatchBorrowFormPage extends StatefulWidget {
  const BatchBorrowFormPage({super.key});

  @override
  State<BatchBorrowFormPage> createState() => _BatchBorrowFormPageState();
}

class _BatchBorrowFormPageState extends State<BatchBorrowFormPage> {
  final _formKey = GlobalKey<FormState>();
  final CartService _cartService = CartService();
  final TeacherService _teacherService = TeacherService();
  final LaboratoryService _laboratoryService = LaboratoryService();

  DateTime? _dateToBeUsed;
  DateTime? _dateToReturn;
  Laboratory? _selectedLaboratory;
  String _adviserName = '';
  String _adviserId = '';
  bool _isSubmitting = false;
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _teacherService.loadTeachers();
    _laboratoryService.loadLaboratories().then((_) {
      // Set default laboratory to first available lab
      if (_laboratoryService.laboratories.isNotEmpty &&
          _selectedLaboratory == null) {
        if (mounted) {
          setState(() {
            _selectedLaboratory = _laboratoryService.laboratories.first;
          });
        }
      }
    });
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(user.uid)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _userRole = data['role'] ?? '';
          // For teachers, set themselves as adviser
          if (_userRole == 'teacher') {
            _adviserId = user.uid;
            _adviserName = data['name'] ?? user.email ?? 'Instructor';
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading user role: $e');
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          isStartDate
              ? (_dateToBeUsed ?? DateTime.now())
              : (_dateToReturn ?? DateTime.now().add(const Duration(days: 1))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _dateToBeUsed = picked;
          if (_dateToReturn != null && _dateToReturn!.isBefore(picked)) {
            _dateToReturn = null;
          }
        } else {
          _dateToReturn = picked;
        }
      });
    }
  }

  Future<void> _submitBatchRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dateToBeUsed == null || _dateToReturn == null) {
      _showSnackBar('Please select both dates', isError: true);
      return;
    }

    // For students, adviser is required; for teachers, they are auto-assigned
    if (_userRole != 'teacher' && (_adviserName.isEmpty || _adviserId.isEmpty)) {
      _showSnackBar('Please select an instructor', isError: true);
      return;
    }

    if (_selectedLaboratory == null) {
      _showSnackBar('Please select a laboratory', isError: true);
      return;
    }

    // For teachers, ensure they are set as their own adviser
    if (_userRole == 'teacher') {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _adviserId = user.uid;
        // Get user name if not already set
        if (_adviserName.isEmpty) {
          try {
            final snapshot = await FirebaseDatabase.instance
                .ref()
                .child('users')
                .child(user.uid)
                .get();
            if (snapshot.exists) {
              final data = snapshot.value as Map<dynamic, dynamic>;
              _adviserName = data['name'] ?? user.email ?? 'Instructor';
            }
          } catch (e) {
            _adviserName = user.email ?? 'Instructor';
          }
        }
      }
    }

    // Show signature dialog first
    final String? signature = await _showSignatureDialog();

    if (signature == null) {
      // User cancelled or cleared the signature
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if user is a teacher (auto-approve)
      final isTeacher = _userRole == 'teacher';
      
      // Create a batch request ID (shared by all items in this batch)
      final batchId =
          FirebaseDatabase.instance.ref().child('batch_requests').push().key!;
      
      // Calculate batch size (total number of items in batch)
      final batchSize = _cartService.items.length;

      final List<Future> requests = [];

      // Create individual requests for each cart item
      // All items share the same batchId to group them together
      for (var item in _cartService.items) {
        // Set status: 'approved' for teachers, 'pending' for students
        final status = isTeacher ? 'approved' : 'pending';
        
        final borrowRequestData = <String, dynamic>{
          'batchId': batchId, // Same batchId for all items in this batch
          'batchSize': batchSize, // Total number of items in this batch
          'userId': user.uid,
          'userEmail': user.email,
          'itemId': item.itemId,
          'categoryId': item.categoryId,
          'itemName': item.itemName,
          'categoryName': item.categoryName,
          'itemNo': 'LAB-${item.itemId.substring(0, 5).toUpperCase()}',
          'laboratory': _selectedLaboratory!.labName, // Display name for backward compatibility
          'labId': _selectedLaboratory!.labId, // Lab code (e.g., "LAB001")
          'labRecordId': _selectedLaboratory!.id, // Firebase record ID
          'quantity': item.quantity,
          'dateToBeUsed': _dateToBeUsed!.toIso8601String(),
          'dateToReturn': _dateToReturn!.toIso8601String(),
          'adviserName': _adviserName,
          'adviserId': _adviserId,
          'status': status,
          'requestedAt': DateTime.now().toIso8601String(),
          'signature': signature, // E-Signature for batch request
          if (isTeacher) 'processedAt': DateTime.now().toIso8601String(),
          if (isTeacher) 'processedBy': user.uid,
        };

        final borrowRef =
            FirebaseDatabase.instance.ref().child('borrow_requests').push();
        final requestId = borrowRef.key!;

        borrowRequestData['requestId'] = requestId;

        requests.add(borrowRef.set(borrowRequestData));

        // For teachers: Auto-approve - update equipment quantity_borrowed immediately
        if (isTeacher) {
          requests.add(_updateEquipmentQuantityBorrowed(
            item.itemId,
            item.categoryId,
            item.quantity,
            increment: true,
          ));

          // Archive to history storage for association rule mining
          // Only batch requests (with batchId) are archived
          requests.add(
            BorrowHistoryService.archiveApprovedRequest(
              requestId,
              borrowRequestData,
            ),
          );
        }
      }

      if (isTeacher) {
        // For teachers: Send approval confirmation
        requests.add(
          NotificationService.sendNotificationToUser(
            userId: user.uid,
            title: 'Batch Request Approved',
            message:
                'Your request for ${_cartService.itemCount} items has been automatically approved.',
            type: 'success',
            additionalData: {
              'batchId': batchId,
              'itemCount': _cartService.itemCount,
              'status': 'approved',
            },
          ),
        );
      } else {
        // For students: Send notification to instructor about the batch request
        requests.add(
          NotificationService.sendNotificationToUser(
            userId: _adviserId,
            title: 'New Batch Borrow Request',
            message:
                '${user.email} has requested to borrow ${_cartService.itemCount} items',
            type: 'info',
            additionalData: {
              'batchId': batchId,
              'itemCount': _cartService.itemCount,
              'studentEmail': user.email,
              'requestedAt': DateTime.now().toIso8601String(),
            },
          ),
        );

        // Send confirmation to student
        requests.add(
          NotificationService.sendNotificationToUser(
            userId: user.uid,
            title: 'Batch Request Submitted',
            message:
                'Your request for ${_cartService.itemCount} items has been submitted and is pending approval',
            type: 'success',
            additionalData: {
              'batchId': batchId,
              'itemCount': _cartService.itemCount,
            },
          ),
        );
      }

      await Future.wait(requests);

      // Clear the cart after successful submission
      _cartService.clear();

      if (mounted) {
        _showSnackBar('Batch request submitted successfully!', isError: false);
        Navigator.pop(context, true); // Return to cart page
        Navigator.pop(context, true); // Return to equipment page
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to submit request: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<String?> _showSignatureDialog() async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => SignaturePad(
            onSignatureComplete: (signature) {
              Navigator.pop(context, signature);
            },
          ),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFE74C3C) : const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Batch Borrow Request'),
        backgroundColor: const Color(0xFF2AA39F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Items Summary
              _buildItemsSummary(),
              const SizedBox(height: 24),

              // Laboratory Selection
              _buildLaboratorySection(),
              const SizedBox(height: 24),

              // Schedule Section
              _buildScheduleSection(),
              const SizedBox(height: 24),

              // Instructor Section (only for students)
              if (_userRole != 'teacher')
                _buildAdviserSection(),
              if (_userRole != 'teacher')
                const SizedBox(height: 24),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitBatchRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AA39F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'Proceed to Check Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart, color: Color(0xFF2AA39F)),
              const SizedBox(width: 8),
              Text(
                'Items to Borrow (${_cartService.itemCount})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cartService.items.length,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final item = _cartService.items[index];
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.itemName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          item.categoryName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2AA39F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Qty: ${item.quantity}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2AA39F),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLaboratorySection() {
    return ListenableBuilder(
      listenable: _laboratoryService,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Laboratory',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _laboratoryService.isLoading
                  ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                  : _laboratoryService.laboratories.isEmpty
                      ? const Text('No laboratories available')
                      : DropdownButtonFormField<Laboratory>(
                        value: _selectedLaboratory,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          prefixIcon: const Icon(
                            Icons.science_outlined,
                            color: Color(0xFF2AA39F),
                          ),
                        ),
                        items: _laboratoryService.laboratories.map((lab) {
                          return DropdownMenuItem<Laboratory>(
                            value: lab,
                            child: Text(lab.labName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedLaboratory = value);
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a laboratory';
                          }
                          return null;
                        },
                        isExpanded: true,
                        menuMaxHeight: 300,
                      ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScheduleSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Schedule',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _selectDate(context, true),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date to be Used',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              child: Text(
                _dateToBeUsed != null
                    ? DateFormat('MMM dd, yyyy').format(_dateToBeUsed!)
                    : 'Select date',
                style: TextStyle(
                  color: _dateToBeUsed != null ? Colors.black : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _selectDate(context, false),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date to Return',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              child: Text(
                _dateToReturn != null
                    ? DateFormat('MMM dd, yyyy').format(_dateToReturn!)
                    : 'Select date',
                style: TextStyle(
                  color: _dateToReturn != null ? Colors.black : Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviserSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Instructor',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: _teacherService,
            builder: (context, child) {
              if (_teacherService.isLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (_teacherService.teachers.isEmpty) {
                return const Text('No teachers available');
              }

              return DropdownButtonFormField<String>(
                value: _adviserName.isEmpty ? null : _adviserName,
                decoration: InputDecoration(
                  hintText: 'Choose your instructor',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items:
                    _teacherService.teachers.map((teacher) {
                      return DropdownMenuItem<String>(
                        value: teacher['name'],
                        child: Text(teacher['name']),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _adviserName = value!;
                    final teacher = _teacherService.teachers.firstWhere(
                      (t) => t['name'] == value,
                    );
                    _adviserId = teacher['id'];
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select an instructor';
                  }
                  return null;
                },
              );
            },
          ),
        ],
      ),
    );
  }

  /// Update equipment quantity_borrowed when request is approved
  Future<void> _updateEquipmentQuantityBorrowed(
    String itemId,
    String categoryId,
    int quantity, {
    required bool increment,
  }) async {
    try {
      // Get current equipment item
      final itemSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('equipment_categories')
          .child(categoryId)
          .child('equipments')
          .child(itemId)
          .get();

      if (itemSnapshot.exists) {
        final itemData = itemSnapshot.value as Map<dynamic, dynamic>;
        final currentBorrowed =
            int.tryParse(itemData['quantity_borrowed']?.toString() ?? '0') ?? 0;

        final newBorrowed = increment
            ? currentBorrowed + quantity
            : (currentBorrowed - quantity).clamp(0, double.infinity).toInt();

        // Update quantity_borrowed
        await FirebaseDatabase.instance
            .ref()
            .child('equipment_categories')
            .child(categoryId)
            .child('equipments')
            .child(itemId)
            .update({
              'quantity_borrowed': newBorrowed,
              'updatedAt': DateTime.now().toIso8601String(),
            });

        // Update category counts
        await _updateCategoryCounts(categoryId);
      }
    } catch (e) {
      debugPrint('Error updating equipment quantity_borrowed: $e');
    }
  }

  /// Update category counts after equipment quantity change
  Future<void> _updateCategoryCounts(String categoryId) async {
    try {
      final snapshot = await FirebaseDatabase.instance
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
            final available = (quantity - quantityBorrowed).clamp(0, quantity);
            availableCount += available;
          }
        }
      }

      await FirebaseDatabase.instance
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
}
