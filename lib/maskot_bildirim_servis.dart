// Vibel açlık / uyku hatırlatması — cihazda yerel, Blaze gerekmez.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:myvibel/maskot_bakim_sozleri.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class MaskotBildirimServis {
  MaskotBildirimServis._();

  static const _kanalId = 'vibel_bakim';
  static const _idAclikYaklasma = 71001;
  static const _idUykuYaklasma = 71002;
  static const _idAclikDongu = 71100;
  static const _idUykuDongu = 71200;
  static const _aclikDonguAdet = 8;
  static const _uykuDonguAdet = 8;
  static const _aclikDonguSaat = 5;
  static const _uykuDonguSaat = 5;
  static const _prefsDongu = 'vibel_aclik_dongu_baslangic_ms';
  static const _prefsUykuDongu = 'vibel_uyku_dongu_baslangic_ms';
  static const _toklukEsik = MaskotBakimSozleri.toklukEsik;
  static const _toklukTamDakika = 300;
  static const _enerjiUykuEsik = MaskotBakimSozleri.enerjiEsik;
  static const _enerjiTamDakika = 360;
  static const _toklukSeviye = 6;
  static const _uykuSeviye = 11;

  static final _eklenti = FlutterLocalNotificationsPlugin();
  static bool _hazir = false;

  static Future<void> baslat() async {
    if (kIsWeb || _hazir) return;
    try {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      } catch (_) {
        tz.setLocalLocation(tz.local);
      }

      await _eklenti.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_mv'),
        ),
      );
      await _eklenti
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _kanalId,
              'Vibel bakımı',
              description: 'Açlık ve uyku hatırlatmaları',
              importance: Importance.defaultImportance,
            ),
          );
      await _eklenti.cancel(71999);
      await _eklenti.cancel(72001);
      await _eklenti.cancel(72004);
      _hazir = true;
    } catch (e) {
      debugPrint('Maskot bildirim baslatilamadi: $e');
    }
  }

  static NotificationDetails _detay({
    required String kanal,
    required String kanalAd,
    required Importance importance,
    required Priority priority,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        kanal,
        kanalAd,
        channelDescription: 'Açlık ve uyku hatırlatmaları',
        importance: importance,
        priority: priority,
        icon: '@drawable/ic_stat_mv',
      ),
    );
  }

  static Future<void> planlaHaritadan(Map<String, dynamic> robot) async {
    if (kIsWeb) return;
    await baslat();
    final izin = await _eklenti
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    if (izin == false) return;
    await _eklenti
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    final seviye = _int(robot['seviye'], 1);
    final isim = (robot['isim'] ?? 'Vibel').toString().trim();
    final ad = isim.isEmpty ? 'Vibel' : isim;
    final tokluk = _int(robot['tokluk'], 80).clamp(0, 100);
    final enerji = _int(robot['enerji'], 70).clamp(0, 100);
    final uykuBitis = _int(robot['uykuBitisMs'], 0);
    final simdi = DateTime.now().millisecondsSinceEpoch;
    final uyuyor = uykuBitis > simdi;

    await _eklenti.cancel(_idAclikYaklasma);
    await _eklenti.cancel(_idUykuYaklasma);
    await _aclikDongusunuIptal();
    await _uykuDongusunuIptal();

    if (seviye < _toklukSeviye) {
      await _aclikDongusunuSifirla();
      await _uykuDongusunuSifirla();
      return;
    }

    if (tokluk > _toklukEsik) {
      await _aclikDongusunuSifirla();
      if (!uyuyor) {
        final aclikDakika = _dakikaEsige(tokluk, _toklukEsik, _toklukTamDakika);
        if (aclikDakika != null) {
          await _zamanla(
            id: _idAclikYaklasma,
            dakika: aclikDakika,
            baslik: ad,
            govde: MaskotBakimSozleri.aclikYaklasma,
          );
        }
      }
    } else if (!uyuyor) {
      await _aclikDongusunuKur(ad: ad, simdiMs: simdi);
    }

    if (uyuyor || seviye < _uykuSeviye) {
      await _uykuDongusunuSifirla();
      return;
    }

    if (enerji > _enerjiUykuEsik) {
      await _uykuDongusunuSifirla();
      // Enerji yalnızca açken düşer; tok Vibel önce acıkmalı.
      final aclikeKalan = tokluk > _toklukEsik
          ? ((tokluk - _toklukEsik) * _toklukTamDakika / 100).ceil()
          : 0;
      final uykuDakika =
          _dakikaEsige(enerji, _enerjiUykuEsik, _enerjiTamDakika);
      if (uykuDakika != null) {
        await _zamanla(
          id: _idUykuYaklasma,
          dakika: aclikeKalan + uykuDakika,
          baslik: ad,
          govde: MaskotBakimSozleri.uykuYaklasma,
        );
      }
    } else {
      await _uykuDongusunuKur(ad: ad, simdiMs: simdi);
    }
  }

  static Future<void> _aclikDongusunuKur({
    required String ad,
    required int simdiMs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    var baslangic = prefs.getInt(_prefsDongu) ?? 0;
    if (baslangic <= 0 || baslangic > simdiMs) {
      baslangic = simdiMs;
      await prefs.setInt(_prefsDongu, baslangic);
    }

    const aralikMs = _aclikDonguSaat * 60 * 60 * 1000;
    final gecen = simdiMs - baslangic;
    var sira = gecen <= 0 ? 1 : (gecen ~/ aralikMs) + 1;
    var kurulan = 0;
    while (kurulan < _aclikDonguAdet) {
      final hedefMs = baslangic + (sira * aralikMs);
      final dakika = ((hedefMs - simdiMs) / 60000).ceil();
      if (dakika >= 2) {
        final cumle = MaskotBakimSozleri.aclikCumleleri[
            (sira - 1) % MaskotBakimSozleri.aclikCumleleri.length];
        await _zamanla(
          id: _idAclikDongu + kurulan,
          dakika: dakika,
          baslik: ad,
          govde: cumle,
        );
        kurulan += 1;
      }
      sira += 1;
      if (sira > 40) break;
    }
  }

  static Future<void> _aclikDongusunuIptal() async {
    for (var i = 0; i < _aclikDonguAdet; i++) {
      await _eklenti.cancel(_idAclikDongu + i);
    }
  }

  static Future<void> _aclikDongusunuSifirla() async {
    await _aclikDongusunuIptal();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsDongu);
  }

  static Future<void> _uykuDongusunuKur({
    required String ad,
    required int simdiMs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    var baslangic = prefs.getInt(_prefsUykuDongu) ?? 0;
    if (baslangic <= 0 || baslangic > simdiMs) {
      baslangic = simdiMs;
      await prefs.setInt(_prefsUykuDongu, baslangic);
    }

    const aralikMs = _uykuDonguSaat * 60 * 60 * 1000;
    final gecen = simdiMs - baslangic;
    var sira = gecen <= 0 ? 1 : (gecen ~/ aralikMs) + 1;
    var kurulan = 0;
    while (kurulan < _uykuDonguAdet) {
      final hedefMs = baslangic + (sira * aralikMs);
      final dakika = ((hedefMs - simdiMs) / 60000).ceil();
      if (dakika >= 2) {
        final cumle = MaskotBakimSozleri.uykuCumleleri[
            (sira - 1) % MaskotBakimSozleri.uykuCumleleri.length];
        await _zamanla(
          id: _idUykuDongu + kurulan,
          dakika: dakika,
          baslik: ad,
          govde: cumle,
        );
        kurulan += 1;
      }
      sira += 1;
      if (sira > 40) break;
    }
  }

  static Future<void> _uykuDongusunuIptal() async {
    for (var i = 0; i < _uykuDonguAdet; i++) {
      await _eklenti.cancel(_idUykuDongu + i);
    }
  }

  static Future<void> _uykuDongusunuSifirla() async {
    await _uykuDongusunuIptal();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsUykuDongu);
  }

  static int? _dakikaEsige(int deger, int esik, int tamDakika) {
    if (deger <= esik) return null;
    final dakika = ((deger - esik) * tamDakika / 100).ceil();
    return dakika < 2 ? 2 : dakika;
  }

  static Future<void> _zamanla({
    required int id,
    required int dakika,
    required String baslik,
    required String govde,
  }) async {
    final zaman = tz.TZDateTime.now(tz.local).add(Duration(minutes: dakika));
    final detay = _detay(
      kanal: _kanalId,
      kanalAd: 'Vibel bakımı',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    try {
      await _eklenti.zonedSchedule(
        id,
        baslik,
        govde,
        zaman,
        detay,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      try {
        await _eklenti.zonedSchedule(
          id,
          baslik,
          govde,
          zaman,
          detay,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e2) {
        debugPrint('Maskot bildirim planlanamadı: $e2');
      }
    }
  }

  static int _int(dynamic v, int varsayilan) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return varsayilan;
  }
}
