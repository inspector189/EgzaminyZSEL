import 'package:flutter/material.dart';

class ShimBox extends StatelessWidget {
  const ShimBox({
    super.key,
    required this.w,
    required this.h,
    required this.cs,
    this.radius = 4,
  });
  final double w;
  final double h;
  final ColorScheme cs;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
