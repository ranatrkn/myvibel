// Takip/engel listeleri ve feed üst barı için yerel önbellek.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SosyalOnbellekServis {
  static String _takipAnahtar(String uid) => 'sosyal_takip_v1_$uid';
  static String _engelAnahtar(String uid) => 'sosyal_engel_v1_$uid';
  static String _engelByAnahtar(String uid) => 'sosyal_engel_by_v1_$uid';
  static String _feedUstAnahtar(String uid) => 'feed_ust_v1_$uid';
  static String _listeMsAnahtar(String uid) => 'sosyal_list_ms_v1_$uid';
  static const sosyalListeTazeSure = Duration(minutes: 10);

  static Set<String> _uidSetOku(String? ham) {
    if (ham == null || ham.isEmpty) return {};
    return ham.split(',').where((id) => id.isNotEmpty).toSet();
  }

  static String _uidSetYaz(Set<String> idler) {
    if (idler.isEmpty) return '';
    return idler.join(',');
  }

  static Future<
      ({
        Set<String> takipEdilenIdler,
        Set<String> engelledigimIdler,
        Set<String> beniEngelleyenIdler,
      })?> sosyalListeleriYukle(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final takip = prefs.getString(_takipAnahtar(uid));
      final engel = prefs.getString(_engelAnahtar(uid));
      final engelBy = prefs.getString(_engelByAnahtar(uid));
      if (takip == null && engel == null && engelBy == null) return null;
      return (
        takipEdilenIdler: _uidSetOku(takip),
        engelledigimIdler: _uidSetOku(engel),
        beniEngelleyenIdler: _uidSetOku(engelBy),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> sosyalListeTazeMi(String uid) async {
    if (uid.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_listeMsAnahtar(uid));
      if (ts == null || ts <= 0) return false;
      return DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(ts),
          ) <
          sosyalListeTazeSure;
    } catch (_) {
      return false;
    }
  }

  static Future<void> sosyalListeleriKaydet(
    String uid, {
    required Set<String> takipEdilenIdler,
    required Set<String> engelledigimIdler,
    required Set<String> beniEngelleyenIdler,
  }) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_takipAnahtar(uid), _uidSetYaz(takipEdilenIdler));
      await prefs.setString(_engelAnahtar(uid), _uidSetYaz(engelledigimIdler));
      await prefs.setString(
        _engelByAnahtar(uid),
        _uidSetYaz(beniEngelleyenIdler),
      );
      await prefs.setInt(
        _listeMsAnahtar(uid),
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> feedUstVerisiYukle(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ham = prefs.getString(_feedUstAnahtar(uid));
      if (ham == null || ham.isEmpty) return null;
      final decoded = jsonDecode(ham);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> feedUstVerisiKaydet(
    String uid,
    Map<String, dynamic> data,
  ) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final sakla = {
        'kullaniciAdi': data['kullaniciAdi'],
        'robot': data['robot'],
      };
      await prefs.setString(_feedUstAnahtar(uid), jsonEncode(sakla));
    } catch (_) {}
  }
}
