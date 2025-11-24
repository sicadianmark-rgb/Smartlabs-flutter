// lib/home/widgets/form_sections.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app/home/service/laboratory_service.dart';
import 'form_widgets.dart';

class ItemInformationSection extends StatelessWidget {
  final String itemName;
  final String categoryName;

  const ItemInformationSection({
    super.key,
    required this.itemName,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return FormWidgets.buildSectionCard(
      title: 'Item Information',
      children: [
        FormWidgets.buildFormField(
          label: 'Item Name',
          isRequired: false,
          child: TextFormField(
            initialValue: itemName,
            enabled: false,
            decoration: FormWidgets.getInputDecoration().copyWith(
              fillColor: Colors.grey[100],
              prefixIcon: const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF6C63FF),
              ),
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FormWidgets.buildFormField(
          label: 'Category',
          isRequired: false,
          child: TextFormField(
            initialValue: categoryName,
            enabled: false,
            decoration: FormWidgets.getInputDecoration().copyWith(
              fillColor: Colors.grey[100],
              prefixIcon: const Icon(
                Icons.category_outlined,
                color: Color(0xFF6C63FF),
              ),
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
      ],
    );
  }
}

class RequestDetailsSection extends StatelessWidget {
  final List<Laboratory> laboratories;
  final bool isLoading;
  final Laboratory? selectedLaboratory;
  final Function(Laboratory?) onLaboratoryChanged;
  final TextEditingController quantityController;
  final TextEditingController itemNoController;

  const RequestDetailsSection({
    super.key,
    required this.laboratories,
    required this.isLoading,
    required this.selectedLaboratory,
    required this.onLaboratoryChanged,
    required this.quantityController,
    required this.itemNoController,
  });

  @override
  Widget build(BuildContext context) {
    return FormWidgets.buildSectionCard(
      title: 'Request Details',
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: FormWidgets.buildFormField(
                label: 'Laboratory',
                child: isLoading
                    ? _buildLoadingState()
                    : _buildLaboratoryDropdown(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FormWidgets.buildFormField(
                label: 'Quantity',
                child: TextFormField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: FormWidgets.getInputDecoration(
                    hintText: '1',
                  ).copyWith(
                    prefixIcon: const Icon(
                      Icons.numbers,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (int.tryParse(value) == null || int.parse(value) < 1) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FormWidgets.buildFormField(
          label: 'Item Number',
          child: TextFormField(
            controller: itemNoController,
            decoration: FormWidgets.getInputDecoration(
              hintText: 'Enter item number',
            ).copyWith(
              prefixIcon: const Icon(Icons.qr_code, color: Color(0xFF6C63FF)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter item number';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, color: Color(0xFF6C63FF)),
          SizedBox(width: 12),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF6C63FF),
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Loading laboratories...',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLaboratoryDropdown() {
    if (laboratories.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.science_outlined, color: Color(0xFF6C63FF)),
            SizedBox(width: 12),
            Text(
              'No laboratories available',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<Laboratory>(
      value: selectedLaboratory,
      decoration: FormWidgets.getInputDecoration(
        hintText: 'Select laboratory',
      ).copyWith(
        prefixIcon: const Icon(
          Icons.science_outlined,
          color: Color(0xFF6C63FF),
        ),
      ),
      items: laboratories.map((lab) {
        return DropdownMenuItem<Laboratory>(
          value: lab,
          child: Text(lab.labName),
        );
      }).toList(),
      onChanged: onLaboratoryChanged,
      validator: (value) {
        if (value == null) {
          return 'Please select a laboratory';
        }
        return null;
      },
      isExpanded: true,
      menuMaxHeight: 300,
    );
  }
}

class ScheduleSection extends StatelessWidget {
  final DateTime? dateToBeUsed;
  final DateTime? dateToReturn;
  final Function(BuildContext, bool) onDateSelected;

  const ScheduleSection({
    super.key,
    required this.dateToBeUsed,
    required this.dateToReturn,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FormWidgets.buildSectionCard(
      title: 'Schedule',
      children: [
        Row(
          children: [
            Expanded(
              child: FormWidgets.buildFormField(
                label: 'Date to be Used',
                child: _buildDateSelector(
                  context,
                  dateToBeUsed,
                  'Select date',
                  Icons.calendar_today_outlined,
                  () => onDateSelected(context, true),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FormWidgets.buildFormField(
                label: 'Date to Return',
                child: _buildDateSelector(
                  context,
                  dateToReturn,
                  'Select date',
                  Icons.event_available_outlined,
                  () => onDateSelected(context, false),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateSelector(
    BuildContext context,
    DateTime? selectedDate,
    String placeholder,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6C63FF), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedDate != null
                    ? DateFormat('MMM dd, yyyy').format(selectedDate)
                    : placeholder,
                style: TextStyle(
                  fontSize: 16,
                  color:
                      selectedDate != null
                          ? const Color(0xFF2C3E50)
                          : Colors.grey[400],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdviserSection extends StatelessWidget {
  final List<Map<String, dynamic>> teachers;
  final bool isLoading;
  final TextEditingController adviserController;
  final Function(String?) onAdviserChanged;

  const AdviserSection({
    super.key,
    required this.teachers,
    required this.isLoading,
    required this.adviserController,
    required this.onAdviserChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormWidgets.buildSectionCard(
      title: 'Supervision',
      children: [
        FormWidgets.buildFormField(
          label: 'Name of the Instructor',
          child: isLoading ? _buildLoadingState() : _buildDropdown(),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.person_outline, color: Color(0xFF6C63FF)),
          SizedBox(width: 12),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF6C63FF),
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Loading teachers...',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: adviserController.text.isEmpty ? null : adviserController.text,
      decoration: FormWidgets.getInputDecoration(
        hintText: teachers.isEmpty ? 'No teachers available' : 'Select instructor',
      ).copyWith(
        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF6C63FF)),
      ),
      items:
          teachers.map((teacher) {
            return DropdownMenuItem<String>(
              value: teacher['name'],
              child: Text(
                teacher['name'],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
      onChanged: teachers.isEmpty ? null : onAdviserChanged,
      validator: (value) {
        if (adviserController.text.isEmpty) {
          return 'Please select an instructor';
        }
        return null;
      },
      isExpanded: true,
      menuMaxHeight: 300,
    );
  }
}
