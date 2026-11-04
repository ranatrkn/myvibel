// Global liderlik sırası (1–3) önbelleği; avatar taçları için.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myvibel/sosyal/takip_servis.dart';

class LiderTacServis {
  LiderTacServis._();

  static final LiderTacServis instance = LiderTacServis._();

  static const _onbellekSuresi = Duration(minutes: 10);
  static const _prefsAnahtar = 'lider_tac_sira_v1';

  Map<String, int> _siraHaritasi = {};
  DateTime? _sonYenileme;
  bool _yukleniyor = false;
  bool _baslatildi = false;
  final Map<String, ValueNotifier<int>> _tacDinleyicileri = {};

  bool get hazir => _sonYenileme != null;

  int? sira(String uid) {
    if (uid.isEmpty) return null;
    final s = _siraHaritasi[uid];
    if (s != null && s >= 1 && s <= 3) return s;
    return null;
  }

  ValueNotifier<int> siraDinleyici(String uid) {
    return _tacDinleyicileri.putIfAbsent(
      uid,
      () => ValueNotifier(sira(uid) ?? 0),
    );
  }

  void _tacDinleyicileriniGuncelle(Map<String, int> yeni) {
    for (final entry in yeni.entries) {
      final dinleyici = _tacDinleyicileri.putIfAbsent(
        entry.key,
        () => ValueNotifier(entry.value),
      );
      if (dinleyici.value != entry.value) {
        dinleyici.value = entry.value;
      }
    }
    for (final uid in _tacDinleyicileri.keys) {
      if (!yeni.containsKey(uid) && _tacDinleyicileri[uid]!.value != 0) {
        _tacDinleyicileri[uid]!.value = 0;
      }
    }
  }

  Future<void> baslat() async {
    if (_baslatildi) return;
    _baslatildi = true;
    await _onbellektenYukle();
    unawaited(yenile(zorla: true));
  }

  Future<void> yenile({bool zorla = false}) async {
    if (_yukleniyor) return;
    if (!zorla &&
        _sonYenileme != null &&
        DateTime.now().difference(_sonYenileme!) < _onbellekSuresi) {
      return;
    }

    _yukleniyor = true;
    try {
      final uidler = await TakipServis.liderlikUstUcUidleri();
      final yeni = <String, int>{};
      for (var i = 0; i < uidler.length; i++) {
        final uid = uidler[i];
        if (uid.isNotEmpty) {
          yeni[uid] = i + 1;
        }
      }
      _siraHaritasi = yeni;
      _sonYenileme = DateTime.now();
      _tacDinleyicileriniGuncelle(yeni);
      await _onbellegeYaz(yeni);
    } catch (e) {
      debugPrint('Lider taç önbelleği yenilenemedi: $e');
    } finally {
      _yukleniyor = false;
    }
  }

  Future<void> _onbellektenYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ham = prefs.getString(_prefsAnahtar);
      if (ham == null || ham.isEmpty) return;

      final yeni = <String, int>{};
      for (final parca in ham.split(',')) {
        final ayir = parca.split(':');
        if (ayir.length != 2) continue;
        final uid = ayir[0].trim();
        final siraNo = int.tryParse(ayir[1].trim());
        if (uid.isNotEmpty && siraNo != null && siraNo >= 1 && siraNo <= 3) {
          yeni[uid] = siraNo;
        }
      }
      if (yeni.isEmpty) return;

      _siraHaritasi = yeni;
      _sonYenileme = DateTime.now();
      _tacDinleyicileriniGuncelle(yeni);
    } catch (e) {
      debugPrint('Lider taç yerel önbellek okunamadı: $e');
    }
  }

  Future<void> _onbellegeYaz(Map<String, int> harita) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ham = harita.entries.map((e) => '${e.key}:${e.value}').join(',');
      await prefs.setString(_prefsAnahtar, ham);
    } catch (e) {
      debugPrint('Lider taç yerel önbellek yazılamadı: $e');
    }
  }
}
