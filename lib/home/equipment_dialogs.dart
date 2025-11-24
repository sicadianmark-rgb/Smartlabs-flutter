                        // lib/home/equipment_dialogs_updated.dart
import 'package:app/home/models/equipment_models.dart';
import 'package:flutter/material.dart';

class EquipmentDialogs {
  // Add Equipment Category Dialog
  static void showAddEquipmentDialog(
    BuildContext context, {
    required Function(EquipmentCategory) onAdd,
  }) {
    final nameController = TextEditingController();
    final countController = TextEditingController();
    IconData selectedIcon = Icons.science;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Equipment Category'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: countController,
                    decoration: const InputDecoration(
                      labelText: 'Initial Item Count',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<IconData>(
                    decoration: const InputDecoration(
                      labelText: 'Select Icon',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedIcon,
                    items: const [
                      DropdownMenuItem(
                        value: Icons.science,
                        child: Row(
                          children: [
                            Icon(Icons.science),
                            SizedBox(width: 8),
                            Text('Science'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: Icons.biotech,
                        child: Row(
                          children: [
                            Icon(Icons.biotech),
                            SizedBox(width: 8),
                            Text('Biotech'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: Icons.electrical_services,
                        child: Row(
                          children: [
                            Icon(Icons.electrical_services),
                            SizedBox(width: 8),
                            Text('Electronics'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: Icons.straighten,
                        child: Row(
                          children: [
                            Icon(Icons.straighten),
                            SizedBox(width: 8),
                            Text('Measurement'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: Icons.health_and_safety,
                        child: Row(
                          children: [
                            Icon(Icons.health_and_safety),
                            SizedBox(width: 8),
                            Text('Safety'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      selectedIcon = value ?? Icons.science;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isEmpty ||
                      countController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all fields'),
                      ),
                    );
                    return;
                  }

                  final category = EquipmentCategory(
                    id: '', // This will be set by the database
                    title: nameController.text,
                    availableCount: int.tryParse(countController.text) ?? 0,
                    icon: selectedIcon,
                    color: const Color(0xFF2AA39F),
                  );

                  onAdd(category);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2AA39F),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  // Edit Equipment Category Dialog
  static void showEditEquipmentDialog(
    BuildContext context, {
    required EquipmentCategory category,
    required Function(String) onEdit,
  }) {
    final nameController = TextEditingController(text: category.title);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Equipment Category'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a name')),
                    );
                    return;
                  }
                  onEdit(nameController.text);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2AA39F),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  // Add Item Dialog with Description and Quantity
  static void showAddItemDialog(
    BuildContext context, {
    required String categoryName,
    required String categoryId,
    required Function(EquipmentItem) onAdd,
  }) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final statusController = TextEditingController(text: 'Available');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add Item to $categoryName'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      hintText: 'Enter item description (optional)',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Quantity *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          value: statusController.text,
                          items: const [
                            DropdownMenuItem(
                              value: 'Available',
                              child: Text('Available'),
                            ),
                            DropdownMenuItem(
                              value: 'In Use',
                              child: Text('In Use'),
                            ),
                            DropdownMenuItem(
                              value: 'Maintenance',
                              child: Text('Maintenance'),
                            ),
                            DropdownMenuItem(
                              value: 'Reserved',
                              child: Text('Reserved'),
                            ),
                          ],
                          onChanged: (value) {
                            statusController.text = value ?? 'Available';
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isEmpty ||
                      quantityController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in required fields'),
                      ),
                    );
                    return;
                  }

                  final item = EquipmentItem(
                    id: '', // This will be set by the database
                    name: nameController.text,
                    status: statusController.text,
                    categoryId: categoryId,
                    description:
                        descriptionController.text.isEmpty
                            ? null
                            : descriptionController.text,
                    quantity: quantityController.text,
                  );

                  onAdd(item);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2AA39F),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  // Edit Item Dialog with Description and Quantity
  static void showEditItemDialog(
    BuildContext context, {
    required EquipmentItem item,
    required Function(String, String, String, String)
    onEdit, // name, status, description, quantity
  }) {
    final nameController = TextEditingController(text: item.name);
    final descriptionController = TextEditingController(
      text: item.description ?? '',
    );
    final quantityController = TextEditingController(text: item.quantity);
    String selectedStatus = item.status;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Edit Equipment Item'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Item Name *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            hintText: 'Enter item description (optional)',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: quantityController,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity *',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  border: OutlineInputBorder(),
                                ),
                                value: selectedStatus,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Available',
                                    child: Text('Available'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'In Use',
                                    child: Text('In Use'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Maintenance',
                                    child: Text('Maintenance'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Reserved',
                                    child: Text('Reserved'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    selectedStatus = value ?? 'Available';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isEmpty ||
                            quantityController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill in required fields'),
                            ),
                          );
                          return;
                        }
                        onEdit(
                          nameController.text,
                          selectedStatus,
                          descriptionController.text,
                          quantityController.text,
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2AA39F),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  // Delete Item Confirmation Dialog
  static void showDeleteItemConfirmation(
    BuildContext context, {
    required String itemName,
    required Function() onDelete,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Item'),
            content: Text('Are you sure you want to delete $itemName?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  onDelete();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
