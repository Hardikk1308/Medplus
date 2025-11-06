import 'package:flutter/material.dart';
import 'package:medplus/pages/auth/screen1.dart';
import 'package:medplus/pages/auth/signup_page.dart';
import 'package:medplus/pages/auth/login_page.dart';
import 'package:medplus/pages/homescreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MedPlus',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/home': (context) => const Homescreen(),
      },
      // Fallback for dynamic links or deep links
      onGenerateRoute: (settings) {
        // Handle any dynamic routes here if needed
        return null;
      },
    );
  }
}
