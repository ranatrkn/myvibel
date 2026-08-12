// Gönderi kartları için ortak beğeni durumu ve işlem mantığı.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/puan_animasyon.dart';
import 'package:vibe_life/sosyal_servis.dart';
import 'package:vibe_life/vibe_snackbar.dart';

class PostBegeniDurumuYonetici {
  PostBegeniDurumuYonetici({
    required this.postId,
    required this.userId,
    required this.postOwnerId,
    required int baslangicBegeniSayisi,
    bool? baslangicBegenildi,
  })  : begeniSayisi = baslangicBegeniSayisi,
        begenildi = baslangicBegenildi ?? false;

  final String postId;
  final String userId;
  final String postOwnerId;

  bool begenildi;
  bool islemSuruyor = false;
  int begeniSayisi;

  VoidCallback? _yenile;

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
      return;
    }
    _begeniDurumunuYukle();
  }

  Future<void> _begeniDurumunuYukle() async {
    if (userId.isEmpty) return;

    try {
      final likeDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId)
          .get();
      if (islemSuruyor) return;
      final yeniDurum = likeDoc.exists;
      if (begenildi == yeniDurum) return;
      begenildi = yeniDurum;
      _yenile?.call();
    } catch (e) {
      debugPrint('begeni durumu yukleme hatasi ($postId): $e');
    }
  }

  void guncelle({int? yeniBaslangicBegeni}) {
    if (yeniBaslangicBegeni != null && !islemSuruyor) {
      begeniSayisi = yeniBaslangicBegeni;
      _yenile?.call();
    }
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

    final eskiBegeniDurumu = begenildi;
    final eskiBegeniSayisi = begeniSayisi;

    islemSuruyor = true;
    begenildi = !begenildi;
    begeniSayisi += begenildi ? 1 : -1;
    _yenile?.call();

    try {
      final yeniBegeni = await SosyalServis.begeniDegistir(
        postId: postId,
        postOwnerId: postOwnerId,
        currentUserId: userId,
      );
      begenildi = yeniBegeni;
      begeniSayisi = eskiBegeniSayisi + (yeniBegeni ? 1 : -1);
      _yenile?.call();
      onBasari?.call(yeniBegeni);

      if (context.mounted && yeniBegeni && userId != postOwnerId) {
        puanAnimasyonuGoster(context, 2);
      }
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
      _yenile?.call();
    }
  }
}
