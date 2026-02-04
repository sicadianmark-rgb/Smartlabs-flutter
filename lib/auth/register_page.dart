import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'profile_setup.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late DatabaseReference _database;

  @override
  void initState() {
    super.initState();
    // Configure Firebase
    FirebaseDatabase.instance.databaseURL =
        'https://smartlab-e2107-default-rtdb.asia-southeast1.firebasedatabase.app';
    _database = FirebaseDatabase.instance.ref();
  }

  @override
  void dispose() {
    // Clean up controllers
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Show a snackbar message
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Validate and handle registration
  Future<void> _register() async {
    // Form validation
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create Firebase Auth user
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final uid = userCredential.user!.uid;
      final userData = {
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'profile_setup': false, // Flag to track if profile setup is complete
      };

      // Store in Realtime Database
      await _database.child('users').child(uid).update(userData);

      _showSnackBar("Registration successful!");

      // Navigate to profile setup page instead of popping back
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileSetupPage(userId: uid),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      final errorMessages = {
        'weak-password': "The password provided is too weak",
        'email-already-in-use': "The email is already in use",
        'invalid-email': "Invalid email format",
        'operation-not-allowed': "Email/password accounts are not enabled",
        'network-request-failed': "Network error. Check your connection",
      };

      _showSnackBar(errorMessages[e.code] ?? "Registration failed");
      debugPrint("Firebase Auth Error: ${e.code} - ${e.message}");
    } on TimeoutException {
      _showSnackBar("Connection timeout. Please try again.");
    } catch (e) {
      _showSnackBar("Registration Failed: $e");
      debugPrint("General error during registration: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
                child: _buildForm(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // App header with logo
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: const BoxDecoration(
        color: Color(0xFF2AA39F),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(100),
          bottomRight: Radius.circular(100),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.science, size: 100, color: Colors.white),
            const SizedBox(height: 12),
            const Text(
              'SMARTLAB',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Registration form
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),
          const Row(
            children: [
              Text(
                'REGISTER ',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Name field
          _buildInputField(
            label: 'Full Name',
            controller: _nameController,
            hintText: 'Your full name',
            keyboardType: TextInputType.name,
            validator:
                (value) => value!.isEmpty ? 'Please enter your name' : null,
          ),

          // Email field
          _buildInputField(
            label: 'Email address',
            controller: _emailController,
            hintText: 'your.email@dnsc.edu.ph',
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value!.isEmpty) return 'Please enter your email';
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return 'Please enter a valid email';
              }
              if (!value.endsWith('@dnsc.edu.ph')) {
                return 'Only @dnsc.edu.ph email addresses are allowed';
              }
              return null;
            },
          ),

          // Password field
          _buildInputField(
            label: 'Password',
            controller: _passwordController,
            hintText: 'Password',
            obscureText: _obscurePassword,
            validator:
                (value) =>
                    value!.length < 6
                        ? 'Password must be at least 6 characters'
                        : null,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey,
              ),
              onPressed:
                  () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),

          const SizedBox(height: 30),

          // Sign up button
          ElevatedButton(
            onPressed: _isLoading ? null : _register,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF52B788),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.0,
                      ),
                    )
                    : const Text(
                      'Sign up',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),

          const SizedBox(height: 20),

          // Login text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Already have an account? "),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Login',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Reusable input field component
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey[200],
            suffixIcon: suffixIcon,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
