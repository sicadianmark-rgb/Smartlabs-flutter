// lib/home/form_page.dart
import 'package:app/home/service/form_service.dart';
import 'package:app/home/service/teacher_service.dart';
import 'package:app/home/service/laboratory_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'widgets/form_sections.dart';
import 'widgets/form_widgets.dart';
import 'widgets/signature_pad.dart';

class BorrowFormPage extends StatefulWidget {
  final String itemName;
  final String categoryName;
  final String itemId;
  final String categoryId;

  const BorrowFormPage({
    super.key,
    required this.itemName,
    required this.categoryName,
    required this.itemId,
    required this.categoryId,
  });

  @override
  State<BorrowFormPage> createState() => _BorrowFormPageState();
}

class _BorrowFormPageState extends State<BorrowFormPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _itemNoController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _adviserController = TextEditingController();

  DateTime? _dateToBeUsed;
  DateTime? _dateToReturn;
  Laboratory? _selectedLaboratory;
  bool _isSubmitting = false;
  String _userRole = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TeacherService _teacherService = TeacherService();
  final LaboratoryService _laboratoryService = LaboratoryService();
  final FormService _formService = FormService();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeForm();
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
        });
      }
    } catch (e) {
      debugPrint('Error loading user role: $e');
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  void _initializeForm() {
    _itemNoController.text =
        'LAB-${widget.itemId.substring(0, 5).toUpperCase()}';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _itemNoController.dispose();
    _quantityController.dispose();
    _adviserController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await _formService.selectDate(
      context,
      isStartDate,
      _dateToBeUsed,
      _dateToReturn,
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

  Future<void> _submitBorrowRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dateToBeUsed == null || _dateToReturn == null) {
      FormWidgets.showSnackBar(
        context,
        'Please select both dates',
        isError: true,
      );
      return;
    }

    if (_selectedLaboratory == null) {
      FormWidgets.showSnackBar(
        context,
        'Please select a laboratory',
        isError: true,
      );
      return;
    }

    // Show signature dialog first
    final String? signature = await _showSignatureDialog();

    if (signature == null) {
      // User cancelled or cleared the signature
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _formService.submitBorrowRequest(
        widget: widget,
        itemNo: _itemNoController.text,
        laboratory: _selectedLaboratory!,
        quantity: int.parse(_quantityController.text),
        dateToBeUsed: _dateToBeUsed!,
        dateToReturn: _dateToReturn!,
        adviserName: _adviserController.text,
        signature: signature,
      );

      if (mounted) {
        FormWidgets.showSnackBar(
          context,
          'Borrow request submitted successfully!',
          isError: false,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        FormWidgets.showSnackBar(
          context,
          'Failed to submit request: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: FormWidgets.buildAppBar(context),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Item Information Section
                  ItemInformationSection(
                    itemName: widget.itemName,
                    categoryName: widget.categoryName,
                  ),

                  // Request Details Section
                  ListenableBuilder(
                    listenable: _laboratoryService,
                    builder: (context, child) {
                      return RequestDetailsSection(
                        laboratories: _laboratoryService.laboratories,
                        isLoading: _laboratoryService.isLoading,
                        selectedLaboratory: _selectedLaboratory,
                        onLaboratoryChanged: (lab) {
                          setState(() {
                            _selectedLaboratory = lab;
                          });
                        },
                        quantityController: _quantityController,
                        itemNoController: _itemNoController,
                      );
                    },
                  ),

                  // Schedule Section
                  ScheduleSection(
                    dateToBeUsed: _dateToBeUsed,
                    dateToReturn: _dateToReturn,
                    onDateSelected: _selectDate,
                  ),

                  // Instructor Section (only for students)
                  if (_userRole != 'teacher')
                    ListenableBuilder(
                      listenable: _teacherService,
                      builder: (context, child) {
                        return AdviserSection(
                          teachers: _teacherService.teachers,
                          isLoading: _teacherService.isLoading,
                          adviserController: _adviserController,
                          onAdviserChanged: (value) {
                            setState(() {
                              _adviserController.text = value ?? '';
                            });
                          },
                        );
                      },
                    ),

                  // Submit Button
                  FormWidgets.buildSubmitButton(
                    onPressed: _isSubmitting ? null : _submitBorrowRequest,
                    isSubmitting: _isSubmitting,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
