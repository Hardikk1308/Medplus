import 'package:flutter/material.dart';
import 'package:medplus/common/colors.dart';

class OutlineGradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final List<Color> gradientColors;

  const OutlineGradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.gradientColors = const [
      AppColors.primaryColor,
      AppColors.secondaryColor,
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50, // Fixed height to match the elevated button
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15.0),
        // Create the gradient border effect by masking with the background color
        border: Border.all(color: AppColors.secondaryColor, width: 2),
      ),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.backgroundColor, // White background
          foregroundColor:
              AppColors.secondaryColor, // Text color is the main pink
          side: const BorderSide(
            color: Colors.transparent, // Hide the default outline
            width: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
