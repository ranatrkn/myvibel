// Yükleme: ince bir nabız çizgisi. Yumurta ve dönen daire yok.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class VibeYukleniyor extends StatefulWidget {
  const VibeYukleniyor({super.key, this.renk, this.nokta = 22});

  final Color? renk;
  final double nokta;

  @override
  State<VibeYukleniyor> createState() => _VibeYukleniyorState();
}

class _VibeYukleniyorState extends State<VibeYukleniyor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrol;

  @override
  void initState() {
    super.initState();
    _kontrol = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yukseklik = widget.nokta < 16 ? 22.0 : widget.nokta;
    final renk = widget.renk ?? const Color.fromARGB(255, 120, 0, 0);
    return SizedBox(
      width: yukseklik * 3.2,
      height: yukseklik,
      child: AnimatedBuilder(
        animation: _kontrol,
        builder: (context, _) {
          return CustomPaint(
            painter: _NabizPainter(ilerleme: _kontrol.value, renk: renk),
          );
        },
      ),
    );
  }
}

class _NabizPainter extends CustomPainter {
  _NabizPainter({required this.ilerleme, required this.renk});

  final double ilerleme;
  final Color renk;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.55;
    final w = size.width;
    final h = size.height * 0.72;
    final path = Path()
      ..moveTo(0, y)
      ..lineTo(w * 0.28, y)
      ..lineTo(w * 0.36, y - h * 0.18)
      ..lineTo(w * 0.46, y + h * 0.42)
      ..lineTo(w * 0.56, y - h * 0.55)
      ..lineTo(w * 0.66, y)
      ..lineTo(w, y);

    final metrik = path.computeMetrics().first;
    final uc = (ilerleme * metrik.length).clamp(0.0, metrik.length);
    final gorunen = metrik.extractPath(0, uc);
    final boya = Paint()
      ..color = renk
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, size.height * 0.09)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(gorunen, boya);
  }

  @override
  bool shouldRepaint(_NabizPainter eski) => eski.ilerleme != ilerleme;
}
