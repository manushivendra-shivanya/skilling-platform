import 'package:flutter/material.dart';

abstract final class AppTypography {
  static TextTheme textTheme(Color textColor) {
    return TextTheme(
      displaySmall: TextStyle(
        color: textColor,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        color: textColor,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      headlineSmall: TextStyle(
        color: textColor,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        color: textColor,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleMedium: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      labelMedium: TextStyle(
        color: textColor,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      labelSmall: TextStyle(
        color: textColor,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
    );
  }
}
