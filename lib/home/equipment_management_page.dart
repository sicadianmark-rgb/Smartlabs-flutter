import 'package:flutter/material.dart';
import 'package:app/home/models/equipment_models.dart';
import 'package:app/home/service/equipment_service.dart';

class EquipmentManagementPage extends StatefulWidget {
  const EquipmentManagementPage({super.key});

  @override
  State<EquipmentManagementPage> createState() =>
      _EquipmentManagementPageState();
}

class _EquipmentManagementPageState extends State<EquipmentManagementPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<EquipmentCategory> _equipmentCategories = [];
  List<EquipmentItem> _allItems = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEquipmentData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEquipmentData() async {
    setState(() => _isLoading = true);

    try {
      final categories = await EquipmentService.getCategories();
      final items = await EquipmentService.getAllItems();

      setState(() {
        _equipmentCategories = categories;
        _allItems = items;
        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar('Error loading equipment data: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _recalculateCounts() async {
    setState(() => _isLoading = true);

    try {
      await EquipmentService.recalculateAllCategoryCounts();
      await _loadEquipmentData();
      _showSnackBar(
        'All category counts have been recalculated!',
        isError: false,
      );
    } catch (e) {
      _showSnackBar('Error recalculating counts: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addCategory() async {
    final nameController = TextEditingController();
    String selectedIcon = 'science';
    Color selectedColor = const Color(0xFF2AA39F);

    await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Add Equipment Category'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Category Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Select Icon:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children:
                              [
                                'science',
                                'biotech',
                                'electrical_services',
                                'straighten',
                                'health_and_safety',
                              ].map((iconName) {
                                final icon =
                                    EquipmentCategory.getIconFromString(
                                      iconName,
                                    );
                                final isSelected = selectedIcon == iconName;
                                return GestureDetector(
                                  onTap:
                                      () => setState(
                                        () => selectedIcon = iconName,
                                      ),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? selectedColor.withValues(
                                                alpha: 0.2,
                                              )
                                              : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? selectedColor
                                                : Colors.grey.shade300,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      icon,
                                      color:
                                          isSelected
                                              ? selectedColor
                                              : Colors.grey,
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Select Color:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children:
                              [
                                const Color(0xFF2AA39F),
                                const Color(0xFF52B788),
                                const Color(0xFF3498DB),
                                const Color(0xFFE74C3C),
                                const Color(0xFFF39C12),
                                const Color(0xFF9B59B6),
                              ].map((color) {
                                final isSelected = selectedColor == color;
                                return GestureDetector(
                                  onTap:
                                      () =>
                                          setState(() => selectedColor = color),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? Colors.black
                                                : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                    child:
                                        isSelected
                                            ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 20,
                                            )
                                            : null,
                                  ),
                                );
                              }).toList(),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);

                        if (nameController.text.trim().isEmpty) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a category name'),
                            ),
                          );
                          return;
                        }

                        final category = EquipmentCategory(
                          id: '',
                          title: nameController.text.trim(),
                          availableCount: 0,
                          icon: EquipmentCategory.getIconFromString(
                            selectedIcon,
                          ),
                          color: selectedColor,
                        );

                        try {
                          await EquipmentService.addCategory(category);
                          navigator.pop(true);
                          _loadEquipmentData();
                          _showSnackBar(
                            'Category added successfully!',
                            isError: false,
                          );
                        } catch (e) {
                          _showSnackBar(
                            'Error adding category: $e',
                            isError: true,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2AA39F),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _addItem(String categoryId) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    String selectedStatus = 'Available';

    await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Add Equipment Item'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Item Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              ['Available', 'Maintenance', 'In Use', 'Reserved']
                                  .map(
                                    (status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (value) =>
                                  setState(() => selectedStatus = value!),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);

                        if (nameController.text.trim().isEmpty) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Please enter an item name'),
                            ),
                          );
                          return;
                        }

                        final item = EquipmentItem(
                          id: '',
                          name: nameController.text.trim(),
                          status: selectedStatus,
                          categoryId: categoryId,
                          description:
                              descriptionController.text.trim().isEmpty
                                  ? null
                                  : descriptionController.text.trim(),
                          quantity: quantityController.text.trim(),
                        );

                        try {
                          await EquipmentService.addItem(item);
                          navigator.pop(true);
                          _loadEquipmentData();
                          _showSnackBar(
                            'Item added successfully!',
                            isError: false,
                          );
                        } catch (e) {
                          _showSnackBar('Error adding item: $e', isError: true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2AA39F),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _deleteCategory(String categoryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Category'),
            content: const Text(
              'Are you sure you want to delete this category? This will also delete all items in this category.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await EquipmentService.deleteCategory(categoryId);
        _loadEquipmentData();
        _showSnackBar('Category deleted successfully!', isError: false);
      } catch (e) {
        _showSnackBar('Error deleting category: $e', isError: true);
      }
    }
  }

  Future<void> _deleteItem(String categoryId, String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Item'),
            content: const Text('Are you sure you want to delete this item?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await EquipmentService.deleteItem(categoryId, itemId);
        _loadEquipmentData();
        _showSnackBar('Item deleted successfully!', isError: false);
      } catch (e) {
        _showSnackBar('Error deleting item: $e', isError: true);
      }
    }
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
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2AA39F),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF2AA39F),
              tabs: const [
                Tab(
                  child: Text(
                    'Categories',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Tab(
                  child: Text(
                    'All Items',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.settings, color: Color(0xFF2AA39F), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Equipment Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.calculate, color: Color(0xFF2AA39F)),
                    onPressed: _recalculateCounts,
                    tooltip: 'Fix counts',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF2AA39F)),
                    onPressed: _loadEquipmentData,
                    tooltip: 'Refresh data',
                  ),
                ),
              ],
            ),
          ),
          _isLoading
              ? const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF2AA39F)),
                      SizedBox(height: 16),
                      Text(
                        'Loading equipment data...',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
              : Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildCategoriesList(), _buildItemsList()],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _equipmentCategories.length + 1, // +1 for add button
      itemBuilder: (context, index) {
        if (index == _equipmentCategories.length) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: const Icon(Icons.add, color: Color(0xFF2AA39F)),
              title: const Text(
                'Add New Category',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2AA39F),
                ),
              ),
              onTap: _addCategory,
            ),
          );
        }

        final category = _equipmentCategories[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(category.icon, color: category.color, size: 24),
            ),
            title: Text(
              category.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${category.totalCount} items • ${category.availableCount} available',
            ),
            trailing: PopupMenuButton(
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'add_item',
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 20),
                          SizedBox(width: 8),
                          Text('Add Item'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Delete Category',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
              onSelected: (value) {
                switch (value) {
                  case 'add_item':
                    _addItem(category.id);
                    break;
                  case 'delete':
                    _deleteCategory(category.id);
                    break;
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allItems.length,
      itemBuilder: (context, index) {
        final item = _allItems[index];
        final category = _equipmentCategories.firstWhere(
          (cat) => cat.id == item.categoryId,
          orElse:
              () => EquipmentCategory(
                id: '',
                title: 'Unknown',
                color: Colors.grey,
                icon: Icons.help_outline,
                availableCount: 0,
              ),
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(category.icon, color: category.color, size: 20),
            ),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${category.title} • Qty: ${item.quantity}'),
                if (item.description != null && item.description!.isNotEmpty)
                  Text(
                    item.description!,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: item.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.status,
                    style: TextStyle(
                      color: item.statusColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton(
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Delete Item',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteItem(item.categoryId, item.id);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
