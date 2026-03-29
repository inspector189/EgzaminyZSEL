import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'utils/app_themes.dart';
import 'widgets/video_player.dart';
import 'widgets/zoomable_image.dart';

// ─────────────────────────────────────────────
//  Design tokens — shared with egzamin_view
// ─────────────────────────────────────────────

const double _minImageHeight = 100;
const double _maxImageHeight = 500;
const double _kCardRadius    = 12.0;
const double _kAccentWidth   = 4.0;

String _stripAnswerPrefix(String text) =>
    text.replaceFirst(RegExp(r'^\s*[A-Da-d][.)]\s*'), '').trimLeft();

// ─────────────────────────────────────────────

class EgzaminPodgladView extends StatelessWidget {
  final List<dynamic> questions;
  final List<String?> selectedAnswers;

  const EgzaminPodgladView({
    super.key,
    required this.questions,
    required this.selectedAnswers,
  });

  // ── Card ───────────────────────────────────

  Widget _buildQuestionCard(BuildContext context, int index) {
    final q        = questions[index];
    final selected = selectedAnswers[index];
    final poprawna = q['poprawna']?.toString() ?? '';
    final cs       = Theme.of(context).colorScheme;
    final extras   = Theme.of(context).extension<ExtraColors>()!;
    final unescape = HtmlUnescape();

    final pytanieText   = unescape.convert(q['pytanie']?.toString() ?? '');
    final pytanieImages = (q['images']  as List?)?.cast<String>() ?? <String>[];
    final pytanieVideos = (q['videos']  as List?)?.cast<String>() ?? <String>[];

    // Accent: correct=green, wrong=red, unanswered=primary
    final Color accent;
    if (selected == null) {
      accent = cs.primary;
    } else if (selected == poprawna) {
      accent = extras.correct;
    } else {
      accent = extras.incorrect;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Left accent bar
          Positioned(
            top: 0, bottom: 0, left: 0,
            width: _kAccentWidth,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft:    Radius.circular(_kCardRadius),
                bottomLeft: Radius.circular(_kCardRadius),
              ),
              child: ColoredBox(color: accent),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(_kAccentWidth + 12, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Pytanie ${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Result pill
                    if (selected != null)
                      _ResultPill(
                        correct: selected == poprawna,
                        extras: extras,
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Question text ────────────────────────────────
                Text(
                  pytanieText,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                ...pytanieImages.map((url) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: _minImageHeight,
                        maxHeight: _maxImageHeight,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: buildZoomableImage(context, url),
                      ),
                    ),
                  ),
                )),

                ...pytanieVideos.map((url) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 400,
                    child: InlineVideoPlayer(url: url, height: 400),
                  ),
                )),

                const SizedBox(height: 12),

                // ── Answer tiles ─────────────────────────────────
                ...List.generate(4, (i) {
                  final letter    = 'ABCD'[i];
                  final key       = 'odp${i + 1}';
                  final rawText   = unescape.convert(q[key]?.toString() ?? '');
                  final text      = _stripAnswerPrefix(rawText);
                  final images    = (q['${key}_images'] as List?)?.cast<String>() ?? <String>[];
                  final videos    = (q['${key}_videos'] as List?)?.cast<String>() ?? <String>[];
                  final isCorrect = letter == poprawna;
                  final isSelected = selected == letter;

                  return _buildAnswerTile(
                    context,
                    letter:     letter,
                    text:       text,
                    images:     images,
                    videos:     videos,
                    isCorrect:  isCorrect,
                    isSelected: isSelected,
                    extras:     extras,
                    cs:         cs,
                  );
                }),

