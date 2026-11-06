import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/ana_kabuk.dart';
import 'package:myvibel/gonderi_detay_sayfasi.dart';
import 'package:myvibel/user_profile_page.dart';

bool _gecisKilitli = false;
int _gecisBilet = 0;

/// Yavaşken aynı ekranın art arda açılmasını engeller.
/// Kilit, rota çizilmeye başlayana kadar durur; ekran kapanınca değil.
int? tekSeferGecisAl() {
  if (_gecisKilitli) return null;
  _gecisKilitli = true;
  _gecisBilet += 1;
  return _gecisBilet;
}

void tekSeferGecisIptal(int bilet) {
  if (_gecisBilet != bilet) return;
  _gecisKilitli = false;
}

void tekSeferGecisBirak(int bilet) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_gecisBilet == bilet) _gecisKilitli = false;
  });
}

NavigatorState _hedefNavigator(
  BuildContext context, {
  required bool kokte,
}) {
  if (!kokte) {
    final orta = AnaKabuk.aktif?.ortaNavigator();
    if (orta != null && orta.mounted) return orta;
  }
  return Navigator.of(context, rootNavigator: kokte);
}

Future<T?> tekSeferPush<T extends Object?>(
  BuildContext context,
  Route<T> route, {
  bool kokte = false,
}) {
  final bilet = tekSeferGecisAl();
  if (bilet == null) return Future<T?>.value(null);
  try {
    final sonuc = _hedefNavigator(context, kokte: kokte).push<T>(route);
    tekSeferGecisBirak(bilet);
    return sonuc;
  } catch (_) {
    tekSeferGecisIptal(bilet);
    rethrow;
  }
}

Future<void> profiliAc(BuildContext context, String userId) async {
  if (userId.isEmpty) return;
  final benim = FirebaseAuth.instance.currentUser?.uid;
  if (benim != null && userId == benim && AnaKabuk.kendiProfilineGit()) {
    return;
  }
  await tekSeferPush(
    context,
    MaterialPageRoute<void>(
      builder: (_) => UserProfilePage(userId: userId),
    ),
  );
}

Future<void> gonderiDetayiniAc(
  BuildContext context, {
  required String postId,
  required String currentUserId,
  bool yorumlariAc = false,
}) async {
  if (postId.isEmpty) return;
  await tekSeferPush(
    context,
    MaterialPageRoute<void>(
      builder: (_) => GonderiDetaySayfasi(
        postId: postId,
        currentUserId: currentUserId,
        onKendiProfilineGit: AnaKabuk.kendiProfilineGit,
        yorumlariAc: yorumlariAc,
      ),
    ),
  );
}
