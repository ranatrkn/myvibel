import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/google_giris_servis.dart';
import 'package:myvibel/legal_pages.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 15–17 yaş hesabı için cihaz içi günlük süre ve ebeveyn PIN.
class EbeveynKontrol {
  EbeveynKontrol._();

  static const varsayilanDk = 90;
  static const minDk = 15;
  static const maxDk = 180;

  static String _pinAnahtar(String uid) => 'ebeveyn_pin_$uid';
  static String _sureAnahtar(String uid) => 'ebeveyn_sure_dk_$uid';
  static String _kullanimAnahtar(String uid, String gun) =>
      'ebeveyn_kullanim_${uid}_$gun';

  static String _gunKodu([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String pinOzeti(String pin) =>
      sha256.convert(utf8.encode('myvibel-ebeveyn:$pin')).toString();

  static Future<int> gunlukLimitDk(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_sureAnahtar(uid)) ?? varsayilanDk;
  }

  static Future<int> bugunKullanilanDk(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kullanimAnahtar(uid, _gunKodu())) ?? 0;
  }

  static Future<bool> pinVarMi(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_pinAnahtar(uid)) ?? '').isNotEmpty;
  }

  static Future<bool> pinDogruMu(String uid, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final kayit = prefs.getString(_pinAnahtar(uid)) ?? '';
    if (kayit.isEmpty) return false;
    return kayit == pinOzeti(pin);
  }

  static Future<void> pinVeSureKaydet({
    required String uid,
    required String pin,
    required int dakika,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dk = dakika.clamp(minDk, maxDk);
    await prefs.setString(_pinAnahtar(uid), pinOzeti(pin));
    await prefs.setInt(_sureAnahtar(uid), dk);
  }

  static Future<void> dakikaEkle(String uid, int dakika) async {
    if (dakika <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _kullanimAnahtar(uid, _gunKodu());
    final once = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, (once + dakika).clamp(0, 24 * 60));
  }
}

class EbeveynSureKapisi extends StatefulWidget {
  const EbeveynSureKapisi({super.key, required this.child});

  final Widget child;

  @override
  State<EbeveynSureKapisi> createState() => _EbeveynSureKapisiState();
}

class _EbeveynSureKapisiState extends State<EbeveynSureKapisi>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _limitDoldu = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_yenile());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_tik());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_yenile());
  }

  Future<void> _tik() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await EbeveynKontrol.dakikaEkle(uid, 1);
    await _yenile();
  }

  Future<void> _yenile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final limit = await EbeveynKontrol.gunlukLimitDk(uid);
    final kullanilan = await EbeveynKontrol.bugunKullanilanDk(uid);
    if (!mounted) return;
    setState(() {
      _limitDoldu = kullanilan >= limit;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_limitDoldu) return widget.child;
    return _SureDolduEkrani(onPinIleAc: _yenile);
  }
}

class _SureDolduEkrani extends StatelessWidget {
  const _SureDolduEkrani({required this.onPinIleAc});

  final Future<void> Function() onPinIleAc;

  @override
  Widget build(BuildContext context) {
    return VibeGradientScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_bottom, size: 48),
              const SizedBox(height: 16),
              Text(
                'Günlük kullanım süresi doldu.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ebeveyn PIN’i ile süre artırılabilir. Süre yarın sıfırlanır.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  final oldu = await ebeveynPinIleSureAc(context);
                  if (oldu) await onPinIleAc();
                },
                child: const Text('Ebeveyn PIN ile aç'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => tekSeferContactYasItiraz(context),
                child: const Text('İtiraz et'),
              ),
              TextButton(
                onPressed: () => GoogleGirisServis.oturumuKapat(),
                child: const Text('Çıkış yap'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void tekSeferContactYasItiraz(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const ContactPage(ilkKategori: 'yas_itiraz'),
    ),
  );
}

Future<bool> ebeveynPinIleSureAc(BuildContext context) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return false;
  final pinVar = await EbeveynKontrol.pinVarMi(uid);
  if (!context.mounted) return false;
  if (!pinVar) {
    return ebeveynAyarPaneliniAc(context);
  }
  final pin = await _pinSor(context, 'Ebeveyn PIN');
  if (pin == null) return false;
  if (!await EbeveynKontrol.pinDogruMu(uid, pin)) {
    if (context.mounted) {
      vibeSnackbarGoster(
        context,
        'PIN hatalı.',
        tip: VibeMesajTipi.hata,
      );
    }
    return false;
  }
  await EbeveynKontrol.dakikaEkle(uid, -30);
  return true;
}

Future<bool> ebeveynAyarPaneliniAc(BuildContext context) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return false;
  final pinVar = await EbeveynKontrol.pinVarMi(uid);
  final mevcutSure = await EbeveynKontrol.gunlukLimitDk(uid);
  if (!context.mounted) return false;

  final pinCtrl = TextEditingController();
  final yeniPinCtrl = TextEditingController();
  var dakika = mevcutSure.toDouble();
  var kaydedildi = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ebeveyn kontrolleri',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Günlük süre varsayılan 90 dakikadır. Değiştirmek için PIN gerekir. '
                  'Gerçek para harcaması yoktur.',
                ),
                const SizedBox(height: 12),
                if (pinVar)
                  TextField(
                    controller: pinCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'Mevcut PIN',
                    ),
                  ),
                TextField(
                  controller: yeniPinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: InputDecoration(
                    labelText: pinVar ? 'Yeni PIN (isteğe bağlı)' : 'PIN belirle (4–8 hane)',
                  ),
                ),
                Text('Günlük süre: ${dakika.round()} dk'),
                Slider(
                  min: EbeveynKontrol.minDk.toDouble(),
                  max: EbeveynKontrol.maxDk.toDouble(),
                  divisions: (EbeveynKontrol.maxDk - EbeveynKontrol.minDk) ~/ 5,
                  value: dakika,
                  onChanged: (v) => setLocal(() => dakika = v),
                ),
                FilledButton(
                  onPressed: () async {
                    if (pinVar) {
                      if (!await EbeveynKontrol.pinDogruMu(uid, pinCtrl.text)) {
                        if (ctx.mounted) {
                          vibeSnackbarGoster(
                            ctx,
                            'PIN hatalı.',
                            tip: VibeMesajTipi.hata,
                          );
                        }
                        return;
                      }
                    }
                    final yeniPin = yeniPinCtrl.text.trim();
                    final pin = yeniPin.isNotEmpty
                        ? yeniPin
                        : (pinVar ? pinCtrl.text : '');
                    if (pin.length < 4) {
                      if (ctx.mounted) {
                        vibeSnackbarGoster(
                          ctx,
                          'PIN en az 4 hane olmalı.',
                          tip: VibeMesajTipi.uyari,
                        );
                      }
                      return;
                    }
                    await EbeveynKontrol.pinVeSureKaydet(
                      uid: uid,
                      pin: pin,
                      dakika: dakika.round(),
                    );
                    kaydedildi = true;
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  pinCtrl.dispose();
  yeniPinCtrl.dispose();
  return kaydedildi;
}

Future<String?> _pinSor(BuildContext context, String baslik) async {
  final ctrl = TextEditingController();
  final sonuc = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(baslik),
      content: TextField(
        controller: ctrl,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 8,
        decoration: const InputDecoration(hintText: 'PIN'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Tamam'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return (sonuc == null || sonuc.isEmpty) ? null : sonuc;
}
