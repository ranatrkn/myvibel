// Apple ile giriş / kayıt butonu.
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/maestro_semantics.dart';

class AppleGirisButonu extends StatelessWidget {
  const AppleGirisButonu({
    super.key,
    required this.onPressed,
    this.etiket = 'Apple ile devam et',
    this.yukleniyor = false,
  });

  final VoidCallback? onPressed;
  final String etiket;
  final bool yukleniyor;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final theme = Theme.of(context);
    final koyu = theme.brightness == Brightness.dark;
    final zemin = koyu ? Colors.white : Colors.black;
    final yazi = koyu ? Colors.black : Colors.white;

    return Semantics(
      label: MaestroSemantics.appleIleGiris,
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(
          onPressed: yukleniyor ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: yazi,
            backgroundColor: zemin,
            side: BorderSide(color: vibe.cardBorder),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: yukleniyor
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: yazi,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apple, size: 22, color: yazi),
                    const SizedBox(width: 10),
                    Text(etiket),
                  ],
                ),
        ),
      ),
    );
  }
}
