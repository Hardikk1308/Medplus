import 'package:flutter/material.dart';
// import 'package:medplus/auth/login.dart';
// import 'package:flutter_svg/flutter_svg.dart';
import 'package:medplus/models/onboard.dart';
import 'package:medplus/pages/auth/login_page.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
// import 'onboarding_contents.dart'; // Import the model file

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 1. PageView for swipeable screens
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: contents.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return OnboardingPage(content: contents[index]);
              },
            ),
          ),

          // 2. Dots Indicator and Button area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                // Dots Indicator
                SmoothPageIndicator(
                  controller: _controller,
                  count: contents.length,
                  effect: ExpandingDotsEffect(
                    spacing: 8.0,
                    radius: 4.0,
                    dotWidth: 8.0,
                    dotHeight: 8.0,
                    strokeWidth: 1.5,
                    dotColor: Colors.grey.shade300,
                    activeDotColor: const Color(
                      0xFF5C6BC0,
                    ), // Use the primary button blue
                  ),
                ),

                const SizedBox(height: 48),

                // Button (Next/Get Started)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < contents.length - 1) {
                        // Go to next page
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeIn,
                        );
                      } else {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                        // print("Onboarding Complete!");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C6BC0), // Primary blue
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          contents[_currentPage].buttonText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (_currentPage < contents.length - 1)
                          const Icon(Icons.arrow_forward),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Widget for each Onboarding Page
class OnboardingPage extends StatelessWidget {
  final OnboardingContent content;

  const OnboardingPage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top Spacer (to push content down like in the phone screenshot)
          const Spacer(flex: 1),

          // Image/Illustration
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35, // Adjust height
            child: Image.asset(content.imagePath, fit: BoxFit.contain),
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            content.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            content.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),

          // Bottom Spacer (to fill remaining space above the indicator)
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
