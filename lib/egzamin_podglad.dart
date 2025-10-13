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

    return Html(
      data: html,
      style: {
        "body": Style(color: Theme.of(context).colorScheme.onSurface),
        "b": Style(color: Theme.of(context).colorScheme.onSurface),
        "span": Style(
          color:
              html.contains("style='color:green;'")
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurface,
        ),
      },
      extensions: [
        TagExtension(
          tagsToExtend: {'img'},
          builder: (extensionContext) {
            final src = extensionContext.attributes['src'];
            if (src != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Builder(
                  builder:
                      (context) => Center(
                        child: Tooltip(
                          message: 'Kliknij, aby powiększyć',
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => _showImageDialog(context, src),
                              child: Image.network(
                                src,
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
              );
            }
            return Text(
              '⚠️ Brak obrazka',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _html(
                    context,
                    "<b>Pytanie ${index + 1}:</b><br>${q['pytanie']}",
                  ),
                  const SizedBox(height: 10),
                  ...['A', 'B', 'C', 'D'].map((litera) {
                    final odp = q['odp${'ABCD'.indexOf(litera) + 1}'];
                    final isCorrectAnswer = litera == q['poprawna'];
                    final isSelected = selected == litera;

                    Color? buttonColor;
                    if (isCorrectAnswer) {
                      buttonColor = Colors.green;
                    } else if (isSelected && !isCorrect) {
                      buttonColor = Colors.red;
                    } else {
                      buttonColor = null;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor:
                              Theme.of(context).colorScheme.onSurface,
                        ),
                        onPressed: () {},
                        child: _html(context, odp ?? ""),
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                  if (selected != null)
                    _html(
                      context,
                      isCorrect
                          ? "<b>✅ Odpowiedź $selected jest poprawna.<br>${q['opisPoprawne']}</b>"
                          : "<b>❌ Odpowiedź $selected jest niepoprawna.<br>${q['opisNiepoprawne']}<br><br><span style='color:green;'>✅ Odpowiedź poprawna to: ${q['poprawna']}</span></b>",
                    ),
                  if (selected == null)
                    _html(
                      context,
                      "<b>⚠️ Nie wybrano odpowiedzi.<br><span style='color:green;'>✅ Odpowiedź poprawna to: ${q['poprawna']}</span></b>",
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
