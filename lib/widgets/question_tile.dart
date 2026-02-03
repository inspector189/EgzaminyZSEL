import 'dart:async';
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
  final VoidCallback onTap;
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
  static final Map<String, _CacheEntry> _cache = {};

  static const _cacheTtl = Duration(minutes: 15);
  static const _baseUrl =
      'https://egzaminy.zsel.edu.pl/egzaminy/count/countQuestions.php';

  int? _count;
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  bool _isHovering = false;
  bool _isPressed = false;

  late final String _cacheKey;
  Future<void>? _currentLoadFuture;

  @override
  void initState() {
    super.initState();
    _cacheKey = widget.code.replaceAll('.', '').toLowerCase();

    if (widget.showCount) {
      _tryLoadFromCacheOrNetwork();
    }
  }

  void _tryLoadFromCacheOrNetwork() {
    final cached = _cache[_cacheKey];
    final now = DateTime.now();

    if (cached != null && cached.expiresAt.isAfter(now)) {
      setState(() {
        _count = cached.value;
        _isLoading = false;
        _hasError = false;
      });
      return;
    }

    if (_currentLoadFuture != null) return;

    _currentLoadFuture = _fetchCount();
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });
  }

  Future<void> _fetchCount() async {
    try {
      final uri = Uri.parse('$_baseUrl?egzamin=$_cacheKey');

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Żądanie wygasło po 10 sekundach');
            },
          );

      if (!mounted) return;

      if (response.statusCode != 200) {
        throw HttpException('Serwer zwrócił kod ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic> || !decoded.containsKey('count')) {
        throw const FormatException('Nieprawidłowy format odpowiedzi!');
      }

      final rawCount = decoded['count'];
      final parsedCount = switch (rawCount) {
        int count => count,
        String str => int.tryParse(str),
        _ => null,
      };

      if (parsedCount == null) {
        throw const FormatException(
          'Zwrócona wartość count nie jest prawidłowa!',
        );
      }

      _cache[_cacheKey] = _CacheEntry(
        value: parsedCount,
        expiresAt: DateTime.now().add(_cacheTtl),
      );

      if (!mounted) return;

      setState(() {
        _count = parsedCount;
        _isLoading = false;
        _hasError = false;
        _errorMessage = null;
      });
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('Widżet ($_cacheKey) napotkał błąd: $e\n$stack');
      }

      String userMessage = 'Nie udało się pobrać liczby pytań';
      if (e is TimeoutException) {
        userMessage = 'Przekroczono czas oczekiwania';
      } else if (e is FormatException) {
        userMessage = 'Błędna odpowiedź serwera';
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = userMessage;
      });
    } finally {
      _currentLoadFuture = null;
    }
  }

  Widget _buildCountArea(ColorScheme scheme, ExtraColors extras) {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: extras.shimmerBase,
        highlightColor: scheme.primary.withValues(alpha: 0.4),
        period: const Duration(milliseconds: 1400),
        child: const _LoadingPlaceholder(),
      );
    }

    if (_hasError) {
      return _ErrorState(
        message: _errorMessage ?? 'Wystąpił błąd',
        onRetry: _tryLoadFromCacheOrNetwork,
        scheme: scheme,
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
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return Text(
      '$_count ${_count == 1 ? "pytanie" : "pytań"}',
      style: TextStyle(
        fontSize: 12.5,
        color: scheme.onSurface.withValues(alpha: 0.75),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final itemWidth = screenWidth < 600 ? screenWidth - 40 : 300.0;

    final scale =
        _isPressed
            ? 0.97
            : _isHovering
            ? 1.025
            : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Card(
            elevation: _isHovering ? 6 : 3,
            shadowColor: scheme.shadow.withValues(
              alpha: _isHovering ? 0.25 : 0.18,
            ),
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
                    Icon(widget.icon, size: 44, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      widget.code,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (widget.showCount) ...[
                      const Spacer(),
                      _buildCountArea(scheme, extras),
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

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
        SizedBox(width: 8),
        Text('Ładowanie...', style: TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final ColorScheme scheme;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline_rounded, color: scheme.error, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            message,
            style: TextStyle(fontSize: 12, color: scheme.error),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Spróbuj ponownie', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

class _CacheEntry {
  final int value;
  final DateTime expiresAt;

  _CacheEntry({required this.value, required this.expiresAt});
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => message;
}
