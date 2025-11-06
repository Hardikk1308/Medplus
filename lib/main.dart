import 'package:flutter/material.dart';
import 'package:medplus/pages/auth/screen1.dart';
import 'package:medplus/pages/auth/signup_page.dart';
import 'package:medplus/pages/auth/login_page.dart';
import 'package:medplus/pages/homescreen.dart';
import 'package:medplus/services/auth_service.dart';
import 'package:medplus/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();

  // Initialize app
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isLoading = false;
      });
    } catch (e) {
      // If there's an error checking auth status, default to not logged in
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Show a loading screen while checking auth status
      return const Material(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sahara',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: _isLoggedIn ? '/home' : '/',
      routes: {
        '/': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/home': (context) => const Homescreen(),
      },
      // Handle deep linking
      onGenerateRoute: (settings) {
        // You can add deep link handling here if needed
        return null;
      },
    );
  }
}
