import 'package:app/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfileSetupPage extends StatefulWidget {
  final String userId;

  const ProfileSetupPage({super.key, required this.userId});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  String _selectedRole = ''; // Can be 'student' or 'teacher'
  String _selectedCourse = '';
  String _selectedYearLevel = '';
  String _selectedSection = '';
  bool _isLoading = false;
  late DatabaseReference _database;

  @override
  void initState() {
    super.initState();
    // Set the correct Firebase database URL
    FirebaseDatabase.instance.databaseURL =
        'https://smartlab-e2107-default-rtdb.asia-southeast1.firebasedatabase.app';
    // Initialize database reference
    _database = FirebaseDatabase.instance.ref();
  }

  // Save role selection and complete profile setup
  Future<void> _completeSetup() async {
    if (_selectedRole.isEmpty) {
      _showSnackBar("Please select a role to continue");
      return;
    }

    // Validate student-specific fields
    if (_selectedRole == 'student') {
      if (_selectedCourse.isEmpty) {
        _showSnackBar("Please select your course");
        return;
      }
      if (_selectedYearLevel.isEmpty) {
        _showSnackBar("Please select your year level");
        return;
      }
      if (_selectedSection.isEmpty) {
        _showSnackBar("Please select your set");
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // Prepare user data
      final userData = {'role': _selectedRole, 'profile_setup': true};

      // Add course info for students
      if (_selectedRole == 'student') {
        userData['course'] = _selectedCourse;
        userData['yearLevel'] = _selectedYearLevel;
        userData['section'] = _selectedSection;
      }

      // Update user data with role and mark profile setup as complete
      await _database.child('users').child(widget.userId).update(userData);

      _showSnackBar("Profile setup complete!");

      // Navigate to HomePage with refresh flag
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomePage(forceReload: true)),
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      _showSnackBar("Failed to complete profile setup: $e");
      debugPrint("Error in profile setup: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.science, size: 32),
            const SizedBox(width: 8),
            const Text(
              "SMARTLAB",
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2AA39F),
        foregroundColor: Colors.white,
        elevation: 0,
        // Prevent going back to registration
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select Your Role',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose your role in the system to continue',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Student option card
              _buildRoleCard(
                title: 'Student',
                description:
                    'Access learning materials and track your progress',
                icon: Icons.school,
                isSelected: _selectedRole == 'student',
                onTap: () => setState(() => _selectedRole = 'student'),
              ),

              const SizedBox(height: 20),

              // Teacher option card
              _buildRoleCard(
                title: 'Instructor',
                description: 'Create courses and manage student progress',
                icon: Icons.psychology,
                isSelected: _selectedRole == 'teacher',
                onTap: () => setState(() => _selectedRole = 'teacher'),
              ),

              const SizedBox(height: 30),

              // Student-specific fields (only show if student is selected)
              if (_selectedRole == 'student') ...[
                const Text(
                  'Student Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Course dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCourse.isEmpty ? null : _selectedCourse,
                  decoration: InputDecoration(
                    labelText: 'Course *',
                    hintText: 'Select your course',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    errorText: null,
                  ),
                  items:
                      [
                      // IAAS
                      'BSAF',
                      'BSFAS',
                      'BSFT',
                      'BSMB',

                      // IC
                      'BSIS',
                      'BSIT',

                      // ILEGG
                      'BPA',
                      'BSDRM',
                      'BSENTREP',
                      'BSSW',
                      'BSTM',

                      // ITEd
                      'BACOMM',
                      'BSEDENG',
                      'BSEDMATH',
                      'BSEDSCIENCES',
                      'BTLED',
                      ].map((course) {
                        return DropdownMenuItem(
                          value: course,
                          child: Text(course),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCourse = value!);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your course';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Year Level dropdown
                DropdownButtonFormField<String>(
                  value: _selectedYearLevel.isEmpty ? null : _selectedYearLevel,
                  decoration: InputDecoration(
                    labelText: 'Year Level *',
                    hintText: 'Select your year level',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  items:
                      ['1', '2', '3', '4'].map((year) {
                        return DropdownMenuItem(
                          value: year,
                          child: Text('${_getYearSuffix(year)} Year'),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedYearLevel = value!);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your year level';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Section dropdown
                DropdownButtonFormField<String>(
                  value: _selectedSection.isEmpty ? null : _selectedSection,
                  decoration: InputDecoration(
                    labelText: 'Set *',
                    hintText: 'Select your set',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  items:
                      ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'].map((section) {
                        return DropdownMenuItem(
                          value: section,
                          child: Text('Set $section'),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedSection = value!);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your set';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  '* All fields are required',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              const Spacer(),

              // Continue button
              ElevatedButton(
                onPressed: _isLoading ? null : _completeSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF52B788),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.0,
                          ),
                        )
                        : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE6F7F5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2AA39F) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? const Color(0xFF2AA39F).withValues(alpha: 0.2)
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 32,
                color:
                    isSelected ? const Color(0xFF2AA39F) : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color:
                          isSelected ? const Color(0xFF2AA39F) : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          isSelected
                              ? const Color(0xFF2AA39F)
                              : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF2AA39F),
                size: 28,
              ),
          ],
        ),
      ),
    );
  }

  String _getYearSuffix(String year) {
    switch (year) {
      case '1':
        return '1st';
      case '2':
        return '2nd';
      case '3':
        return '3rd';
      case '4':
        return '4th';
      default:
        return '${year}th';
    }
  }
}