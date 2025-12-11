import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:frontend/PatientDashboard.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;

import 'AdminDashboard.dart';
import 'DoctorDashboard.dart';

void main() {
  runApp(const MedCareApp());
}

class MedCareApp extends StatelessWidget {
  const MedCareApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFE8F4F8),
        fontFamily: 'SF Pro Display',
      ),
      home: const AuthScreen(),
    );
  }
}

// ============================================
// AUTH SCREEN
// ============================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    } else if (Platform.isIOS) {
      return 'http://127.0.0.1:3000/api';
    } else {
      return 'http://localhost:3000/api';
    }
  }

  String currentView = 'welcome'; // 'welcome', 'signin', 'signup'

  final loginIdController = TextEditingController();
  final passwordController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final ageController = TextEditingController();
  final phoneController = TextEditingController();

  String selectedGender = 'Male';
  String selectedBloodGroup = 'A+';

  bool isLoading = false;
  bool showPassword = false;

  late AnimationController _backgroundController;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );

    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _expandController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _expandController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _expandController.dispose();
    loginIdController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void expandToSignIn() {
    // Clear fields when switching to sign in
    loginIdController.clear();
    passwordController.clear();
    setState(() {
      currentView = 'signin';
      showPassword = false;
    });
    _expandController.forward();
  }

  void expandToSignUp() {
    // Clear fields when switching to sign up
    firstNameController.clear();
    lastNameController.clear();
    ageController.clear();
    phoneController.clear();
    passwordController.clear();
    setState(() {
      currentView = 'signup';
      selectedGender = 'Male';
      selectedBloodGroup = 'A+';
      showPassword = false;
    });
    _expandController.forward();
  }

  void collapseToWelcome() {
    // Clear all fields when going back to welcome
    loginIdController.clear();
    passwordController.clear();
    firstNameController.clear();
    lastNameController.clear();
    ageController.clear();
    phoneController.clear();

    _expandController.reverse().then((_) {
      setState(() {
        currentView = 'welcome';
        showPassword = false;
      });
    });
  }

  void switchBetweenForms() {
    if (currentView == 'signin') {
      collapseToWelcome();
      Future.delayed(const Duration(milliseconds: 450), () {
        expandToSignUp();
      });
    } else {
      collapseToWelcome();
      Future.delayed(const Duration(milliseconds: 450), () {
        expandToSignIn();
      });
    }
  }

  Future<void> handleSignUp() async {
    if (firstNameController.text.isEmpty ||
        lastNameController.text.isEmpty ||
        ageController.text.isEmpty ||
        phoneController.text.isEmpty ||
        passwordController.text.isEmpty) {
      showError('Please fill all required fields');
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'first_name': firstNameController.text,
          'last_name': lastNameController.text,
          'age': int.parse(ageController.text),
          'gender': selectedGender,
          'blood_group': selectedBloodGroup,
          'phone_no': phoneController.text,
          'password': passwordController.text,
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Clear fields after successful signup
        firstNameController.clear();
        lastNameController.clear();
        ageController.clear();
        phoneController.clear();
        passwordController.clear();
        setState(() {
          selectedGender = 'Male';
          selectedBloodGroup = 'A+';
        });

        showSuccess('Registration successful! Your ID is: ${data['patient_login_id']}');
        collapseToWelcome();
        Future.delayed(const Duration(milliseconds: 450), () {
          expandToSignIn();
        });
      } else {
        final errorData = jsonDecode(response.body);
        showError(errorData['error'] ?? 'Registration failed');
      }
    } catch (e) {
      setState(() => isLoading = false);
      showError('Connection error: Please check if server is running');
      print('Sign up error: $e');
    }
  }

  Future<void> handleSignIn() async {
    if (loginIdController.text.isEmpty || passwordController.text.isEmpty) {
      showError('Please enter ID and password');
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': loginIdController.text.trim(),
          'password': passwordController.text,
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userType = data['user_type'];
        final userData = data['user']; // Extract user data here

        // Clear fields after successful login
        loginIdController.clear();
        passwordController.clear();

        if (userType == 'admin') {
          showSuccess('Admin login successful!');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AdminDashboard(userData: userData),
            ),
          );
        } else if (userType == 'doctor') {
          showSuccess('Doctor login successful!');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DoctorDashboard(userData: userData), // Fixed: use userData instead of user
            ),
          );
        } else if (userType == 'patient') {
          showSuccess('Patient login successful!');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PatientDashboard(userData: userData), // Fixed: use userData instead of user
            ),
          );
        } else if (userType == 'receptionist') {
          showSuccess('Receptionist login successful!');
          // TODO: Navigate to Receptionist Dashboard
        }
      } else {
        final errorData = jsonDecode(response.body);
        showError(errorData['error'] ?? 'Sign in failed: Invalid credentials');
      }
    } catch (e) {
      setState(() => isLoading = false);
      showError('Connection error: Please check if server is running');
      print('Sign in error: $e');
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  void showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Professional Gradient Background
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              final t = _backgroundController.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        const Color(0xFFE8F4F8),
                        const Color(0xFFD5E8F0),
                        t,
                      )!,
                      Color.lerp(
                        const Color(0xFFD5E8F0),
                        const Color(0xFFC4DFE8),
                        (t + 0.3).clamp(0.0, 1.0),
                      )!,
                      Color.lerp(
                        const Color(0xFFC4DFE8),
                        const Color(0xFFB3D6E0),
                        (t + 0.6).clamp(0.0, 1.0),
                      )!,
                    ],
                  ),
                ),
              );
            },
          ),

          // Hospital System Visual Elements - Subtle and Professional
          // Top-left: Patient Record Icon
          Positioned(
            top: 40,
            left: 30,
            child: Opacity(
              opacity: 0.06,
              child: Transform.rotate(
                angle: -0.1,
                child: const Icon(
                  Icons.folder_shared,
                  size: 120,
                  color: Color(0xFF4A90E2),
                ),
              ),
            ),
          ),

          // Top-right: Calendar/Appointments
          Positioned(
            top: 60,
            right: 40,
            child: Opacity(
              opacity: 0.06,
              child: Transform.rotate(
                angle: 0.1,
                child: const Icon(
                  Icons.calendar_month,
                  size: 100,
                  color: Color(0xFF4A90E2),
                ),
              ),
            ),
          ),

          // Middle-left: Stethoscope/Doctor
          Positioned(
            top: 250,
            left: 20,
            child: Opacity(
              opacity: 0.05,
              child: const Icon(
                Icons.medical_services,
                size: 90,
                color: Color(0xFF4A90E2),
              ),
            ),
          ),

          // Middle-right: Prescription/Medicine
          Positioned(
            top: 300,
            right: 30,
            child: Opacity(
              opacity: 0.05,
              child: Transform.rotate(
                angle: 0.15,
                child: const Icon(
                  Icons.medication,
                  size: 85,
                  color: Color(0xFF4A90E2),
                ),
              ),
            ),
          ),

          // Bottom-left: Hospital Building
          Positioned(
            bottom: 100,
            left: 35,
            child: Opacity(
              opacity: 0.06,
              child: const Icon(
                Icons.local_hospital,
                size: 110,
                color: Color(0xFF4A90E2),
              ),
            ),
          ),

          // Bottom-right: Medical Chart/Analytics
          Positioned(
            bottom: 80,
            right: 45,
            child: Opacity(
              opacity: 0.05,
              child: Transform.rotate(
                angle: -0.1,
                child: const Icon(
                  Icons.assessment,
                  size: 95,
                  color: Color(0xFF4A90E2),
                ),
              ),
            ),
          ),

          // Center-background: Large subtle cross
          Positioned(
            top: 200,
            left: 0,
            right: 0,
            child: Center(
              child: Opacity(
                opacity: 0.03,
                child: const Icon(
                  Icons.add,
                  size: 300,
                  color: Color(0xFF4A90E2),
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: AnimatedBuilder(
                  animation: _expandAnimation,
                  builder: (context, child) {
                    double additionalHeight = 0;
                    if (currentView == 'signin') {
                      additionalHeight = 80 * _expandAnimation.value;
                    } else if (currentView == 'signup') {
                      additionalHeight = 500 * _expandAnimation.value;
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      width: 440,
                      constraints: BoxConstraints(
                        minHeight: 520 + additionalHeight,
                      ),
                      padding: const EdgeInsets.all(45),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE0E0E0).withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 30,
                            spreadRadius: 0,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (currentView == 'welcome')
                            FadeTransition(
                              opacity: _fadeOutAnimation,
                              child: _buildWelcomeContent(),
                            )
                          else
                            FadeTransition(
                              opacity: _fadeInAnimation,
                              child: _buildFormContent(),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Simple Professional Medical Icon
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF4A90E2),
                const Color(0xFF357ABD),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A90E2).withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.local_hospital_rounded,
              size: 45,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // App Name
        const Text(
          'MedCare',
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
            letterSpacing: -1,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 12),

        // Tagline
        const Text(
          'Book Smart, Heal Faster',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 50),

        // Login Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: expandToSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: const Color(0xFF4A90E2).withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Login With ID',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Sign Up Link
        TextButton(
          onPressed: expandToSignUp,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4A90E2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text(
            "Don't have an account? Sign Up",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            currentView == 'signin' ? Icons.login : Icons.person_add,
            size: 24,
            color: const Color(0xFF4A90E2),
          ),
        ),
        const SizedBox(height: 24),

        // Title
        Text(
          currentView == 'signin' ? 'Sign In' : 'Sign Up',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          currentView == 'signin'
              ? 'Sign in now to access your account'
              : 'Create your account to get started',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF777777),
          ),
        ),
        const SizedBox(height: 30),

        // Form Fields
        if (currentView == 'signup') ...[
          _buildFieldLabel('First Name'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: firstNameController,
            hint: 'Enter first name',
          ),
          const SizedBox(height: 18),

          _buildFieldLabel('Last Name'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: lastNameController,
            hint: 'Enter last name',
          ),
          const SizedBox(height: 18),

          _buildFieldLabel('Age'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: ageController,
            hint: 'Enter age',
          ),
          const SizedBox(height: 18),

          _buildFieldLabel('Gender'),
          const SizedBox(height: 8),
          _buildDropdown(
            value: selectedGender,
            items: ['Male', 'Female', 'Other'],
            onChanged: (value) => setState(() => selectedGender = value!),
          ),
          const SizedBox(height: 18),

          _buildFieldLabel('Blood Group'),
          const SizedBox(height: 8),
          _buildDropdown(
            value: selectedBloodGroup,
            items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
            onChanged: (value) => setState(() => selectedBloodGroup = value!),
          ),
          const SizedBox(height: 18),

          _buildFieldLabel('Phone Number'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: phoneController,
            hint: 'Enter phone number',
          ),
          const SizedBox(height: 18),

          _buildFieldLabel('Password'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: passwordController,
            hint: 'Enter password',
            isPassword: true,
          ),
        ],

        if (currentView == 'signin') ...[
          _buildFieldLabel('Login ID'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: loginIdController,
            hint: 'Enter your ID',
          ),
          const SizedBox(height: 18),

          _buildFieldLabel('Password'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: passwordController,
            hint: 'Enter your password',
            isPassword: true,
          ),
          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4A90E2),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 28),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading
                ? null
                : (currentView == 'signin' ? handleSignIn : handleSignUp),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              elevation: 0,
              disabledBackgroundColor: const Color(0xFFBBDEFB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isLoading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
                : Text(
              currentView == 'signin' ? 'LOGIN' : 'SIGNUP',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Toggle Link
        Center(
          child: GestureDetector(
            onTap: switchBetweenForms,
            child: RichText(
              text: TextSpan(
                text: currentView == 'signin'
                    ? "Don't have an account? "
                    : 'Already have an account? ',
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: currentView == 'signin' ? 'Sign Up' : 'Sign In',
                    style: const TextStyle(
                      color: Color(0xFF4A90E2),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Back to Welcome
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: collapseToWelcome,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF888888),
            ),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text(
              'Back',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF333333),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
  }) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !showPassword,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF1A1A1A),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFFAAAAAA),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              showPassword ? Icons.visibility_off : Icons.visibility,
              color: const Color(0xFF999999),
              size: 18,
            ),
            onPressed: () => setState(() => showPassword = !showPassword),
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF999999)),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1A1A1A),
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

