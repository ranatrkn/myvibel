// Maskot karesi etrafında seviye gelişim çubuğu.
import 'package:flutter/material.dart';

/// Maskot görselini kare bir çerçeve içine alır; çerçeve gelişim oranına göre dolur.
class MascotGelisimCercevesi extends StatelessWidget {
  const MascotGelisimCercevesi({
    super.key,
    required this.progress,
    required this.size,
    required this.child,
    this.strokeWidth = 4,
    this.innerPadding = 4,
    this.progressColor = Colors.blueAccent,
    this.backgroundColor,
    this.borderRadius = 20,
    this.backgroundFill,
  });

  final double progress;
  final double size;
  final Widget child;
  final double strokeWidth;
  final double innerPadding;
  final Color progressColor;
  final Color? backgroundColor;
  final double borderRadius;
  final Color? backgroundFill;

  @override
  Widget build(BuildContext context) {
    final kenar = strokeWidth + innerPadding;
    final icBoyut = size - kenar * 2;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KareGelisimCercevePainter(
          progress: progress.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
          progressColor: progressColor,
          backgroundColor: backgroundColor ?? Colors.white10,
          borderRadius: borderRadius,
          backgroundFill: backgroundFill,
        ),
        child: Padding(
          padding: EdgeInsets.all(kenar),
          child: SizedBox(
            width: icBoyut,
            height: icBoyut,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _KareGelisimCercevePainter extends CustomPainter {
  const _KareGelisimCercevePainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.backgroundColor,
    required this.borderRadius,
    this.backgroundFill,
  });

  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color backgroundColor;
  final double borderRadius;
  final Color? backgroundFill;

  @override
  void paint(Canvas canvas, Size size) {
    final half = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      half,
      half,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    if (backgroundFill != null) {
      canvas.drawRRect(rrect, Paint()..color = backgroundFill!);
    }

    final path = Path()..addRRect(rrect);
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, bgPaint);

    if (progress <= 0) return;

    final metric = path.computeMetrics().first;
    final dolu = metric.extractPath(0, metric.length * progress);
    final fgPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(dolu, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _KareGelisimCercevePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.backgroundFill != backgroundFill;
  }
}
