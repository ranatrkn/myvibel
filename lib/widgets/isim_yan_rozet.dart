// İsim yanında o haftanın rozeti ve Vibel sıralaması tacı.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/haftalik_gorev_servis.dart';
import 'package:myvibel/maskot_servis.dart';

class HaftaRozetServis {
  HaftaRozetServis._();

  static final HaftaRozetServis instance = HaftaRozetServis._();

  final Map<String, String> _rozet = {};
  final Map<String, ValueNotifier<String>> _dinleyici = {};
  final ValueNotifier<bool> acik = ValueNotifier(false);
  bool _yukleniyor = false;

  String rozet(String uid) => _rozet[uid] ?? '';

  ValueNotifier<String> dinleyici(String uid) {
    return _dinleyici.putIfAbsent(uid, () => ValueNotifier(rozet(uid)));
  }

  Future<void> yenile() async {
    if (_yukleniyor) return;
    _yukleniyor = true;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final ben = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final seviye =
            MascotServis.tryParse(ben.data()?['robot'])?.seviye ?? 1;
        acik.value = seviye >= MascotServis.gorevAcilisSeviyesi;
      }
      if (!acik.value) return;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('haftalikGorev.hafta',
              isEqualTo: HaftalikGorevServis.haftaKimligi())
          .where('haftalikGorev.puan',
              isGreaterThanOrEqualTo: HaftalikGorevServis.bronzPuan)
          .orderBy('haftalikGorev.puan', descending: true)
          .limit(100)
          .get();
      final yeni = <String, String>{};
      for (final doc in snap.docs) {
        final puan = (doc.data()['haftalikGorev'] as Map?)?['puan'];
        final tur = HaftalikGorevServis.rozetTuru(
          puan is num ? puan.toInt() : 0,
        );
        if (tur.isNotEmpty) yeni[doc.id] = tur;
      }
      _rozet
        ..clear()
        ..addAll(yeni);
      for (final entry in _dinleyici.entries) {
        final deger = yeni[entry.key] ?? '';
        if (entry.value.value != deger) entry.value.value = deger;
      }
    } catch (_) {
    } finally {
      _yukleniyor = false;
    }
  }
}

class IsimYanRozet extends StatelessWidget {
  const IsimYanRozet({super.key, required this.uid, this.boy = 20});

  final String uid;
  final double boy;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: HaftaRozetServis.instance.acik,
      builder: (context, acik, _) {
        if (!acik) return const SizedBox.shrink();
        return ValueListenableBuilder<String>(
          valueListenable: HaftaRozetServis.instance.dinleyici(uid),
          builder: (context, rozet, _) {
            if (rozet.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: HaftaRozetGorsel(tur: rozet, boy: boy),
            );
          },
        );
      },
    );
  }
}

class RozetSayacSatiri extends StatelessWidget {
  const RozetSayacSatiri({super.key, required this.data, required this.seviye});

  final Map<String, dynamic>? data;
  final int seviye;

  @override
  Widget build(BuildContext context) {
    if (seviye < MascotServis.gorevAcilisSeviyesi) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<bool>(
      valueListenable: HaftaRozetServis.instance.acik,
      builder: (context, acik, _) {
        if (!acik) return const SizedBox.shrink();
        final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
        int sayi(String alan) {
          final deger = data?[alan];
          if (deger is num) return deger.toInt();
          return 0;
        }

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              const HaftaRozetGorsel(tur: 'altin', boy: 22),
              const SizedBox(width: 4),
              Text('${sayi('rozetAltin')}',
                  style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(width: 10),
              const HaftaRozetGorsel(tur: 'gumus', boy: 22),
              const SizedBox(width: 4),
              Text('${sayi('rozetGumus')}',
                  style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(width: 10),
              const HaftaRozetGorsel(tur: 'bronz', boy: 22),
              const SizedBox(width: 4),
              Text('${sayi('rozetBronz')}',
                  style: TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}

class HaftaRozetGorsel extends StatelessWidget {
  const HaftaRozetGorsel({super.key, required this.tur, this.boy = 16});

  final String tur;
  final double boy;

  static const _yollar = {
    'altin': 'assets/badges/hafta_rozet_altin.png',
    'gumus': 'assets/badges/hafta_rozet_gumus.png',
    'bronz': 'assets/badges/hafta_rozet_bronz.png',
  };

  @override
  Widget build(BuildContext context) {
    final yol = _yollar[tur];
    if (yol == null) return const SizedBox.shrink();
    return Image.asset(
      yol,
      height: boy,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
