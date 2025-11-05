import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:medplus/common/button/Gradient.dart';
import 'package:medplus/common/button/outline.dart';
import 'package:medplus/common/colors.dart';

class Signup extends StatelessWidget {
  const Signup({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive padding
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(flex: 2),

            // ------------------
            // Hero Image/Illustration Section
            // ------------------
            Center(
              child: Image.asset(
                'assets/images/2nd.png', // Keep your original asset path
                height: screenHeight * 0.45, // Allocate space for the image
                errorBuilder: (context, error, stackTrace) => Container(
                  height: screenHeight * 0.45,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryColor, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Hero Illustration Here',
                    style: TextStyle(color: AppColors.textColor),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // ------------------
            // Title
            // ------------------
            const Center(
              child: Text(
                // Corrected typo: "Let's meet new people around you"
                "Let's meet new people\naround you",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const Spacer(flex: 2),

            // ------------------
            // Buttons Section
            // ------------------

            // 1. Login with phone (Outlined Button)
            OutlineGradientButton(
              text: 'Login with phone',
              onPressed: () {
                // Handle phone login
              },
              // Use primary color for outline
            ),

            const SizedBox(height: 15),

            // 2. Login with google (Gradient Button)
            GradientElevatedButton(
              text: 'Login with google',
              onPressed: () {
                // Handle Google login
              },

              gradientColors: const [
                AppColors.primaryColor,
                AppColors.secondaryColor,
              ],
            ),

            const SizedBox(height: 20),

            // 3. Sign up link
            Center(
              child: RichText(
                text: TextSpan(
                  text: "Don't have account ",
                  style: TextStyle(
                    color: AppColors.textColor.withOpacity(0.7),
                    fontSize: 16,
                  ),
                  children: [
                    TextSpan(
                      text: "Sign up",
                      style: const TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                      // You can add a recognizer to make this link clickable
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          // Navigate to sign up screen
                        },
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
