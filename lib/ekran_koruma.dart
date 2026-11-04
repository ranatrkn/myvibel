import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android'de çocuk hesabında ekran görüntüsü / kayıt zorlaştırılır (FLAG_SECURE).
class EkranKoruma {
  EkranKoruma._();

  static const _kanal = MethodChannel('myvibel/ekran');

  static Future<void> ayarla(bool kilit) async {
    if (kIsWeb) return;
    try {
      await _kanal.invokeMethod<void>('setSecure', kilit);
    } catch (e) {
      debugPrint('ekran koruma: $e');
    }
  }
}
