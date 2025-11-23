import 'package:flutter/material.dart';
import 'package:flutter_app/app_themes.dart';
import 'package:html_unescape/html_unescape.dart';
import 'utils/video_player.dart';
import 'utils/zoomable_image.dart';

class EgzaminPodgladView extends StatelessWidget {
  final List<dynamic> questions;
  final List<String?> selectedAnswers;

  const EgzaminPodgladView({
    super.key,
    required this.questions,
    required this.selectedAnswers,
  });

  Widget _buildQuestionCard(BuildContext context, int index) {
    final q = questions[index];
    final selected = selectedAnswers[index];
    final poprawna = q['poprawna']?.toString() ?? '';
    final colorScheme = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;
    final HtmlUnescape unescape = HtmlUnescape();

    final pytanieText = unescape.convert(q['pytanie']?.toString() ?? '');
    final List<String> pytanieImages =
        (q['images'] as List?)?.cast<String>() ?? [];
    final List<String> pytanieVideos =
        (q['videos'] as List?)?.cast<String>() ?? [];

    final List<_AnswerOption> options = List.generate(4, (i) {
      final key = 'odp${i + 1}';
      return _AnswerOption(
        letter: 'ABCD'[i],
        text: unescape.convert(q[key]?.toString() ?? ''),
        images: (q['${key}_images'] as List?)?.cast<String>() ?? [],
        videos: (q['${key}_videos'] as List?)?.cast<String>() ?? [],
        isCorrect: 'ABCD'[i] == poprawna,
        isSelected: selected == 'ABCD'[i],
      );
    });

    final bool isCorrect = selected == poprawna;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pytanie ${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),

            Text(pytanieText, style: const TextStyle(fontSize: 16)),
            ...pytanieImages.map(
              (url) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: buildZoomableImage(context, url),
              ),
            ),
            ...pytanieVideos.map(
              (url) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: InlineVideoPlayer(url: url),
              ),
            ),
            const SizedBox(height: 12),

            ...options.map(
              (opt) => _buildAnswerOption(context, opt, extras, colorScheme),
            ),

            const SizedBox(height: 8),
            if (selected != null)
              Text(
                isCorrect
                    ? 'Wybrano poprawną odpowiedź: $selected.'
                    : 'Wybrano niepoprawną odpowiedź: $selected.\nPoprawna odpowiedź: $poprawna.',
                style: TextStyle(
                  color: isCorrect ? extras.correct : extras.incorrect,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nie wybrano odpowiedzi.',
                    style: TextStyle(
                      color: extras.noAnswer,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  Text(
                    'Poprawna odpowiedź: $poprawna.',
                    style: TextStyle(
                      color: extras.correct,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),

            if (selected != null) ...[
              if (isCorrect &&
                  (q['opisPoprawne']?.toString().isNotEmpty ?? false))
                Text(
                  unescape.convert(q['opisPoprawne'].toString()),
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              if (!isCorrect &&
                  (q['opisNiepoprawne']?.toString().isNotEmpty ?? false))
                Text(
                  unescape.convert(q['opisNiepoprawne'].toString()),
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerOption(
    BuildContext context,
    _AnswerOption opt,
    ExtraColors extras,
    ColorScheme colorScheme,
  ) {
    final bool isResultOption =
        opt.isCorrect || (opt.isSelected && !opt.isCorrect);
    final Color textColor =
        isResultOption ? Colors.black : colorScheme.onSurface;
    final Color bgColor =
        opt.isCorrect
            ? extras.correct
            : (opt.isSelected && !opt.isCorrect)
            ? extras.incorrect
            : colorScheme.surface;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: bgColor,
          disabledForegroundColor: textColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          alignment: Alignment.centerLeft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(opt.text, style: TextStyle(fontSize: 15, color: textColor)),
            ...opt.images.map(
              (url) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: buildZoomableImage(context, url),
              ),
            ),
            ...opt.videos.map(
              (url) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: InlineVideoPlayer(url: url),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Podgląd egzaminu')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (c, i) => _buildQuestionCard(c, i),
      ),
    );
  }
}

class _AnswerOption {
  final String letter;
  final String text;
  final List<String> images;
  final List<String> videos;
  final bool isCorrect;
  final bool isSelected;

  _AnswerOption({
    required this.letter,
    required this.text,
    required this.images,
    required this.videos,
    required this.isCorrect,
    required this.isSelected,
  });
}
