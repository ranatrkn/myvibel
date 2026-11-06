// Takipçi / takip edilen sayıları: son bilinen değer anında gösterilir,
// sunucudan gelen sayı arka planda yerine yazılır.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TakipSayacOnbellek {
  static final Map<String, int> _bellek = {};
  static SharedPreferences? _prefs;

  static String _anahtar(String uid, bool takipci) =>
      'takipSayac_${takipci ? 'takipci' : 'takip'}_$uid';

  static Future<void> hazirla() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static int? oku(String uid, {required bool takipci}) {
    final anahtar = _anahtar(uid, takipci);
    return _bellek[anahtar] ?? _prefs?.getInt(anahtar);
  }

  static Future<int> tazele(String uid, {required bool takipci}) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(takipci ? 'followers' : 'following')
        .count()
        .get();
    final sayi = snap.count ?? 0;
    final anahtar = _anahtar(uid, takipci);
    _bellek[anahtar] = sayi;
    unawaited(_prefs?.setInt(anahtar, sayi));
    return sayi;
  }

  /// Uygulama açılışında kendi sayılarını önceden ısıtır.
  static Future<void> onYukle(String uid) async {
    await hazirla();
    await Future.wait([
      tazele(uid, takipci: true),
      tazele(uid, takipci: false),
    ]);
  }
}