                // ── Result banner ────────────────────────────────
                const SizedBox(height: 4),
                _buildResultBanner(context, selected, poprawna, q, extras, cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Answer tile — same style as egzamin_view, but always shows result ──

  Widget _buildAnswerTile(
    BuildContext context, {
    required String letter,
    required String text,
    required List<String> images,
    required List<String> videos,
    required bool isCorrect,
    required bool isSelected,
    required ExtraColors extras,
    required ColorScheme cs,
  }) {
    final Color borderColor;
    final Color bgColor;
    final Color circleColor;
    final Color textColor;
    Widget? trailingIcon;

    if (isCorrect) {
      borderColor  = extras.correct.withValues(alpha: 0.6);
      bgColor      = extras.correct.withValues(alpha: 0.12);
      circleColor  = extras.correct;
      textColor    = cs.onSurface;
      trailingIcon = Icon(Icons.check_circle_rounded, size: 16, color: extras.correct);
    } else if (isSelected) {
      // Selected but wrong
      borderColor  = extras.incorrect.withValues(alpha: 0.6);
      bgColor      = extras.incorrect.withValues(alpha: 0.10);
      circleColor  = extras.incorrect;
      textColor    = cs.onSurface;
      trailingIcon = Icon(Icons.cancel_rounded, size: 16, color: extras.incorrect);
    } else {
      borderColor = cs.outlineVariant.withValues(alpha: 0.28);
      bgColor     = cs.surfaceContainerHighest.withValues(alpha: 0.35);
      circleColor = cs.outlineVariant.withValues(alpha: 0.3);
      textColor   = cs.onSurfaceVariant;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: (isSelected || isCorrect) ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Letter circle
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isCorrect ? cs.surface : cs.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: textColor,
                    fontWeight: (isSelected || isCorrect)
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                ...images.map((url) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: _minImageHeight,
                        maxHeight: _maxImageHeight,
                      ),
                      child: buildZoomableImage(context, url),
                    ),
                  ),
                )),
                ...videos.map((url) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 400,
                    child: InlineVideoPlayer(url: url, height: 400),
                  ),
                )),
              ],
            ),
          ),
          if (trailingIcon != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 3),
              child: trailingIcon,
            ),
        ],
      ),
    );
  }

  // ── Result banner (correct/incorrect/unanswered) ──

  Widget _buildResultBanner(
    BuildContext context,
    String? selected,
    String poprawna,
    dynamic q,
    ExtraColors extras,
    ColorScheme cs,
  ) {
    final unescape = HtmlUnescape();

    if (selected == null) {
      // Unanswered
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: extras.noAnswer.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: extras.noAnswer.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.help_outline_rounded, size: 15, color: extras.noAnswer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nie wybrano odpowiedzi.  Poprawna: $poprawna.',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: extras.noAnswer,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isCorrect = selected == poprawna;
    final color     = isCorrect ? extras.correct : extras.incorrect;
    final icon      = isCorrect
        ? Icons.check_circle_rounded
        : Icons.cancel_rounded;
    final label     = isCorrect
        ? 'Wybrano poprawną odpowiedź: $selected.'
        : 'Niepoprawna: $selected.  Poprawna: $poprawna.';

    // Optional explanation text
    final String? explanation = isCorrect
        ? (q['opisPoprawne']?.toString().trim().isNotEmpty == true
            ? unescape.convert(q['opisPoprawne'].toString())
            : null)
        : (q['opisNiepoprawne']?.toString().trim().isNotEmpty == true
            ? unescape.convert(q['opisNiepoprawne'].toString())
            : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (explanation != null) ...[
            const SizedBox(height: 6),
            Text(
              explanation,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Podgląd egzaminu'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        iconTheme: IconThemeData(color: cs.onPrimary),
      ),
      backgroundColor: cs.surfaceContainerLowest,
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (c, i) => _buildQuestionCard(c, i),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Small result pill shown in the card header
// ─────────────────────────────────────────────

class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.correct, required this.extras});
  final bool correct;
  final ExtraColors extras;

  @override
  Widget build(BuildContext context) {
    final color = correct ? extras.correct : extras.incorrect;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            correct ? Icons.check_rounded : Icons.close_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            correct ? 'POPRAWNA' : 'BŁĘDNA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}