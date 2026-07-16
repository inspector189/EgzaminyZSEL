import 'package:flutter/material.dart';

class AdminTileData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const AdminTileData({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class AdminTile extends StatefulWidget {
  final AdminTileData data;

  const AdminTile({super.key, required this.data});

  @override
  State<AdminTile> createState() => _AdminTileState();
}

class _AdminTileState extends State<AdminTile> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (_hovered != value) {
      setState(() => _hovered = value);
    }
  }

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final scale = _pressed
        ? 0.97
        : _hovered
        ? 1.02
        : 1.0;

    return FocusableActionDetector(
      onShowHoverHighlight: _setHovered,
      onShowFocusHighlight: _setHovered,
      actions: {
        ActivateIntent: CallbackAction<Intent>(
          onInvoke: (_) {
            widget.data.onTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) {
          _setPressed(false);
          widget.data.onTap();
        },
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            height: 120,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: cs.onSurface.withValues(alpha: _hovered ? 0.2 : 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(widget.data.icon, size: 36, color: cs.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.data.label,
                    style: tt.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
