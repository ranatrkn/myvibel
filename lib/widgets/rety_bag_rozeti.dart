// Rety bağı rozeti: yalnızca iki kişi görür; 30 gün hareketsizse solar.
// Takipten çıkınca 3 gün içinde karşılıklı takip dönmezse bağ silinir.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/maskot_servis.dart';
import 'package:myvibel/widgets/vibe_avatar.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';

class RetyBagRozeti extends StatelessWidget {
  const RetyBagRozeti({
    super.key,
    required this.parlak,
    this.size = 28,
  });

  static const assetYolu = 'assets/badges/rety_bag_rozeti.png';

  final bool parlak;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget gorsel = Image.asset(
      assetYolu,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
    if (!parlak) {
      gorsel = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: gorsel,
      );
    }
    return Opacity(
      opacity: parlak ? 1 : 0.45,
      child: SizedBox(width: size, height: size, child: gorsel),
    );
  }
}

/// Karşı profilde: bağ varsa tek rozet.
class RetyBagProfilRozeti extends StatelessWidget {
  const RetyBagProfilRozeti({super.key, required this.otherUid});

  final String otherUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RetyBagKaydi?>(
      stream: MascotServis.bagStream(otherUid),
      builder: (context, snap) {
        final kayit = snap.data;
        if (kayit == null || !kayit.bagVar) return const SizedBox.shrink();
        return Tooltip(
          message: kayit.parlak ? 'Vibel bağı' : 'Vibel bağı · eski bağ',
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: RetyBagRozeti(parlak: kayit.parlak, size: 28),
          ),
        );
      },
    );
  }
}

/// Kendi profilde özel liste.
class RetyBagOzelListe extends StatelessWidget {
  const RetyBagOzelListe({
    super.key,
    required this.onKullaniciAc,
    this.kartli = true,
    this.bosGoster = false,
  });

  final void Function(String uid) onKullaniciAc;
  final bool kartli;
  final bool bosGoster;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RetyBagKaydi>>(
      stream: MascotServis.benimBaglarStream(),
      builder: (context, snap) {
        final liste = snap.data;
        if (liste == null) {
          if (!bosGoster) return const SizedBox.shrink();
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: VibeYukleniyor()),
          );
        }
        if (liste.isEmpty) {
          if (!bosGoster) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Henüz bağın yok.\nKarşılıklı takip ettiğin biriyle birbirinizin Vibel’ine yemek verince bağ oluşur.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.vibe.mutedText, fontSize: 14),
            ),
          );
        }
        final vibe = context.vibe;
        final icerik = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (kartli) ...[
              Text(
                'Vibel bağı · ${liste.length}',
                style: TextStyle(
                  color: vibe.mutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],
            ...liste.map(
              (k) => _RetyBagSatir(
                kayit: k,
                onTap: () => onKullaniciAc(k.otherUid),
              ),
            ),
          ],
        );
        if (!kartli) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [icerik],
          );
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          decoration: vibe.cardDecoration(),
          child: icerik,
        );
      },
    );
  }
}

class RetyBaglarPage extends StatelessWidget {
  const RetyBaglarPage({super.key, required this.onKullaniciAc});

  final void Function(String uid) onKullaniciAc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Arkadaşlık bağları'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Karşılıklı takip ettiğin birinin Vibel’ine yemek ver (20 vil), '
              'o da seninkine versin. Bağ rozeti yalnızca ikinizin profilinde görünür; '
              '30 gün karşılıklı yemek olmazsa solar. Biri takipten çıkar ve 3 gün içinde '
              'karşılıklı takip geri gelmezse bağ silinir.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: RetyBagOzelListe(
              kartli: false,
              bosGoster: true,
              onKullaniciAc: onKullaniciAc,
            ),
          ),
        ],
      ),
    );
  }
}

class _RetyBagSatir extends StatelessWidget {
  const _RetyBagSatir({required this.kayit, required this.onTap});

  final RetyBagKaydi kayit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(kayit.otherUid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data?.exists != true) {
          return const SizedBox.shrink();
        }
        final data = snap.data?.data();
        final ad = (data?['kullaniciAdi'] ?? 'kullanici').toString();
        final photoUrl = data?['photoUrl']?.toString();
        final avatarKey = data?['avatarKey']?.toString();
        return Material(
          color: Colors.transparent,
          child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                vibeAvatar(
                  radius: 26,
                  userId: kayit.otherUid,
                  photoUrl: photoUrl,
                  avatarKey: avatarKey,
                  fallbackText: ad,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '@$ad',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                RetyBagRozeti(parlak: kayit.parlak, size: 44),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}
