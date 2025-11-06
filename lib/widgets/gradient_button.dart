import 'package:flutter/material.dart';
import 'package:medplus/theme/app_colors.dart';

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final List<Color>? gradientColors;
  final bool enabled;
  final EdgeInsetsGeometry? padding;

  const GradientButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.width,
    this.height = 50.0,
    this.borderRadius = 12.0,
    this.gradientColors,
    this.enabled = true,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? AppColors.primaryGradient;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enabled ? colors : [Colors.grey[400]!, Colors.grey[500]!],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: Color.fromRGBO(
                    (colors.last.r * 255).round() & 0xff,
                    (colors.last.g * 255).round() & 0xff,
                    (colors.last.b * 255).round() & 0xff,
                    0.3,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: padding,
        ),
        child: child,
      ),
    );
  }
}
