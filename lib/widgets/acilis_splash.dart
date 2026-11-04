// Uygulama açılışı: MyVibel ikonu, uygulama gradyanı üzerinde.
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';

class AcilisSplash extends StatelessWidget {
  const AcilisSplash({
    super.key,
    this.mesaj,
    this.arkaPlansiz = false,
  });

  final String? mesaj;
  final bool arkaPlansiz;

  static const _ikonYolu = 'assets/icon/myvibel_ikon.png';

  @override
  Widget build(BuildContext context) {
    final icerik = SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              _ikonYolu,
              width: 176,
              height: 176,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 28),
            const VibeYukleniyor(renk: Colors.white),
            if (mesaj != null) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  mesaj!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: VibeAppTheme.fontFamily,
                    color: Color(0xB3FFFFFF),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (arkaPlansiz) {
      return icerik;
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 40, 0, 0),
            Color(0xFF1A002E),
            Color.fromARGB(255, 15, 0, 38),
          ],
        ),
      ),
      child: SizedBox.expand(child: icerik),
    );
  }
}
