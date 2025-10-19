import 'package:flutter/material.dart';

class AppThemes {
  static ThemeData lightTheme(Color primaryColor, Color secondaryColor) => ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
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
    dividerColor: const Color(0xFF333333),
    scaffoldBackgroundColor: Colors.white,
  );

  static ThemeData darkTheme(Color primaryColor, Color secondaryColor) => ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      onPrimary: Colors.white,
      surface: const Color(0xFF222222),
      onSurface: const Color(0xFFCCCCCC),
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
    dividerColor: const Color(0xFFBBBBBB),
    scaffoldBackgroundColor: const Color(0xFF121212),
  );
}
