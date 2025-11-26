import 'package:cached_network_image/cached_network_image.dart'
    show CachedNetworkImage;
import 'package:flutter/material.dart'
    show
        Widget,
        BuildContext,
        BoxFit,
        Center,
        GestureDetector,
        LayoutBuilder,
        Theme,
        BorderRadius,
        BoxDecoration,
        Icons,
        Icon,
        Container,
        Image,
        InteractiveViewer,
        FadeTransition,
        Colors,            
        Navigator,          
        Padding,           
        ClipRRect,        
        Transform,      
        Duration,        
        Material,  
        CircularProgressIndicator;

import 'package:flutter/widgets.dart';
import 'package:flutter_app/app_themes.dart' show ExtraColors;
import 'package:shimmer/shimmer.dart' show Shimmer;

const double imageZoomScale = 1.75;

Widget buildZoomableImage(BuildContext context, String url) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final maxWidth = constraints.maxWidth - 300;
      return GestureDetector(
        onTap: () => _showZoomedImage(context, url),
        child: Center(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, _) => _buildImagePlaceholder(context, maxWidth),
            errorWidget:
                (_, _, _) =>
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
  return Container(
    width: width,
    decoration: BoxDecoration(
      color: error ? extras.shimmerBase : extras.shimmerHighlight,
      borderRadius: BorderRadius.circular(8),
    ),
    child:
        error
            ? Icon(Icons.broken_image, color: extras.shimmerHighlight)
            : Shimmer.fromColors(
              baseColor: extras.shimmerBase,
              highlightColor: extras.shimmerHighlight,
              child: Container(
                decoration: BoxDecoration(
                  color: extras.shimmerBase,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
  );
}

void _showZoomedImage(BuildContext context, String url) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Zamknij',
    barrierColor: Colors.black.withOpacity(0.92),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, __) {
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
                  placeholder: (_, __) => Container(
                    width: targetWidth,
                    height: targetHeight,
                    color: const Color(0xFF111111),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white70),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: targetWidth,
                    height: targetHeight,
                    color: const Color(0xFF111111),
                    child: const Icon(Icons.error, color: Colors.white70, size: 60),
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