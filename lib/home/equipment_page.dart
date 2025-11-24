// lib/home/equipment_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:app/home/models/equipment_models.dart';
import 'package:app/home/service/equipment_service.dart';
import 'package:app/home/service/cart_service.dart';
import 'package:app/home/service/laboratory_service.dart';
import 'package:app/home/cart_page.dart';
import 'package:app/home/category_items_page.dart';

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({super.key});

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> {
  bool _isLoading = true;
  String _userRole = '';
  List<EquipmentCategory> _equipmentCategories = [];
  Laboratory? _selectedLaboratory;
  List<EquipmentCategory> _filteredCategories = [];
  final TextEditingController _searchController = TextEditingController();
  final CartService _cartService = CartService();
  final LaboratoryService _laboratoryService = LaboratoryService();

  @override
  void initState() {
    super.initState();
    // Set the correct Firebase database URL
    FirebaseDatabase.instance.databaseURL =
        'https://smartlab-e2107-default-rtdb.asia-southeast1.firebasedatabase.app';
    _loadUserRole();
    _loadLaboratories();
    _loadEquipmentData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot =
          await FirebaseDatabase.instance
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

  Future<void> _loadLaboratories() async {
    try {
      await _laboratoryService.loadLaboratories();
      // Auto-select first lab if available and none selected
      if (_selectedLaboratory == null &&
          _laboratoryService.laboratories.isNotEmpty) {
        setState(() {
          _selectedLaboratory = _laboratoryService.laboratories.first;
        });
        _filterCategoriesByLab();
      }
    } catch (e) {
      debugPrint('Error loading laboratories: $e');
    }
  }

  Future<void> _loadEquipmentData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _equipmentCategories = await EquipmentService.getCategories();
      _filterCategoriesByLab();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load equipment data: $e')),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _filterCategoriesByLab() {
    if (_selectedLaboratory == null) {
      _filteredCategories = _equipmentCategories;
      return;
    }

    // Filter categories by labId or labRecordId
    _filteredCategories = _equipmentCategories.where((category) {
      return category.labId == _selectedLaboratory!.labId ||
          category.labRecordId == _selectedLaboratory!.id ||
          category.labId == _selectedLaboratory!.id;
    }).toList();
  }

  void _onLaboratorySelected(Laboratory? lab) {
    setState(() {
      _selectedLaboratory = lab;
      _filterCategoriesByLab();
    });
  }

  Future<void> _recalculateCounts() async {
    setState(() => _isLoading = true);

    try {
      await EquipmentService.recalculateAllCategoryCounts();
      await _loadEquipmentData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All category counts have been fixed!'),
            backgroundColor: Color(0xFF27AE60),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fixing counts: $e'),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _cartService,
        builder: (context, child) {
          if (_cartService.isEmpty) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartPage()),
              );
            },
            backgroundColor: const Color(0xFF2AA39F),
            icon: Badge(
              label: Text('${_cartService.itemCount}'),
              child: const Icon(Icons.shopping_cart),
            ),
            label: const Text('View Cart'),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Laboratory Equipment',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse and borrow equipment for your experiments',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _recalculateCounts,
              icon: const Icon(Icons.refresh, size: 28),
              color: const Color(0xFF2AA39F),
              tooltip: 'Fix counts',
            ),
            ListenableBuilder(
              listenable: _cartService,
              builder: (context, child) {
                return IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CartPage(),
                      ),
                    );
                  },
                  icon: Badge(
                    label: _cartService.itemCount > 0
                        ? Text('${_cartService.itemCount}')
                        : null,
                    isLabelVisible: _cartService.itemCount > 0,
                    child: const Icon(Icons.shopping_cart_outlined, size: 28),
                  ),
                  color: const Color(0xFF2AA39F),
                  tooltip: 'View Cart',
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Laboratory selector
        if (_laboratoryService.laboratories.isNotEmpty) ...[
          const Text(
            'Select Laboratory',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Laboratory>(
                value: _selectedLaboratory,
                isExpanded: true,
                hint: const Text('All Laboratories'),
                items: [
                  const DropdownMenuItem<Laboratory>(
                    value: null,
                    child: Text('All Laboratories'),
                  ),
                  ..._laboratoryService.laboratories.map((lab) {
                    return DropdownMenuItem<Laboratory>(
                      value: lab,
                      child: Text(lab.labName),
                    );
                  }),
                ],
                onChanged: _onLaboratorySelected,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_equipmentCategories.isEmpty) {
      return _buildEmptyState();
    }

    return _userRole == 'teacher' ? _buildTeacherView() : _buildStudentView();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Equipment Categories',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some equipment categories to get started',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherView() {
    if (_selectedLaboratory == null) {
      return _buildLaboratorySelectionView();
    }

    if (_filteredCategories.isEmpty) {
      return _buildEmptyLabView();
    }

    return RefreshIndicator(
      onRefresh: _loadEquipmentData,
      child: ListView.builder(
        itemCount: _filteredCategories.length,
        itemBuilder: (context, index) {
          final category = _filteredCategories[index];
          return _buildEquipmentCategory(category);
        },
      ),
    );
  }

  Widget _buildStudentView() {
    if (_selectedLaboratory == null) {
      return _buildLaboratorySelectionView();
    }

    if (_filteredCategories.isEmpty) {
      return _buildEmptyLabView();
    }

    return RefreshIndicator(
      onRefresh: _loadEquipmentData,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _filteredCategories.length,
        itemBuilder: (context, index) {
          final category = _filteredCategories[index];
          return _buildEquipmentCategory(category);
        },
      ),
    );
  }

  Widget _buildLaboratorySelectionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.science_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Select a Laboratory',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Please select a laboratory to view available equipment',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLabView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Equipment in ${_selectedLaboratory?.labName ?? "this lab"}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This laboratory has no equipment categories yet',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentCategory(EquipmentCategory category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(category.icon, color: category.color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (category.labName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          category.labName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Available: ${category.availableCount}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Total: ${category.totalCount}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => CategoryItemsPage(category: category),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Items'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AA39F),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
