import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
// import 'package:app/home/analytics_page.dart'; // Hidden for now

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  String _userName = 'User';
  String _userRole = '';
  String _userEmail = '';
  String _userCourse = '';
  String _userYearLevel = '';
  String _userSection = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() {
        _userEmail = user.email ?? '';
      });

      final snapshot =
          await FirebaseDatabase.instance
              .ref()
              .child('users')
              .child(user.uid)
              .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _userName = data['name'] ?? 'User';
          _userRole = data['role'] ?? 'Unknown';
          _userCourse = data['course'] ?? '';
          _userYearLevel = data['yearLevel'] ?? '';
          _userSection = data['section'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigation should be handled by your routing system
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFF2AA39F).withValues(alpha: 0.1),
              child: const Icon(
                Icons.person,
                size: 80,
                color: Color(0xFF2AA39F),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _userName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _userEmail,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2AA39F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _userRole.isNotEmpty
                    ? _userRole == 'teacher'
                        ? 'Instructor'
                        : _userRole[0].toUpperCase() + _userRole.substring(1)
                    : "Role not set",
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2AA39F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Show course info for students
            if (_userRole == 'student' && _userCourse.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '$_userCourse $_userYearLevel-$_userSection',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            const SizedBox(height: 40),

            _buildSectionHeader('Account'),
            _buildProfileOption(
              'Edit Profile',
              Icons.edit,
              _showEditProfileDialog,
            ),
            _buildProfileOption(
              'Change Password',
              Icons.lock,
              _showChangePasswordDialog,
            ),
            // Analytics section hidden for now
            // if (_userRole == 'teacher') ...[
            //   const SizedBox(height: 30),
            //   _buildSectionHeader('Analytics'),
            //   _buildProfileOption('View Analytics', Icons.analytics, () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => const AnalyticsPage(),
            //       ),
            //     );
            //   }),
            // ],

            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption(String title, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Icon(icon, color: const Color(0xFF2AA39F)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userName);
    String selectedCourse = _userCourse;
    String selectedYearLevel = _userYearLevel;
    String selectedSection = _userSection;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    if (_userRole == 'student') ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedCourse.isEmpty ? null : selectedCourse,
                        decoration: const InputDecoration(
                          labelText: 'Course',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.school),
                        ),
                        items: [
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
                          setDialogState(() {
                            selectedCourse = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedYearLevel.isEmpty
                            ? null
                            : selectedYearLevel,
                        decoration: const InputDecoration(
                          labelText: 'Year Level',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        items: ['1', '2', '3', '4'].map((year) {
                          return DropdownMenuItem(
                            value: year,
                            child: Text('$year${_getYearSuffix(year)} Year'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedYearLevel = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value:
                            selectedSection.isEmpty ? null : selectedSection,
                        decoration: const InputDecoration(
                          labelText: 'Set',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.group),
                        ),
                        items: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'].map((section) {
                          return DropdownMenuItem(
                            value: section,
                            child: Text('$section'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedSection = value ?? '';
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    navigator.pop();

                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    if (nameController.text.trim().isEmpty) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Please enter your name'),
                        ),
                      );
                      return;
                    }

                    // Validate student fields if student
                    if (_userRole == 'student') {
                      if (selectedCourse.isEmpty ||
                          selectedYearLevel.isEmpty ||
                          selectedSection.isEmpty) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please fill in all student information',
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    try {
                      final updateData = {
                        'name': nameController.text.trim(),
                      };

                      // Add student-specific fields
                      if (_userRole == 'student') {
                        updateData['course'] = selectedCourse;
                        updateData['yearLevel'] = selectedYearLevel;
                        updateData['section'] = selectedSection;
                      }

                      await FirebaseDatabase.instance
                          .ref()
                          .child('users')
                          .child(user.uid)
                          .update(updateData);

                      if (mounted) {
                        setState(() {
                          _userName = nameController.text.trim();
                          if (_userRole == 'student') {
                            _userCourse = selectedCourse;
                            _userYearLevel = selectedYearLevel;
                            _userSection = selectedSection;
                          }
                        });
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated successfully'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('Error updating profile: $e'),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AA39F),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getYearSuffix(String year) {
    switch (year) {
      case '1':
        return 'st';
      case '2':
        return 'nd';
      case '3':
        return 'rd';
      case '4':
        return 'th';
      default:
        return '';
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: obscureCurrentPassword,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrentPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureCurrentPassword = !obscureCurrentPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNewPassword,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureNewPassword = !obscureNewPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureConfirmPassword = !obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (newPasswordController.text !=
                        confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Passwords do not match')),
                      );
                      return;
                    }

                    if (newPasswordController.text.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Password must be at least 6 characters',
                          ),
                        ),
                      );
                      return;
                    }

                    final navigator = Navigator.of(context);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    navigator.pop();

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      final credential = EmailAuthProvider.credential(
                        email: user?.email ?? '',
                        password: currentPasswordController.text,
                      );

                      await user?.reauthenticateWithCredential(credential);
                      await user?.updatePassword(newPasswordController.text);

                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Password updated successfully'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2AA39F),
                  ),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
