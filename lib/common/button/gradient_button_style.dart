import 'package:flutter/material.dart';
import 'package:medplus/common/colors.dart';
// import 'package:talkio/core/constants/colors.dart';

class GradientElevatedButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final List<Color> gradientColors;

  const GradientElevatedButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.gradientColors = const [
      AppColors.primaryColor,
      AppColors.secondaryColor,
    ], Center? child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55, // Fixed height for a comfortable tap target
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15.0),
        // Apply the gradient decoration here
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          // Subtle shadow to enhance the "elevated" look
          BoxShadow(
            color: Color.fromRGBO(
              (gradientColors.first.r * 255).round() & 0xff,
              (gradientColors.first.g * 255).round() & 0xff,
              (gradientColors.first.b * 255).round() & 0xff,
              0.2,
            ),
            blurRadius: 10.0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          // Make the button transparent so the container's gradient shows
          backgroundColor: Colors.transparent,
          // Remove built-in shadow/elevation
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          // Set padding to zero as the height is fixed on the container
          padding: EdgeInsets.zero,
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
