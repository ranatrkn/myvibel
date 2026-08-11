// Puan kazanım/kaybı için yüzen animasyon gösterir.
import 'package:flutter/material.dart';

// Ekranda kısa süreli puan animasyonu başlatır
void puanAnimasyonuGoster(BuildContext context, int miktar) {
  if (miktar == 0 || !context.mounted) return;

  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => _PuanAnimasyonWidget(
      miktar: miktar,
      onFinished: () {
        if (entry.mounted) {
          entry.remove(); // Animasyon bitince kaldır
        }
      },
    ),
  );

  overlay.insert(entry);
}

// Animasyonlu puan metni widget'ı
class _PuanAnimasyonWidget extends StatefulWidget {
  final int miktar;
  final VoidCallback onFinished;

  const _PuanAnimasyonWidget({
    required this.miktar,
    required this.onFinished,
  });

  @override
  State<_PuanAnimasyonWidget> createState() => _PuanAnimasyonWidgetState();
}

class _PuanAnimasyonWidgetState extends State<_PuanAnimasyonWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  bool _bitti = false;

  // Tekrarlı bitiş çağrısını engeller
  void _animasyonuBitir() {
    if (_bitti) return;
    _bitti = true;
    widget.onFinished();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.25, curve: Curves.easeOut),
      ),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: const Offset(0, -0.6),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _animasyonuBitir();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isaret = widget.miktar > 0 ? "+" : "";

    return IgnorePointer(
      child: Center(
        child: SlideTransition(
          position: _offset,
          child: FadeTransition(
            opacity: _opacity,
            child: Material(
              color: Colors.transparent,
              child: Text(
                "$isaret${widget.miktar}",
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
