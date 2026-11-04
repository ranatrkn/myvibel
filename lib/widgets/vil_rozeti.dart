import 'package:flutter/material.dart';

/// Vil jetonu ve jetondan uzanan küçük çerçeve içinde miktar.
class VilRozeti extends StatelessWidget {
  const VilRozeti({
    super.key,
    required this.miktar,
    this.jetonBoyutu = 20,
    this.yaziBoyutu = 13,
    this.yaziRengi,
    this.cerceveRengi,
  });

  final int miktar;
  final double jetonBoyutu;
  final double yaziBoyutu;
  final Color? yaziRengi;
  final Color? cerceveRengi;

  static const _mor = Color(0xFF8E5CFF);

  @override
  Widget build(BuildContext context) {
    final yazi = yaziRengi ?? Theme.of(context).colorScheme.onSurface;
    final cerceve = cerceveRengi ?? _mor;
    final yari = jetonBoyutu / 2;
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Padding(
          padding: EdgeInsets.only(left: yari),
          child: Container(
            padding: EdgeInsets.fromLTRB(yari + 5, 1, 9, 1),
            decoration: BoxDecoration(
              color: cerceve.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: cerceve.withOpacity(0.55),
                width: 1,
              ),
            ),
            child: Text(
              '$miktar',
              style: TextStyle(
                color: yazi,
                fontSize: yaziBoyutu,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ),
        Image.asset(
          'assets/icon/vil.png',
          width: jetonBoyutu,
          height: jetonBoyutu,
          filterQuality: FilterQuality.medium,
        ),
      ],
    );
  }
}
