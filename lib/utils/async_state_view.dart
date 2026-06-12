import 'package:flutter/material.dart';

enum _AsyncStateType { loading, empty, error }

class AsyncStateView extends StatelessWidget {
  final _AsyncStateType _type;
  final String message;
  final String? subtitle;
  final IconData icon;

  const AsyncStateView._({
    required _AsyncStateType type,
    required this.message,
    required this.icon,
    this.subtitle,
  }) : _type = type;

  factory AsyncStateView.loading({
    String message = 'Ładowanie...',
    String? subtitle,
  }) => AsyncStateView._(
    type: _AsyncStateType.loading,
    message: message,
    icon: Icons.hourglass_empty_rounded,
    subtitle: subtitle,
  );

  factory AsyncStateView.empty({
    String message = 'Brak danych',
    String? subtitle,
    IconData icon = Icons.inbox_outlined,
  }) => AsyncStateView._(
    type: _AsyncStateType.empty,
    message: message,
    icon: icon,
    subtitle: subtitle,
  );

  factory AsyncStateView.error({
    required String message,
    String? subtitle,
    IconData icon = Icons.error_outline_rounded,
  }) => AsyncStateView._(
    type: _AsyncStateType.error,
    message: message,
    icon: icon,
    subtitle: subtitle,
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);

    final double scale = (size.width / 400).clamp(0.8, 1.4);

    final double cardSize = 200 * scale;

    final Color borderColor = switch (_type) {
      _AsyncStateType.loading => colorScheme.primary.withValues(alpha: 0.35),
      _AsyncStateType.empty => colorScheme.outlineVariant,
      _AsyncStateType.error => colorScheme.error.withValues(alpha: 0.45),
    };

    final Color iconBg = colorScheme.surfaceContainerHighest;
    final Color iconFg = switch (_type) {
      _AsyncStateType.loading => colorScheme.primary,
      _AsyncStateType.empty => colorScheme.onSurfaceVariant,
      _AsyncStateType.error => colorScheme.error,
    };

    final double iconCircle = 52 * scale;
    final double iconSize = 24 * scale;
    final double spinnerPad = 13 * scale;
    final double gap = 14 * scale;
    final double smallGap = 6 * scale;

    return Center(
      child: SizedBox(
        width: cardSize,
        height: cardSize,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: iconCircle,
                height: iconCircle,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: _type == _AsyncStateType.loading
                    ? Padding(
                        padding: EdgeInsets.all(spinnerPad),
                        child: CircularProgressIndicator(
                          strokeWidth: 5,
                          color: iconFg,
                        ),
                      )
                    : Icon(icon, color: iconFg, size: iconSize),
              ),
              SizedBox(height: gap),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                child: Text(
                  message,
                  style: (textTheme.titleSmall ?? const TextStyle()).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14 * scale,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: smallGap),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                  child: Text(
                    subtitle!,
                    style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12 * scale,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
