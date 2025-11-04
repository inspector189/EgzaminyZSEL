import 'package:flutter/material.dart';

class AppThemes {
  static ThemeData lightTheme(Color primaryColor, Color secondaryColor) =>
      ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          onPrimary: Color(0xFF333333),
          surface: Colors.white,
          onSurface: Colors.black,
          onSurfaceVariant: Colors.black87,
          secondary: secondaryColor,
          onSecondary: Colors.white,
          error: Colors.red,
          onError: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        dividerColor: Colors.transparent,
        scaffoldBackgroundColor: Colors.white,
      );

  static ThemeData darkTheme(Color primaryColor, Color secondaryColor) =>
      ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          onPrimary: Colors.white,
          surface: const Color(0xFF222222),
          onSurface: const Color(0xFFCCCCCC),
          onSurfaceVariant: Colors.grey,
          secondary: secondaryColor,
          onSecondary: Colors.white,
          error: Colors.redAccent,
          onError: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        dividerColor: Colors.transparent,
        scaffoldBackgroundColor: const Color(0xFF121212),
      );
}
