import 'package:flutter/material.dart';
import 'package:html_unescape_xx/html_unescape.dart';

import 'utils/app_themes.dart';
import 'widgets/exam_question_card.dart';

String _stripAnswerPrefix(String text) =>
    text.replaceFirst(RegExp(r'^\s*[A-Da-d][.)]\s*'), '').trimLeft();

class ExamPreviewPage extends StatelessWidget {
  final List<dynamic> questions;
  final List<String?> selectedAnswers;

  const ExamPreviewPage({
    super.key,
    required this.questions,
    required this.selectedAnswers,
  });

  // ── Card ───────────────────────────────────

  Widget _buildQuestionCard(BuildContext context, int index) {
    final q = questions[index];
    final selected = selectedAnswers[index];
    final poprawna = q['poprawna']?.toString() ?? '';
    final cs = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;
    final unescape = HtmlUnescapeSmall();

    final Color accent = selected == null
        ? cs.primary
        : selected == poprawna
        ? extras.correct
        : extras.incorrect;

    final answers = List.generate(4, (i) {
      final letter = 'ABCD'[i];
      final key = 'odp${i + 1}';
      return ExamAnswerState(
        letter: letter,
        text: _stripAnswerPrefix(unescape.convert(q[key]?.toString() ?? '')),
        images: (q['${key}_images'] as List?)?.cast<String>() ?? [],
        videos: (q['${key}_videos'] as List?)?.cast<String>() ?? [],
        isCorrect: letter == poprawna,
        isSelected: selected == letter,
      );
    });

    return ExamQuestionCard(
      label: 'Pytanie ${index + 1}',
      questionText: unescape.convert(q['pytanie']?.toString() ?? ''),
      questionImages: (q['images'] as List?)?.cast<String>() ?? [],
      questionVideos: (q['videos'] as List?)?.cast<String>() ?? [],
      answers: answers,
      accentColor: accent,
      showResult: true,
      headerTrailing: selected != null
          ? _ResultPill(correct: selected == poprawna, extras: extras)
          : null,
      resultBanner: _buildResultBanner(
        context,
        selected,
        poprawna,
        q,
        extras,
        cs,
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
    final unescape = HtmlUnescapeSmall();

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
    final color = isCorrect ? extras.correct : extras.incorrect;
    final icon = isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final label = isCorrect
        ? 'Wybrano poprawną odpowiedź: $selected.'
        : 'Niepoprawna: $selected.  Poprawna: $poprawna.';

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
