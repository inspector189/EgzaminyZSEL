import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/utils/app_themes.dart';
import 'package:shimmer/shimmer.dart';

const double imageZoomScale = 1.75;

Widget buildZoomableImage(BuildContext context, String url) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      return GestureDetector(
        onTap: () => _showZoomedImage(context, url),
        child: Center(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.fitWidth,
            placeholder: (_, _) => _buildImagePlaceholder(context, maxWidth),
            errorBuilder: (_, _, _) =>
                _buildImagePlaceholder(context, maxWidth, error: true),
          ),
        ),
      );
    },
  );
}

Widget _buildImagePlaceholder(
  BuildContext context,
  double width, {
  bool error = false,
}) {
  final extras = Theme.of(context).extension<ExtraColors>()!;
  final cs = Theme.of(context).colorScheme;

  if (error) {
    return Container(
      width: width,
      height: 72,
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.error.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: cs.error.withValues(alpha: 0.6),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Nie udało się załadować obrazu',
            style: TextStyle(
              fontSize: 12,
              color: cs.onErrorContainer.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  return Shimmer.fromColors(
    baseColor: extras.shimmerBase,
    highlightColor: extras.shimmerHighlight,
    period: const Duration(milliseconds: 900),
    child: Container(
      width: width,
      height: 120,
      decoration: BoxDecoration(
        color: extras.shimmerBase,
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}

void _showZoomedImage(BuildContext context, String url) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Zamknij',
    barrierColor: Colors.black.withValues(alpha: 0.92),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) {
      return _ZoomedImageViewer(imageUrl: url);
    },
    transitionBuilder: (context, animation, _, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _ZoomedImageViewer extends StatelessWidget {
  final String imageUrl;

  const _ZoomedImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final double targetWidth = size.width * imageZoomScale;
    final double targetHeight = size.height * imageZoomScale;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  width: targetWidth,
                  height: targetHeight,
                  placeholder: (_, _) => Container(
                    width: targetWidth,
                    height: targetHeight,
                    color: const Color(0xFF111111),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white70),
                    ),
                  ),
                  errorBuilder: (_, _, _) => Container(
                    width: targetWidth,
                    height: targetHeight,
                    color: const Color(0xFF111111),
                    child: const Icon(
                      Icons.error,
                      color: Colors.white70,
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
