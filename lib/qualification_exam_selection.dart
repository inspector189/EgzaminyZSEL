import 'package:flutter/material.dart';

import '/published_tests_view.dart';
import '/exam_solving.dart';
import '/question_editing.dart';

import "/services/oauth2_service.dart";
import '/widgets/question_tile.dart';

class QualificationExamSelectionPage extends StatelessWidget {
  const QualificationExamSelectionPage({
    super.key,
    required this.qualification,
    required this.isAdmin,
    required this.isLoggedIn,
  });

  final String qualification;
  final bool isAdmin;
  final bool isLoggedIn;

  String get _sanitized => qualification.toLowerCase().replaceAll('.', '');

  String get _display => qualification.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final route = ModalRoute.of(context);
    final args = route?.settings.arguments;
    final returnToHome =
        args is Map<String, dynamic> && args['returnToHome'] == true;

    final screenWidth = MediaQuery.of(context).size.width;
    const double kMaxContent = 880.0;
    final double contentWidth = screenWidth < 600
        ? screenWidth - 32
        : (screenWidth * 0.85).clamp(0.0, kMaxContent);
    final double hPad = ((screenWidth - contentWidth) / 2).clamp(
      16.0,
      double.infinity,
    );

    final itemWidth = screenWidth < 600 ? screenWidth - 40 : 300.0;
    final isWide = screenWidth >= 800 && isAdmin;

    final practiceTileBuilders = <Widget Function(double tileWidth)>[
      (w) => SizedBox(
        width: w,
        child: QuestionTile(
          icon: Icons.casino_rounded,
          code: 'Losuj 1 pytanie',
          label: 'Sprawdź swoją wiedzę',
          showCount: false,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EgzaminView(
                tryb: TrybEgzaminu.singleQuestion,
                kwalifikacja: _sanitized,
                returnToHome: false,
              ),
            ),
          ),
        ),
      ),
      (w) => SizedBox(
        width: w,
        child: QuestionTile(
          icon: Icons.list_alt_rounded,
          code: 'Test 40 pytań',
          label: 'Pełny egzamin próbny',
          showCount: false,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EgzaminView(
                tryb: TrybEgzaminu.normalTest,
                kwalifikacja: _sanitized,
                returnToHome: false,
              ),
            ),
          ),
        ),
      ),
      (w) => SizedBox(
        width: w,
        child: QuestionTile(
          icon: Icons.library_books_rounded,
          code: 'Baza pytań',
          label: 'Przeglądaj wszystkie pytania',
          showCount: false,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EgzaminView(
                tryb: TrybEgzaminu.allQuestions,
                kwalifikacja: _sanitized,
                returnToHome: false,
              ),
            ),
          ),
        ),
      ),
      (w) => SizedBox(
        width: w,
        child: QuestionTile(
          icon: Icons.assignment_turned_in_rounded,
          code: 'Testy nauczyciela',
          label: 'Opublikowane zestawy pytań',
          showCount: false,
          isLocked: !isLoggedIn,
          onTap: () => isLoggedIn
              ? Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PublishedTestsPage(qualification: _sanitized),
                  ),
                )
              : LoginGateBottomSheet.show(context),
        ),
      ),
    ];

    final practiceSection = _Section(
      label: 'Ćwicz',
      cs: cs,
      tt: tt,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          const double spacing = 16;
          const int columns = 2;
          final int cols = constraints.maxWidth < 360 ? 1 : columns;
          final double tileWidth =
              (constraints.maxWidth - spacing * (cols - 1)) / cols;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: practiceTileBuilders
                .map((builder) => builder(tileWidth))
                .toList(),
          );
        },
      ),
    );

    final adminSection = isAdmin
        ? _Section(
            label: 'Zarządzanie',
            cs: cs,
            tt: tt,
            accent: cs.tertiary,
            child: Center(
              child: SizedBox(
                width: itemWidth,
                child: QuestionTile(
                  icon: Icons.edit_note_rounded,
                  code: 'Edytuj pytania',
                  label: 'Zarządzaj bazą egzaminów',
                  showCount: false,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EditQuestionsPage(qualification: _sanitized),
                    ),
                  ),
                ),
              ),
            ),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_display),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        iconTheme: IconThemeData(color: cs.onPrimary),
        leading: returnToHome
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 32),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: practiceSection),
                  Container(
                    width: 1,
                    height: 600,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                  SizedBox(width: itemWidth + 40, child: adminSection!),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  practiceSection,
                  if (adminSection != null) ...[
                    const SizedBox(height: 32),
                    Divider(color: cs.outlineVariant.withValues(alpha: 0.4)),
                    const SizedBox(height: 20),
                    adminSection,
                  ],
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//          Login Gate Bottom Sheet
// ─────────────────────────────────────────────

class LoginGateBottomSheet extends StatelessWidget {
  const LoginGateBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const LoginGateBottomSheet(),
    );
  }

  Future<void> _startLogin(BuildContext context) async {
    Navigator.pop(context);
    try {
      OAuth2Service.startLogin();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd logowania: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 28,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Wymagane logowanie',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Aby rozwiązywać testy od nauczycieli,\nmusisz być zalogowany przy pomocy maila '
            'z domeną @zselektr.onmicrosoft.com.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _startLogin(context),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Zaloguj się'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//          Section wrapper with label
// ─────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.cs,
    required this.tt,
    required this.child,
    this.accent,
  });
  final String label;
  final ColorScheme cs;
  final TextTheme tt;
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? cs.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label.toUpperCase(),
              style: tt.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
