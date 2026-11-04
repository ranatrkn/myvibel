// Maskot karesi etrafında seviye gelişim çubuğu.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';

/// Maskot görselini kare bir çerçeve içine alır; çerçeve gelişim oranına göre dolur.
class MascotGelisimCercevesi extends StatelessWidget {
  const MascotGelisimCercevesi({
    super.key,
    required this.progress,
    required this.size,
    required this.child,
    this.strokeWidth = 5,
    this.innerPadding = 5,
    this.progressColor,
    this.backgroundColor,
    this.borderRadius = 20,
    this.backgroundFill,
  });

  final double progress;
  final double size;
  final Widget child;
  final double strokeWidth;
  final double innerPadding;
  final Color? progressColor;
  final Color? backgroundColor;
  final double borderRadius;
  final Color? backgroundFill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kenar = strokeWidth + innerPadding;
    final icBoyut = size - kenar * 2;
    final iz = backgroundColor ??
        theme.colorScheme.onSurface.withOpacity(0.22);
    final dolu = progressColor ?? VibeAppTheme.accent;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KareGelisimCercevePainter(
          progress: progress.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
          progressColor: dolu,
          backgroundColor: iz,
          borderRadius: borderRadius,
          backgroundFill: backgroundFill,
        ),
        child: Padding(
          padding: EdgeInsets.all(kenar),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              math.max(0, borderRadius - kenar / 2),
            ),
            child: SizedBox(
              width: icBoyut,
              height: icBoyut,
              child: child,
            ),
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
    final uzunluk = metric.length;
    // Üst kenarın ortasından başlasın; küçük ilerleme de görünsün.
    final baslangic = uzunluk * 0.875;
    final doluUzunluk = uzunluk * progress;
    final Path dolu;
    if (baslangic + doluUzunluk <= uzunluk) {
      dolu = metric.extractPath(baslangic, baslangic + doluUzunluk);
    } else {
      final birinci = metric.extractPath(baslangic, uzunluk);
      final ikinci = metric.extractPath(0, baslangic + doluUzunluk - uzunluk);
      dolu = Path()
        ..addPath(birinci, Offset.zero)
        ..addPath(ikinci, Offset.zero);
    }
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
