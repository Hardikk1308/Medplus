import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medplus/pages/homescreen.dart';
import 'package:medplus/theme/app_colors.dart';
import 'package:medplus/pages/auth/login_page.dart';
import 'package:medplus/services/auth_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form controllers
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _obscurePassword = true;

  // Doctor selection (normalized)
  // Store as list of {id, name, spec} with id as String
  List<Map<String, String>> _doctors = [];
  String? _selectedDoctorId;
  bool _isLoadingDoctors = false;
  String? _doctorLoadError;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    if (_isLoadingDoctors) return;

    setState(() {
      _isLoadingDoctors = true;
      _doctorLoadError = null;
    });

    try {
      // Adjust this path if your backend differs
      final res = await http.get(
        Uri.parse('${AuthService.baseUrl}/users/doctors'),
        headers: {'Content-Type': 'application/json'},
      );

      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);

        final normalized = <Map<String, String>>[];
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            // The API you showed returns "id" and "full_name"
            final rawId = item['id'] ?? item['_id'];
            if (rawId == null) continue;
            final id = rawId.toString();

            final name =
                (item['full_name'] ??
                        item['fullName'] ??
                        item['username'] ??
                        'Unknown')
                    .toString();

            // Your sample doesn’t include specialization; default to General
            // final spec = (item['specialization'] ?? 'General').toString();

            normalized.add({'id': id, 'name': name});
          }
        }

        // Ensure current selection is valid
        final ids = normalized.map((e) => e['id']!).toSet();
        if (_selectedDoctorId != null && !ids.contains(_selectedDoctorId)) {
          _selectedDoctorId = null;
        }

        setState(() {
          _doctors = normalized;
        });
      } else {
        throw Exception('Failed to load doctors (status ${res.statusCode})');
      }
    } catch (e) {
      setState(() {
        _doctorLoadError = 'Failed to load doctors. Please try again later.';
        _selectedDoctorId = null; // reset selection on error
      });
      debugPrint('Error loading doctors: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDoctors = false;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (!mounted) return;

      // Call the AuthService.signup method
      await AuthService.signup(
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        role: 'patient', // Default role, adjust as needed
        doctorId: _selectedDoctorId,
      );

      // If we get here, signup was successful and token is stored
      if (!mounted) return;
      
      // Navigate to home screen
      Navigator.pushReplacementNamed(context, '/home');
      
    } catch (e) {
      if (!mounted) return;

      String errorMessage = 'An error occurred during registration';
      if (e.toString().contains('email already exists')) {
        errorMessage = 'This email is already registered';
      } else if (e.toString().contains('username already taken')) {
        errorMessage = 'This username is already taken';
      } else if (e.toString().toLowerCase().contains('network')) {
        errorMessage = 'Network error. Please check your connection';
      } else {
        // Add more specific error handling if needed
        errorMessage = e.toString();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure the selected value exists; otherwise null to show hint
    final existingIds = _doctors.map((d) => d['id']!).toSet();
    final safeSelectedValue = existingIds.contains(_selectedDoctorId)
        ? _selectedDoctorId
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Fill in your details to create an account',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Full Name
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(
                          r'^[^@]+@[^\s]+\.[^\s]+$',
                        ).hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Username
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please choose a username';
                        }
                        if (value.length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    // Doctor selection
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Doctor (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isLoadingDoctors)
                          const LinearProgressIndicator()
                        else if (_doctorLoadError != null)
                          Text(
                            _doctorLoadError!,
                            style: const TextStyle(color: Colors.red),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                hint: const Text('Select a doctor'),
                                value: safeSelectedValue,
                                icon: const Icon(Icons.arrow_drop_down),
                                iconSize: 24,
                                elevation: 16,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedDoctorId = newValue;
                                  });
                                },
                                items: _doctors.map<DropdownMenuItem<String>>((
                                  doctor,
                                ) {
                                  final id = doctor['id']!;
                                  final name = doctor['name'] ?? 'Unknown';

                                  return DropdownMenuItem<String>(
                                    value: id,
                                    child: Text(
                                      'Dr. $name',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account?'),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  // Typically go to Login, not Home, from the signup screen
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginPage(),
                                    ),
                                  );
                                },
                          child: const Text(
                            'Sign In',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
