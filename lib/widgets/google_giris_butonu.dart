// Google ile giriş / kayıt butonu.
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/maestro_semantics.dart';

class GoogleGirisButonu extends StatelessWidget {
  const GoogleGirisButonu({
    super.key,
    required this.onPressed,
    this.etiket = 'Google ile devam et',
    this.yukleniyor = false,
  });

  final VoidCallback? onPressed;
  final String etiket;
  final bool yukleniyor;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final theme = Theme.of(context);

    return Semantics(
      label: MaestroSemantics.googleIleGiris,
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(
          onPressed: yukleniyor ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
            backgroundColor: vibe.inputFill,
            side: BorderSide(color: vibe.cardBorder),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: yukleniyor
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _GoogleGIsareti(),
                    const SizedBox(width: 10),
                    Text(etiket),
                  ],
                ),
        ),
      ),
    );
  }
}

class _GoogleGIsareti extends StatelessWidget {
  const _GoogleGIsareti();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF4285F4),
            height: 1,
          ),
        ),
      ),
    );
  }
}
