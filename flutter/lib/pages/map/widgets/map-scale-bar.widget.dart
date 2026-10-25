import 'package:flutter/widgets.dart';

import '../../../constants/app-sizes.dart';
import '../../../constants/app-colors.dart';
import '../../../l10n/app_localizations.dart';

/// Displays a small metric scale HUD indicator for the current zoom level.
class MapScaleBar extends StatelessWidget {
  final double gridMetersStep;
  final double zoom;

  const MapScaleBar({
    super.key,
    required this.gridMetersStep,
    required this.zoom,
  });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final double pixelWidth = (this.gridMetersStep * this.zoom).clamp(40.0, 140.0);

    final String distanceLabel = (this.gridMetersStep >= 1000.0)
      ? l10n.mapScaleKilometers((this.gridMetersStep / 1000.0).toStringAsFixed(1))
      : l10n.mapScaleMeters(this.gridMetersStep.toStringAsFixed(0))
    ;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p8,
        vertical  : AppSizes.p4,
      ),
      decoration: BoxDecoration(
        color       : AppColors.surface(context).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppSizes.radius8),
        border      : Border.all(
          color: AppColors.border(context),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children    : [
          // Metric distance text
          Text(
            distanceLabel,
            style: TextStyle(
              fontSize  : AppSizes.font10,
              fontWeight: FontWeight.bold,
              color     : AppColors.textSecondary(context),
            ),
          ),

          // Spacing between text and scale ruler
          const SizedBox(height: AppSizes.p2),

          // Scale line with end brackets
          SizedBox(
            width : pixelWidth,
            height: AppSizes.p6,
            child : CustomPaint(
              painter: _ScaleBarLinePainter(
                lineColor: AppColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the bracketed scale line.
class _ScaleBarLinePainter extends CustomPainter {
  final Color lineColor;

  const _ScaleBarLinePainter({
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color       = this.lineColor
      ..strokeWidth = AppSizes.mapStrokeThin
      ..style       = PaintingStyle.stroke
    ;

    // Horizontal line
    canvas.drawLine(
      Offset(0.0, size.height),
      Offset(size.width, size.height),
      paint,
    );

    // Left tick
    canvas.drawLine(
      Offset(0.0, size.height),
      const Offset(0.0, 0.0),
      paint,
    );

    // Right tick
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, 0.0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScaleBarLinePainter oldDelegate) {
    return oldDelegate.lineColor != this.lineColor;
  }
}
