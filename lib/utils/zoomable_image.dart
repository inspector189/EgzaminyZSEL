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
        showGeneralDialog;
import 'package:flutter_app/app_themes.dart' show ExtraColors;
import 'package:shimmer/shimmer.dart' show Shimmer;

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
    barrierLabel: 'Close',
    pageBuilder:
        (c, a1, a2) => Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 1.0,
            maxScale: 5.0,
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
    transitionBuilder:
        (c, a1, a2, child) => FadeTransition(opacity: a1, child: child),
    transitionDuration: const Duration(milliseconds: 300),
  );
}
