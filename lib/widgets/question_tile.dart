import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import '../app_themes.dart';

class QuestionTile extends StatefulWidget {
  final IconData icon;
  final String code;
  final String label;
  final Function(String) onTap;
  final bool showCount;

  const QuestionTile({
    super.key,
    required this.icon,
    required this.code,
    required this.label,
    required this.onTap,
    this.showCount = true,
  });

  @override
  State<QuestionTile> createState() => _QuestionTileState();
}

class _QuestionTileState extends State<QuestionTile> {
  static final Map<String, int?> _cache = {};
  int? _count;
  bool _loading = false;
  bool _error = false;

  bool _hovering = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.showCount) {
      _loading = true;
      _loadCount();
    }
  }

  Future<void> _loadCount() async {
    if (_cache.containsKey(widget.code)) {
      _count = _cache[widget.code];
      _loading = false;
      return;
    }

    setState(() {
      _error = false;
    });

    try {
      final sanitized = widget.code.replaceAll('.', '').toLowerCase();
      final url = Uri.parse(
        'https://egzaminy.zsel.edu.pl/egzaminy/count/countQuestions.php?egzamin=$sanitized',
      );

      if (kDebugMode) debugPrint('Requesting: $url');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('count')) {
          _count = data['count'] as int;
          _cache[widget.code] = _count;
        } else {
          _error = true;
        }
      } else {
        _error = true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error fetching count: $e');
      _error = true;
    }

    if (mounted) setState(() => _loading = false);
  }

  Widget _countWidget(ColorScheme colorScheme, ExtraColors extras) {
    if (_loading) {
      return Shimmer.fromColors(
        baseColor: extras.shimmerBase,
        highlightColor: colorScheme.primary,
        period: const Duration(milliseconds: 1500),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Ładowanie...', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    if (_error) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.close_rounded, color: colorScheme.error, size: 20),
          const SizedBox(width: 4),
          Text(
            'Wystąpił błąd',
            style: TextStyle(fontSize: 12, color: colorScheme.error),
          ),
        ],
      );
    }

    if (_count != null && _count! > 0) {
      return Text(
        '$_count pytań',
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.warning_rounded, color: extras.noAnswer, size: 20),
        const SizedBox(width: 4),
        Text(
          'Brak pytań',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth < 600 ? screenWidth - 40 : 300.0;

    double scale = 1.0;
    if (_hovering) scale = 1.02;
    if (_pressed) scale = 0.97;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap(widget.code);
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            width: itemWidth,
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.onSurface.withValues(
                    alpha: _hovering ? 0.2 : 0.15,
                  ),
                  blurRadius: _hovering ? 12 : 8,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 40, color: colorScheme.primary),
                const SizedBox(height: 14),
                Text(
                  widget.code,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                if (widget.showCount) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _countWidget(colorScheme, extras),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
