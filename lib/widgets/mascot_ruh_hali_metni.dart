// Vibel kutusu: aç / yorgun cümleleri aralıkla yenilenir.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myvibel/maskot_bakim_sozleri.dart';
import 'package:myvibel/maskot_servis.dart';

class MascotRuhHaliMetni extends StatefulWidget {
  const MascotRuhHaliMetni({
    super.key,
    required this.mascot,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final MascotDurum mascot;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<MascotRuhHaliMetni> createState() => _MascotRuhHaliMetniState();
}

class _MascotRuhHaliMetniState extends State<MascotRuhHaliMetni> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(MaskotBakimSozleri.kutuAralik, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      MascotServis.ruhHaliMesaji(widget.mascot),
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      style: widget.style,
    );
  }
}
