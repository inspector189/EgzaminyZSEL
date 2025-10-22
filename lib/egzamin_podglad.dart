import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

class EgzaminPodgladView extends StatelessWidget {
  final List<dynamic> questions;
  final List<String?> selectedAnswers;

  const EgzaminPodgladView({
    super.key,
    required this.questions,
    required this.selectedAnswers,
  });

  Html _html(BuildContext context, String html) {
    html = html.replaceAll('<img', '<br><img');
    html = html.replaceAll('<video', '<br><video');

    return Html(
      data: html,
      style: {
        'div.questionHeader': Style(
          color: Theme.of(context).colorScheme.primary,
          fontSize: FontSize(18),
          verticalAlign: VerticalAlign.middle,
        ),
        'div.question': Style(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: FontSize(16),
          verticalAlign: VerticalAlign.middle,
        ),
        'div.answer': Style(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: FontSize(14),
          verticalAlign: VerticalAlign.middle,
          textShadow: <Shadow>[
            Shadow(
              offset: Offset(3.0, 3.0),
              blurRadius: 2.0,
              color: Colors.black,
            ),
            Shadow(
              offset: Offset(1.0, 1.0),
              blurRadius: 2.0,
              color: Colors.black,
            ),
          ],
        ),
        'div.description.correct': Style(
          color: Colors.green,
          fontSize: FontSize(14),
          fontStyle: FontStyle.italic,
        ),
        'div.description.incorrect': Style(
          color: Colors.red,
          fontSize: FontSize(14),
          fontStyle: FontStyle.italic,
        ),
        'div.description.unselected': Style(
          color: Colors.amberAccent,
          fontSize: FontSize(14),
          fontStyle: FontStyle.italic,
        ),
        'b': Style(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          verticalAlign: VerticalAlign.middle,
        ),
        'div.media': Style(
          margin: Margins.symmetric(vertical: 12),
          textAlign: TextAlign.center,
        ),
      },
      extensions: [
        TagExtension(
          tagsToExtend: {'img'},
          builder: (extensionContext) {
            final src = extensionContext.attributes['src'];
            double? forcedHeight;
            final styleAttr = extensionContext.attributes['style'] ?? '';
            final m = RegExp(
              r'height\s*:\s*(\d+)\s*px',
              caseSensitive: false,
            ).firstMatch(styleAttr);
            if (m != null) {
              forcedHeight = double.tryParse(m.group(1)!);
            } else {
              final hAttr = extensionContext.attributes['height'];
              if (hAttr != null) forcedHeight = double.tryParse(hAttr);
            }

            if (src == null || src.isEmpty) {
              return Text(
                '⚠️ Brak obrazka',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: GestureDetector(
                    onTap: () => _showImageDialog(context, src),
                    child: Image.network(
                      src,
                      height: forcedHeight,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (context, error, stackTrace) => Text(
                            '❌ Nie udało się załadować obrazka',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Zamknij',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        final screenSize = MediaQuery.of(context).size;
        bool isPressed = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return GestureDetector(
              onTap: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Scaffold(
                backgroundColor: Colors.black.withValues(alpha: 0.9),
                body: Stack(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () {},
                        child: Listener(
                          onPointerDown:
                              (_) => setState(() => isPressed = true),
                          onPointerUp: (_) => setState(() => isPressed = false),
                          child: MouseRegion(
                            cursor:
                                isPressed
                                    ? SystemMouseCursors.grabbing
                                    : SystemMouseCursors.grab,
                            child: InteractiveViewer(
                              panEnabled: true,
                              minScale: 0.5,
                              maxScale: 4,
                              child: Image.network(
                                imageUrl,
                                width: screenSize.width * 0.8,
                                fit: BoxFit.contain,
                                errorBuilder:
                                    (context, error, stackTrace) => Text(
                                      '❌ Nie udało się załadować obrazka',
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 30,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        tooltip: 'Zamknij',
                        onPressed:
                            () =>
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Podgląd egzaminu")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) {
          final q = questions[index];
          final selected = selectedAnswers[index];
          final isCorrect = selected == q['poprawna'];

          final questionHtml =
              '<div class="questionHeader"><b>Pytanie ${index + 1}${q['id'] != null ? ' (ID ${q['id']})' : ''}:</b></div><br><div class="question">${q['pytanie']}</div>';

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _html(context, questionHtml),
                  const SizedBox(height: 10),
                  ...['A', 'B', 'C', 'D'].map((litera) {
                    final odp = q['odp${'ABCD'.indexOf(litera) + 1}'];
                    final isCorrectAnswer = litera == q['poprawna'];
                    final isSelected = selected == litera;
                    final isWrong = isSelected && !isCorrect;

                    Color? buttonColor;
                    if (isCorrectAnswer) {
                      buttonColor = Colors.green.withValues();
                    } else if (isWrong) {
                      buttonColor = Colors.red.withValues();
                    } else if (isSelected) {
                      buttonColor = Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.8);
                    } else {
                      buttonColor = Theme.of(context).colorScheme.surface;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                        ),
                        onPressed: () {},
                        child: _html(
                          context,
                          '<div class="answer">${odp ?? ""}</div>',
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                  if (selected != null)
                    _html(
                      context,
                      isCorrect
                          ? '<div class="description correct">✅ Odpowiedź $selected jest poprawna.<br>${q['opisPoprawne']}</div>'
                          : '<div class="description incorrect">❌ Odpowiedź $selected jest niepoprawna.<br>${q['opisNiepoprawne']}<br><div class="description correct">✅ Odpowiedź poprawna to: ${q['poprawna']}</div></div>',
                    ),
                  if (selected == null)
                    _html(
                      context,
                      '<div class="description unselected">⚠️ Nie wybrano odpowiedzi.<br><div class="description correct">✅ Odpowiedź poprawna to: ${q['poprawna']}</div></div>',
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
