// Maskot bakım odası — yemek, uyku, gelişim.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/robot_servis.dart';
import 'package:vibe_life/vibe_snackbar.dart';
import 'package:vibe_life/widgets/robot_durum_bari.dart';
import 'package:vibe_life/widgets/robot_lottie_view.dart';
import 'package:vibe_life/widgets/vibe_gradient_scaffold.dart';

class MascotPage extends StatefulWidget {
  const MascotPage({super.key});

  @override
  State<MascotPage> createState() => _MascotPageState();
}

class _MascotPageState extends State<MascotPage> {
  bool _islemSuruyor = false;

  Future<void> _guvenliIslem(Future<void> Function() islem) async {
    if (_islemSuruyor) return;
    setState(() => _islemSuruyor = true);
    try {
      await islem();
    } catch (e) {
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(error: e, fallback: e.toString()),
      );
    } finally {
      if (mounted) setState(() => _islemSuruyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const VibeGradientScaffold(
        body: Center(child: Text('Oturum bulunamadı.')),
      );
    }

    return VibeGradientScaffold(
      appBar: AppBar(title: const Text('Maskot odası')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: VibeAppTheme.accent),
            );
          }

          final data = snapshot.data!.data() ?? {};
          final mascot = MascotServis.parse(data['robot']);
          final odaAcik = MascotServis.odaAcik(mascot.seviye);
          final uyuyor = mascot.uyuyor;
          final mesaj = MascotServis.ruhHaliMesaji(mascot);
          final vibe = context.vibe;
          final onSurface = Theme.of(context).colorScheme.onSurface;
          final sonrakiFaz = MascotServis.sonrakiFazSeviyesi(mascot.seviye);

          if (!odaAcik) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MascotLottieView(
                      seviye: mascot.seviye,
                      gorselDurum: mascot.gorselDurum,
                      width: 120,
                      height: 120,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${MascotServis.odaAcilisSeviyesi}. seviyede maskot odası açılır.\n'
                      'Şimdilik etkileşimlerle otomatik büyürsün.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: vibe.mutedText),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              children: [
                Text(
                  mascot.isim,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Seviye ${mascot.seviye} · ${MascotServis.fazBasligi(mascot.seviye)}',
                  style: TextStyle(color: vibe.mutedText),
                ),
                if (mascot.seviye < MascotServis.mutlulukAcilisSeviyesi) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Sonraki duygu kilidi: Seviye $sonrakiFaz',
                    style: TextStyle(color: vibe.faintText, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  mesaj,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: VibeAppTheme.accent,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                MascotLottieView(
                  seviye: mascot.seviye,
                  gorselDurum: mascot.gorselDurum,
                  width: 220,
                  height: 220,
                ),
                const SizedBox(height: 20),
                if (MascotServis.toklukAktif(mascot.seviye))
                  MascotDurumBari(
                    etiket: 'Tokluk',
                    deger: mascot.tokluk,
                    renk: Colors.orangeAccent,
                  ),
                if (MascotServis.enerjiAktif(mascot.seviye))
                  MascotDurumBari(
                    etiket: 'Enerji',
                    deger: mascot.enerji,
                    renk: Colors.amber,
                  ),
                if (MascotServis.mutlulukAktif(mascot.seviye))
                  MascotDurumBari(
                    etiket: 'Mutluluk',
                    deger: mascot.mutluluk,
                    renk: Colors.pinkAccent,
                  ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: mascot.gelisimOrani,
                    backgroundColor: Colors.white10,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gelişim: ${mascot.gelisimPuani} / ${mascot.gerekliGelisim} '
                  '(etkileşimle otomatik artar)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: vibe.mutedText, fontSize: 13),
                ),
                const SizedBox(height: 24),
                if (uyuyor) ...[
                  if (MascotServis.uykuKalanSure(mascot) case final kalan?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Kalan dinlenme: ${_sureYaz(kalan)}',
                        style: TextStyle(color: vibe.mutedText, fontSize: 13),
                      ),
                    ),
                  if (!MascotServis.uyuSistemiAcik(mascot.seviye))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Dinlenme ${MascotServis.enerjiAcilisSeviyesi}. seviyede tam açılır. '
                        'Şimdilik uyandırabilirsin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: vibe.faintText, fontSize: 12),
                      ),
                    ),
                  if (MascotServis.uyandirEngelMesaji(mascot) case final engel?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        engel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  _aksiyonButon(
                    label: 'Uyandır',
                    icon: Icons.wb_sunny_outlined,
                    onPressed: _islemSuruyor ||
                            !MascotServis.erkenUyandirabilir(mascot)
                        ? null
                        : () => _guvenliIslem(() async {
                              final sonuc = await MascotServis.uyandir(uid);
                              if (mounted) {
                                vibeSnackbarGoster(
                                  context,
                                  sonuc,
                                  tip: VibeMesajTipi.basari,
                                );
                              }
                            }),
                  ),
                ] else ...[
                  if (MascotServis.yemekSistemiAcik(mascot.seviye))
                    _aksiyonButon(
                      label: 'Yemek ver',
                      icon: Icons.restaurant,
                      onPressed: _islemSuruyor
                          ? null
                          : () => _guvenliIslem(() async {
                                final sonuc = await MascotServis.yemekVer(uid);
                                if (mounted) {
                                  vibeSnackbarGoster(
                                    context,
                                    sonuc,
                                    tip: VibeMesajTipi.basari,
                                  );
                                }
                              }),
                    ),
                  if (MascotServis.uyuSistemiAcik(mascot.seviye) &&
                      mascot.enerji <= MascotServis.uyuMaxEnerji)
                    _aksiyonButon(
                      label: 'Uyu',
                      icon: Icons.bedtime_outlined,
                      onPressed: _islemSuruyor
                          ? null
                          : () => _guvenliIslem(() async {
                                final sonuc = await MascotServis.uyuYap(uid);
                                if (mounted) {
                                  vibeSnackbarGoster(
                                    context,
                                    sonuc,
                                    tip: VibeMesajTipi.bilgi,
                                  );
                                }
                              }),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _sureYaz(Duration sure) {
    final saat = sure.inHours;
    final dakika = sure.inMinutes.remainder(60);
    if (saat > 0) return '$saat sa $dakika dk';
    if (dakika > 0) return '$dakika dk';
    return '${sure.inSeconds.remainder(60)} sn';
  }

  Widget _aksiyonButon({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: VibeAppTheme.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
