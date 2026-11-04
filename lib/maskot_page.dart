// Maskot bakım odası — yemek, uyku, gelişim.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/haftalik_gorev_servis.dart';
import 'package:myvibel/maestro_semantics.dart';
import 'package:myvibel/maskot_servis.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/mascot_ruh_hali_metni.dart';
import 'package:myvibel/widgets/haftalik_gorev_karti.dart';
import 'package:myvibel/widgets/maskot_durum_bari.dart';
import 'package:myvibel/widgets/maskot_gelisim_cercevesi.dart';
import 'package:myvibel/widgets/maskot_lottie_view.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';
import 'package:myvibel/widgets/vil_harcama_uyarisi.dart';
import 'package:myvibel/widgets/vil_rozeti.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';

class MascotPage extends StatefulWidget {
  const MascotPage({super.key});

  @override
  State<MascotPage> createState() => _MascotPageState();
}

class _MascotPageState extends State<MascotPage> {
  bool _islemSuruyor = false;
  Map<String, dynamic>? _iyimserRobot;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      HaftalikGorevServis.oturumSenkronizeEt(uid);
    }
  }

  Future<void> _guvenliIslem(Future<void> Function() islem) async {
    if (_islemSuruyor) return;
    setState(() => _islemSuruyor = true);
    try {
      await islem();
    } catch (e) {
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: 'Yemek veya bakım şu an yapılamadı. Tekrar dene.',
        ),
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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final robotHam = _iyimserRobot ?? data?['robot'];
        final mascot = data != null ? MascotServis.tryParse(robotHam) : null;
        final baslik = mascot != null ? '${mascot.isim} odası' : 'Vibel odası';

        return VibeGradientScaffold(
          appBar: VibeGradientScaffold.seffafBaslik(baslik),
          body: _maskotGovdesi(
            snapshot: snapshot,
            uid: uid,
          ),
        );
      },
    );
  }

  Widget _maskotGovdesi({
    required AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
    required String uid,
  }) {
        if (!snapshot.hasData) {
          return const Center(
            child: VibeYukleniyor(renk: VibeAppTheme.accent),
          );
        }

        final data = snapshot.data!.data() ?? {};
        final mascot = MascotServis.tryParse(_iyimserRobot ?? data['robot']);
        if (mascot == null) {
          return const Center(
            child: VibeYukleniyor(renk: VibeAppTheme.accent),
          );
        }
          final gorevDurumu = MascotServis.gunlukGorevlerAcik(mascot.seviye)
              ? HaftalikGorevServis.kullaniciVerisindenDurum(data)
              : null;
          final odaAcik = MascotServis.odaAcik(mascot.seviye);
          final uyuyor = mascot.uyuyor;
          final vibe = context.vibe;
          final onSurface = Theme.of(context).colorScheme.onSurface;

          if (!odaAcik) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MascotGelisimCercevesi(
                      progress: mascot.gelisimOrani,
                      size: 140,
                      strokeWidth: 4,
                      child: MascotLottieView(
                        seviye: mascot.seviye,
                        gorselDurum: mascot.gorselDurum,
                        renk: mascot.renk,
                        width: 120,
                        height: 120,
                        renkSecilebilir:
                            mascot.seviye >= MascotServis.odaAcilisSeviyesi,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Seviye ${mascot.seviye}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MascotRuhHaliMetni(
                      mascot: mascot,
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
                  'Seviye ${mascot.seviye}',
                  style: TextStyle(color: vibe.mutedText),
                ),
                const SizedBox(height: 8),
                MascotRuhHaliMetni(
                  mascot: mascot,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: VibeAppTheme.accent,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                MascotGelisimCercevesi(
                  progress: mascot.gelisimOrani,
                  size: 244,
                  strokeWidth: 5,
                  innerPadding: 6,
                  child: MascotLottieView(
                    seviye: mascot.seviye,
                    gorselDurum: mascot.gorselDurum,
                    renk: mascot.renk,
                    width: 220,
                    height: 220,
                    renkSecilebilir:
                        mascot.seviye >= MascotServis.odaAcilisSeviyesi,
                  ),
                ),
                const SizedBox(height: 20),
                if (MascotServis.vilCuzdaniAcik(mascot.seviye)) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Semantics(
                      label: MaestroSemantics.vilBakiyesi(mascot.vil),
                      child: Row(
                        children: [
                          VilRozeti(
                            miktar: mascot.vil,
                            jetonBoyutu: 26,
                            yaziBoyutu: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (MascotServis.toklukAktif(mascot.seviye))
                  MascotDurumBari(
                    etiket: 'Tokluk',
                    deger: mascot.tokluk,
                    renk: Colors.orangeAccent,
                    sayiGoster: false,
                  ),
                if (MascotServis.enerjiAktif(mascot.seviye))
                  MascotDurumBari(
                    etiket: 'Enerji',
                    deger: mascot.enerji,
                    renk: Colors.amber,
                    sayiGoster: false,
                  ),
                if (MascotServis.mutlulukAktif(mascot.seviye))
                  MascotDurumBari(
                    etiket: 'Mutluluk',
                    deger: mascot.mutluluk,
                    renk: Colors.redAccent,
                  ),
                const SizedBox(height: 24),
                if (gorevDurumu != null) ...[
                  HaftalikGorevKarti(
                    durum: gorevDurumu,
                    mascotUyuyor: uyuyor,
                  ),
                  const SizedBox(height: 24),
                ],
                if (uyuyor) ...[
                  if (MascotServis.uykuKalanSure(mascot) case final kalan?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Kalan dinlenme: ${_sureYaz(kalan)}',
                        style: TextStyle(color: vibe.mutedText, fontSize: 13),
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
                              await MascotServis.uyandir(uid);
                            }),
                  ),
                ] else ...[
                  if (MascotServis.yemekSistemiAcik(mascot.seviye))
                    _aksiyonButon(
                      label: 'Yemek',
                      icon: Icons.restaurant,
                      onPressed: _islemSuruyor ||
                              mascot.tokluk >= 100 ||
                              mascot.vil < MascotServis.yemekVilMaliyeti
                          ? null
                          : () async {
                                final devam = await VilHarcamaUyarisi.onayla(
                                  context: context,
                                  islem: VilHarcamaUyarisi.yemek,
                                  maliyet: MascotServis.yemekVilMaliyeti,
                                  vilHarcanacak: true,
                                );
                                if (!devam || !mounted || _islemSuruyor) return;
                                final ham = data['robot'] is Map
                                    ? Map<String, dynamic>.from(
                                        data['robot'] as Map,
                                      )
                                    : <String, dynamic>{};
                                late final Map<String, dynamic> robot;
                                try {
                                  robot = MascotServis.yemekHesapla(ham).robot;
                                } catch (e) {
                                  if (!mounted) return;
                                  vibeSnackbarGoster(
                                    context,
                                    internetAwareErrorMessage(
                                      error: e,
                                      fallback:
                                          'Yemek veya bakım şu an yapılamadı. Tekrar dene.',
                                    ),
                                  );
                                  return;
                                }
                                setState(() {
                                  _iyimserRobot = robot;
                                  _islemSuruyor = true;
                                });
                                unawaited(() async {
                                  try {
                                    await MascotServis.yemekVer(
                                      uid,
                                      anlikRobot: ham,
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    setState(() => _iyimserRobot = null);
                                    vibeSnackbarGoster(
                                      context,
                                      internetAwareErrorMessage(
                                        error: e,
                                        fallback:
                                            'Yemek veya bakım şu an yapılamadı. Tekrar dene.',
                                      ),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _islemSuruyor = false);
                                    }
                                  }
                                }());
                              },
                    ),
                  if (MascotServis.uyuSistemiAcik(mascot.seviye) &&
                      mascot.enerji <= MascotServis.uyuMaxEnerji)
                    _aksiyonButon(
                      label:
                          'Uyu (${MascotServis.uykuTahminiSureMetni(mascot.enerji)})',
                      icon: Icons.bedtime_outlined,
                      onPressed: _islemSuruyor
                          ? null
                          : () => _guvenliIslem(() async {
                                await MascotServis.uyuYap(uid);
                              }),
                    ),
                ],
              ],
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
