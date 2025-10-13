import 'package:flutter/material.dart';

class AppThemes {
  static ThemeData lightTheme(Color accent) => ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: accent,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
      secondary: accent,
      onSecondary: Colors.white,
      error: Colors.red,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    scaffoldBackgroundColor: Colors.white,
  );

  static ThemeData darkTheme(Color accent) => ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: accent,
      onPrimary: Colors.white,
      surface: const Color(0xFF222222),
      onSurface: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      error: Colors.redAccent,
      onError: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
  );
}
