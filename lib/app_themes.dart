import 'package:flutter/material.dart';

class AppThemes {
  static ThemeData lightTheme(Color primaryColor, Color secondaryColor) =>
      ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          onPrimary: const Color(0xFF333333),
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
        extensions: const [
          ExtraColors(
            shimmerBase: Color(0xFFE0E0E0),
            shimmerHighlight: Color(0xFFF5F5F5),
            correct: Colors.green,
            incorrect: Colors.red,
            noAnswer: Colors.amber,
          ),
        ],
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
        extensions: const [
          ExtraColors(
            shimmerBase: Color(0xFF2A2A2A),
            shimmerHighlight: Color(0xFF3C3C3C),
            correct: Colors.greenAccent,
            incorrect: Colors.redAccent,
            noAnswer: Colors.amberAccent,
          ),
        ],
      );
}

@immutable
class ExtraColors extends ThemeExtension<ExtraColors> {
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color correct;
  final Color incorrect;
  final Color noAnswer;

  const ExtraColors({
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.correct,
    required this.incorrect,
    required this.noAnswer,
  });

  @override
  ExtraColors copyWith({
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? correct,
    Color? incorrect,
    Color? noAnswer,
  }) {
    return ExtraColors(
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      correct: correct ?? this.correct,
      incorrect: incorrect ?? this.incorrect,
      noAnswer: noAnswer ?? this.noAnswer,
    );
  }

  @override
  ExtraColors lerp(ThemeExtension<ExtraColors>? other, double t) {
    if (other is! ExtraColors) return this;

    Color mix(Color a, Color b, double t) {
      final hsvA = HSVColor.fromColor(a);
      final hsvB = HSVColor.fromColor(b);
      return HSVColor.lerp(hsvA, hsvB, t)!.toColor();
    }

    return ExtraColors(
      shimmerBase: mix(shimmerBase, other.shimmerBase, t),
      shimmerHighlight: mix(shimmerHighlight, other.shimmerHighlight, t),
      correct: mix(correct, other.correct, t),
      incorrect: mix(incorrect, other.incorrect, t),
      noAnswer: mix(noAnswer, other.noAnswer, t),
    );
  }
}
