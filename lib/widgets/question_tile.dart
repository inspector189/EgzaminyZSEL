import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '/services/api_service.dart';
import '/utils/app_themes.dart';

class QuestionTile extends StatefulWidget {
  final IconData icon;
  final String code;
  final String label;
  final VoidCallback onTap;
  final bool showCount;
  final bool isLocked;

  const QuestionTile({
    super.key,
    required this.icon,
    required this.code,
    required this.label,
    required this.onTap,
    this.showCount = true,
    this.isLocked = false,
  });

  @override
  State<QuestionTile> createState() => _QuestionTileState();
}

class _QuestionTileState extends State<QuestionTile> {
  int? _count;
  bool _isLoading = false;
  bool _hasError = false;
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.showCount) _load();
  }

  String get _cacheKey => widget.code.replaceAll('.', '').toLowerCase();

  Future<void> _load() async {
    if (_isLoading) return;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final result = await ApiService.instance.fetchQuestionCount(_cacheKey);
      if (!mounted) return;
      if (result.isSuccess) {
        setState(() {
          _count = result.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Widget _buildCountArea(ColorScheme cs, ExtraColors extras) {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: extras.shimmerBase,
        highlightColor: cs.primary.withValues(alpha: 0.4),
        period: const Duration(milliseconds: 1400),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            SizedBox(width: 8),
            Text('Ładowanie...', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    if (_hasError) {
      return GestureDetector(
        onTap: _load,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: cs.error, size: 15),
            const SizedBox(width: 5),
            Padding(
              padding: EdgeInsetsGeometry.all(2),
              child: Text(
                'Błąd — dotknij, aby ponowić',
                style: TextStyle(fontSize: 11, color: cs.error),
              ),
            ),
          ],
        ),
      );
    }

    if (_count == null || _count == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: extras.noAnswer, size: 18),
          const SizedBox(width: 6),
          Text(
            'Brak pytań',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      );
    }

    return Text(
      '$_count ${_count == 1 ? "pytanie" : "pytań"}',
      style: TextStyle(
        fontSize: 12.5,
        color: cs.onSurface.withValues(alpha: 0.75),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final itemWidth = screenWidth < 600 ? screenWidth - 40 : 300.0;

    final scale = _isPressed
        ? 0.97
        : (_isHovering && !widget.isLocked)
        ? 1.025
        : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTapDown: (_) {
          if (!widget.isLocked) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          if (!widget.isLocked) widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Card(
            elevation: _isHovering && !widget.isLocked ? 6 : 3,
            color: cs.surfaceContainerHighest,
            shadowColor: cs.shadow.withValues(alpha: _isHovering ? 0.25 : 0.18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: itemWidth,
              height: 220,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          widget.icon,
                          size: 44,
                          color: widget.isLocked
                              ? cs.onSurface.withValues(alpha: 0.3)
                              : cs.primary,
                        ),
                        if (widget.isLocked)
                          Positioned(
                            right: -6,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_outline_rounded,
                                size: 13,
                                color: cs.outline,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.code,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.isLocked
                            ? cs.onSurface.withValues(alpha: 0.4)
                            : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (widget.showCount) ...[
                      const Spacer(),
                      _buildCountArea(cs, extras),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
