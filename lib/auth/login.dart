import 'package:flutter/material.dart';
import 'package:medplus/common/button/Gradient.dart';
import 'package:medplus/common/button/outline.dart';
import 'package:medplus/common/colors.dart';
import 'package:medplus/pages/Homescreen.dart';
import 'package:medplus/services/Authservice.dart';
import 'package:medplus/widgets/customtexxtfiled.dart';

class Loginscreen extends StatefulWidget {
  const Loginscreen({super.key});

  @override
  State<Loginscreen> createState() => _LoginscreenState();
}

class _LoginscreenState extends State<Loginscreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Check for existing token immediately when the screen loads
    _checkLoginStatus();
  }

  /// Checks secure storage for a token and navigates if logged in.
  Future<void> _checkLoginStatus() async {
    final authService = AuthService();
    final isLoggedIn = await authService.isUserLoggedIn();

    if (mounted && isLoggedIn) {
      // Token found, navigate home immediately
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Homescreen()),
      );
    }
    // If not logged in, remain on the Login screen
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final String email = _usernameController.text.trim();
    final String password = _passwordController.text;

    final authService = AuthService();
    final success = await authService.login(email, password); // API call and token save

    if (mounted) {
      if (success) {
        // Token is now saved in AuthService. Just need to check status and redirect.
        await _checkLoginStatus(); 
      } else {
        // Show an error message (SnackBar)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login failed. Please check your credentials.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: screenHeight * 0.15),

              // App Logo and Name
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: screenHeight * 0.12,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.medical_services_outlined, // Placeholder icon
                    color: AppColors.primaryColor,
                    size: 100,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'MedPlus',
                  style: TextStyle(
                    color: AppColors.textColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 50),

              // Welcome Text
              const Center(
                child: Text(
                  'Sign In to Your Account',
                  style: TextStyle(
                    color: AppColors.textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Input Fields Section
              CustomTextField(
                controller: _usernameController,
                hintText: 'Email',
                icon: Icons.person_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _passwordController,
                hintText: 'Password',
                icon: Icons.lock_outline,
                obscureText: true,
                keyboardType: TextInputType.visiblePassword,
              ),
              const SizedBox(height: 40),

              // Buttons Section
              GradientElevatedButton(
                text: _isLoading ? 'Signing In...' : 'Sign In',
                // Disable button when loading
                onPressed: _isLoading ?  _handleLogin : _handleLogin, 
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : null,
              ),

              const SizedBox(height: 15),

              OutlineGradientButton(
                text: 'Create Account',
                onPressed: () {
                  debugPrint('Navigate to Signup');
                },
              ),
              const SizedBox(height: 40),

              // Back Button (Moved to bottom)
              Center(
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.05), // Bottom spacing
            ],
          ),
        ),
      ),
    );
  }
}