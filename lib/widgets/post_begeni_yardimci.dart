// Gönderi kartları için ortak beğeni durumu ve işlem mantığı.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/maskot_servis.dart';
import 'package:myvibel/puan_animasyon.dart';
import 'package:myvibel/sosyal/begeni_yorum_servis.dart';
import 'package:myvibel/sosyal/sosyal_core.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/vil_harcama_uyarisi.dart';

class PostBegeniDurumuYonetici {
  PostBegeniDurumuYonetici({
    required this.postId,
    required this.userId,
    required this.postOwnerId,
    required int baslangicBegeniSayisi,
    bool? baslangicBegenildi,
  })  : begeniSayisi = baslangicBegeniSayisi,
        begenildi = baslangicBegenildi ??
            _bilinenDurumlar['$userId/$postId'] ??
            false;

  final String postId;
  final String userId;
  final String postOwnerId;

  bool begenildi;
  bool islemSuruyor = false;
  int begeniSayisi;

  VoidCallback? _yenile;

  // Ekranlar arası son bilinen beğeni durumu: detay/profil kartı açılınca
  // sunucu cevabını beklemeden doğru kalp görünsün.
  static final Map<String, bool> _bilinenDurumlar = {};

  String get _anahtar => '$userId/$postId';

  void _durumuKaydet() {
    if (userId.isEmpty) return;
    _bilinenDurumlar[_anahtar] = begenildi;
  }

  static int sayacDeger(dynamic value, int varsayilan) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return varsayilan;
  }

  void baslat({
    required VoidCallback yenile,
    bool? baslangicBegenildi,
  }) {
    _yenile = yenile;
    if (baslangicBegenildi != null) {
      begenildi = baslangicBegenildi;
      _durumuKaydet();
    }
    _begeniDurumunuYukle();
  }

  Future<void> _begeniDurumunuYukle() async {
    if (userId.isEmpty) return;

    if (userId != postOwnerId) {
      unawaited(
        BegeniYorumServis.begeniOdulDurumu(uid: userId, postId: postId)
            .catchError((Object e) {
          debugPrint('begeni odul durumu ($postId): $e');
          return const BegeniOdulDurumu(odulAlindi: false, geriAlindi: false);
        }),
      );
    }

    try {
      final likeDoc = await SosyalCore.gonderiRef(postId)
          .collection('likes')
          .doc(userId)
          .get();
      if (islemSuruyor) return;
      final yeniDurum = likeDoc.exists;
      _bilinenDurumlar[_anahtar] = yeniDurum;
      if (begenildi == yeniDurum) return;
      begenildi = yeniDurum;
      _yenile?.call();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        debugPrint('begeni durumu yukleme hatasi ($postId): $e');
      }
    } catch (e) {
      debugPrint('begeni durumu yukleme hatasi ($postId): $e');
    }
  }

  void guncelle({int? yeniBaslangicBegeni}) {
    if (yeniBaslangicBegeni != null && !islemSuruyor) {
      begeniSayisi = yeniBaslangicBegeni < 0 ? 0 : yeniBaslangicBegeni;
      _yenile?.call();
    }
  }

  void begeniDurumunuUygula(bool? yeniDurum) {
    if (yeniDurum == null || islemSuruyor || begenildi == yeniDurum) return;
    begenildi = yeniDurum;
    _durumuKaydet();
    _yenile?.call();
  }

  void durdur() {}

  void sayacSenkronizeEt(int yeniBegeniSayisi) {
    if (islemSuruyor || yeniBegeniSayisi == begeniSayisi) return;
    begeniSayisi = yeniBegeniSayisi;
    _yenile?.call();
  }

  Future<void> degistir(
    BuildContext context, {
    ValueChanged<bool>? onBasari,
  }) async {
    if (islemSuruyor || userId.isEmpty) return;

    final kendiGonderisi = userId == postOwnerId;
    BegeniOdulDurumu? odulDurumu;
    if (!kendiGonderisi) {
      odulDurumu = BegeniYorumServis.begeniOdulDurumuOnbellek(
        uid: userId,
        postId: postId,
      );
      if (odulDurumu == null && begenildi) {
        try {
          odulDurumu = await BegeniYorumServis.begeniOdulDurumu(
            uid: userId,
            postId: postId,
          );
        } catch (e) {
          debugPrint('begeni odul durumu ($postId): $e');
        }
      }
    }
    if (!context.mounted) return;

    if (begenildi && !kendiGonderisi && !(odulDurumu?.geriAlindi ?? false)) {
      final devam = await VilHarcamaUyarisi.onayla(
        context: context,
        islem: VilHarcamaUyarisi.begeniGeriAl,
        maliyet: MascotServis.sosyalGeriAlVilMaliyeti,
      );
      if (!devam) return;
    }

    final eskiBegeniDurumu = begenildi;
    final eskiBegeniSayisi = begeniSayisi;

    islemSuruyor = true;
    begenildi = !begenildi;
    begeniSayisi += begenildi ? 1 : -1;
    if (begeniSayisi < 0) begeniSayisi = 0;
    _yenile?.call();
    if (context.mounted &&
        begenildi &&
        !kendiGonderisi &&
        !(odulDurumu?.odulAlindi ?? false)) {
      puanAnimasyonuGoster(context, 2);
    }

    try {
      final yeniBegeni = await SosyalServis.begeniDegistir(
        postId: postId,
        postOwnerId: postOwnerId,
        currentUserId: userId,
        begen: begenildi,
      );
      begenildi = yeniBegeni;
      begeniSayisi = eskiBegeniSayisi + (yeniBegeni ? 1 : -1);
      if (begeniSayisi < 0) begeniSayisi = 0;
      _yenile?.call();
      onBasari?.call(yeniBegeni);
    } catch (e) {
      begenildi = eskiBegeniDurumu;
      begeniSayisi = eskiBegeniSayisi;
      _yenile?.call();
      debugPrint('begeni degistir hatasi ($postId): $e');
      if (context.mounted) {
        vibeSnackbarGoster(
          context,
          internetAwareErrorMessage(
            error: e,
            fallback: 'Beğeni işlemi başarısız.',
          ),
        );
      }
    } finally {
      islemSuruyor = false;
      _durumuKaydet();
      _yenile?.call();
    }
  }
}
