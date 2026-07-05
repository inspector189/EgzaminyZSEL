import 'dart:typed_data';

import 'package:flutter/material.dart';

import '/utils/app_themes.dart';
import '/widgets/inline_video_player.dart';
import '/widgets/zoomable_image.dart';

const double _kCardRadius = 12.0;
const double _kAccentWidth = 4.0;

class ExamAnswerState {
  final String letter;
  final String text;
  final List<String> images;
  final List<String> videos;
  final bool isCorrect;
  final bool isSelected;
  final Uint8List? localImageBytes;

  const ExamAnswerState({
    required this.letter,
    required this.text,
    required this.images,
    required this.videos,
    required this.isCorrect,
    required this.isSelected,
    this.localImageBytes,
  });
}

class ExamQuestionCard extends StatelessWidget {
  const ExamQuestionCard({
    super.key,
    required this.label,
    required this.questionText,
    required this.questionImages,
    required this.questionVideos,
    required this.answers,
    required this.accentColor,
    // Optional slots
    this.headerTrailing,
    this.onAnswerTap,
    this.showResult = false,
    this.resultBanner,
    this.bottomRow,
    this.backgroundColor,
    this.shadowAlpha = 0.06,
    this.questionLocalImageBytes,
  });

  final String label;
  final String questionText;
  final List<String> questionImages;
  final List<String> questionVideos;
  final List<ExamAnswerState> answers;
  final Color accentColor;

  final Widget? headerTrailing;
  final void Function(String letter)? onAnswerTap;
  final bool showResult;
  final Widget? resultBanner;
  final Widget? bottomRow;
  final Color? backgroundColor;
  final double shadowAlpha;
  final List<Uint8List>? questionLocalImageBytes;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final extras = Theme.of(context).extension<ExtraColors>()!;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.surface,
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: shadowAlpha),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: _kAccentWidth,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(_kCardRadius),
                bottomLeft: Radius.circular(_kCardRadius),
              ),
              child: ColoredBox(color: accentColor),
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
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    ?headerTrailing,
                  ],
                ),
                const SizedBox(height: 10),

                // ── Question text + media ────────────────────────
                if (questionText.isNotEmpty)
                  Text(
                    questionText,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: cs.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ...questionImages.map(
                  (url) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: buildZoomableImage(context, url),
                    ),
                  ),
                ),
                ...?questionLocalImageBytes?.map(
                  (bytes) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
                ...questionVideos.map(
                  (url) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: InlineVideoPlayer.network(url, height: 400),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Answer tiles ─────────────────────────────────
                ...answers.map((a) => _buildAnswerTile(context, a, cs, extras)),

                // ── Result banner ────────────────────────────────
                if (resultBanner != null) ...[
                  const SizedBox(height: 8),
                  resultBanner!,
                ],

                // ── Bottom row (actions etc.) ────────────────────
                if (bottomRow != null) ...[
                  const Divider(height: 16),
                  bottomRow!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerTile(
    BuildContext context,
    ExamAnswerState a,
    ColorScheme cs,
    ExtraColors extras,
  ) {
    final Color borderColor;
    final Color bgColor;
    final Color circleColor;
    final Color textColor;
    Widget? trailingIcon;

    if (showResult) {
      if (a.isCorrect) {
        borderColor = extras.correct.withValues(alpha: 0.6);
        bgColor = extras.correct.withValues(alpha: 0.12);
        circleColor = extras.correct;
        textColor = cs.onSurface;
        trailingIcon = Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: extras.correct,
        );
      } else if (a.isSelected) {
        borderColor = extras.incorrect.withValues(alpha: 0.6);
        bgColor = extras.incorrect.withValues(alpha: 0.10);
        circleColor = extras.incorrect;
        textColor = cs.onSurface;
        trailingIcon = Icon(
          Icons.cancel_rounded,
          size: 16,
          color: extras.incorrect,
        );
      } else {
        borderColor = cs.outlineVariant.withValues(alpha: 0.28);
        bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.35);
        circleColor = cs.outlineVariant.withValues(alpha: 0.3);
        textColor = cs.onSurfaceVariant;
      }
    } else if (a.isSelected) {
      borderColor = cs.primary.withValues(alpha: 0.6);
      bgColor = cs.primary.withValues(alpha: 0.10);
      circleColor = cs.primary;
      textColor = cs.onSurface;
    } else {
      borderColor = cs.outlineVariant.withValues(alpha: 0.28);
      bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.42);
      circleColor = cs.outlineVariant.withValues(alpha: 0.3);
      textColor = cs.onSurfaceVariant;
    }

    return GestureDetector(
      onTap: (showResult || onAnswerTap == null)
          ? null
          : () => onAnswerTap!(a.letter),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: (a.isSelected || (showResult && a.isCorrect)) ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                a.letter,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: a.isSelected ? cs.surface : cs.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: textColor,
                      fontWeight: (a.isSelected || (showResult && a.isCorrect))
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  ...a.images.map(
                    (url) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: buildZoomableImage(context, url),
                    ),
                  ),
                  if (a.localImageBytes != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          a.localImageBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ...a.videos.map(
                    (url) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: InlineVideoPlayer.network(url, height: 400),
                    ),
                  ),
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
      ),
    );
  }
}
