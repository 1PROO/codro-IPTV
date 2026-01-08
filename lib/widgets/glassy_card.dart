import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class GlassyCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? height;
  final EdgeInsetsGeometry padding;
  final bool isActive;

  const GlassyCard({
    super.key,
    required this.child,
    this.onTap,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              gradient: isActive
                  ? AppTheme.glassActiveGradient
                  : AppTheme.glassGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.glassBorderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
