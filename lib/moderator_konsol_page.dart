// Birleşik moderatör konsolu — telefon + geniş ekran (PC).
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/destek_talepleri_panel_page.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/hesap_silme_geri_bildirim_panel.dart';
import 'package:myvibel/moderasyon_panel_page.dart';
import 'package:myvibel/moderator/mod_ortak.dart';
import 'package:myvibel/sosyal/moderasyon_servis.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';

class ModeratorKonsolPage extends StatefulWidget {
  const ModeratorKonsolPage({
    super.key,
    this.masaustuModu = false,
    this.onCikis,
  });

  /// true: Windows/web uygulamasında kök sayfa; geri yerine çıkış.
  final bool masaustuModu;
  final VoidCallback? onCikis;

  @override
  State<ModeratorKonsolPage> createState() => _ModeratorKonsolPageState();
}

class _ModeratorKonsolPageState extends State<ModeratorKonsolPage> {
  bool _erisimKontrolEdiliyor = true;
  bool _erisimVar = false;
  int _secilen = 0;

  static const _basliklar = [
    'Şikayetler',
    'Destek & Öneriler',
    'Hesap silme',
  ];

  static const _aciklamalar = [
    'Kullanıcıların bildirdiği gönderi, yorum ve hesaplar. '
        'Gönderi 5, yorum 4 şikayete ulaşınca otomatik gizlenir; son kararı sen verirsin.',
    'Uygulamadan gönderilen destek talepleri, hata bildirimleri ve öneriler.',
    'Hesabını silen kullanıcıların seçtiği nedenler ve bıraktığı notlar.',
  ];

  static const _ikonlar = [
    (Icons.flag_outlined, Icons.flag),
    (Icons.support_agent_outlined, Icons.support_agent),
    (Icons.person_off_outlined, Icons.person_off),
  ];

  static const _kisaEtiketler = ['Şikayetler', 'Destek', 'Hesap silme'];

  late final Stream<int> _bekleyenSikayet = FirebaseFirestore.instance
      .collection('reports')
      .where('status', isEqualTo: 'pending')
      .limit(500)
      .snapshots()
      .map((s) => s.size);

  late final Stream<int> _bekleyenTalep = FirebaseFirestore.instance
      .collection('supportTickets')
      .where('status', isEqualTo: 'pending')
      .limit(500)
      .snapshots()
      .map((s) => s.size);

  int _sikayetSayisi = 0;
  int _talepSayisi = 0;
  StreamSubscription<int>? _sikayetAbonelik;
  StreamSubscription<int>? _talepAbonelik;

  void _sayaclariBaslat() {
    _sikayetAbonelik ??= _bekleyenSikayet.listen(
      (n) {
        if (mounted) setState(() => _sikayetSayisi = n);
      },
      onError: (_) {},
    );
    _talepAbonelik ??= _bekleyenTalep.listen(
      (n) {
        if (mounted) setState(() => _talepSayisi = n);
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _sikayetAbonelik?.cancel();
    _talepAbonelik?.cancel();
    super.dispose();
  }

  int _bekleyen(int indeks) => switch (indeks) {
        0 => _sikayetSayisi,
        1 => _talepSayisi,
        _ => 0,
      };

  Widget _rozetliIkon(int indeks, {required bool secili}) {
    final n = _bekleyen(indeks);
    final ikon = Icon(secili ? _ikonlar[indeks].$2 : _ikonlar[indeks].$1);
    return Badge(
      isLabelVisible: n > 0,
      label: Text(n > 99 ? '99+' : '$n'),
      child: ikon,
    );
  }

  static const _sayfalar = [
    ModerasyonPanelPage(gomulu: true),
    DestekTalepleriPanelPage(gomulu: true),
    HesapSilmeGeriBildirimPanel(gomulu: true),
  ];

  @override
  void initState() {
    super.initState();
    _erisimiDogrula();
  }

  Future<void> _erisimiDogrula() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      if (widget.masaustuModu) {
        widget.onCikis?.call();
      } else {
        Navigator.pop(context);
      }
      return;
    }

    try {
      final yetkili = await ModerasyonServis.moderatorMu(uid);
      if (!mounted) return;
      if (!yetkili) {
        vibeSnackbarGoster(
          context,
          'Bu alana erişim yetkin yok.',
          tip: VibeMesajTipi.uyari,
        );
        if (widget.masaustuModu) {
          widget.onCikis?.call();
        } else {
          Navigator.pop(context);
        }
        return;
      }
      setState(() {
        _erisimVar = true;
        _erisimKontrolEdiliyor = false;
      });
      _sayaclariBaslat();
    } catch (e) {
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: 'Erişim doğrulanamadı.',
        ),
      );
      if (widget.masaustuModu) {
        widget.onCikis?.call();
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;

    if (_erisimKontrolEdiliyor || !_erisimVar) {
      return VibeGradientScaffold(
        appBar: widget.masaustuModu
            ? null
            : VibeGradientScaffold.seffafBaslik('Moderatör Konsolu'),
        body: const Center(child: VibeYukleniyor()),
      );
    }

    final icerik = IndexedStack(
      index: _secilen,
      children: _sayfalar,
    );

    return LayoutBuilder(
      builder: (context, kisit) {
        final genis = kisit.maxWidth >= 900;
        final onSurface = Theme.of(context).colorScheme.onSurface;

        PreferredSizeWidget? appBar;
        if (!widget.masaustuModu || !genis) {
          appBar = VibeGradientScaffold.seffafBaslik(
            genis
                ? 'Moderatör Konsolu'
                : 'Moderatör · ${_kisaEtiketler[_secilen]}',
            actions: widget.masaustuModu
                ? [
                    TextButton(
                      onPressed: widget.onCikis,
                      child: Text(
                        'Çıkış',
                        style: TextStyle(color: vibe.mutedText),
                      ),
                    ),
                  ]
                : null,
          );
        }

        if (genis) {
          final bekleyen = _bekleyen(_secilen);
          return VibeGradientScaffold(
            appBar: appBar,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _secilen,
                  onDestinationSelected: (i) => setState(() => _secilen = i),
                  labelType: NavigationRailLabelType.all,
                  minWidth: 96,
                  leading: widget.masaustuModu
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: [
                              Icon(
                                Icons.admin_panel_settings,
                                color: vibe.primaryButton,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Moderatör',
                                style: TextStyle(
                                  color: vibe.mutedText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (widget.onCikis != null) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: widget.onCikis,
                                  child: const Text('Çıkış'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : null,
                  destinations: [
                    for (var i = 0; i < _kisaEtiketler.length; i++)
                      NavigationRailDestination(
                        icon: _rozetliIkon(i, secili: false),
                        selectedIcon: _rozetliIkon(i, secili: true),
                        label: Text(_kisaEtiketler[i]),
                      ),
                  ],
                ),
                VerticalDivider(width: 1, color: vibe.cardBorder),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ModIcerikGenisligi(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _basliklar[_secilen],
                                    style: TextStyle(
                                      color: onSurface,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (bekleyen > 0) ...[
                                    const SizedBox(width: 10),
                                    ModRozet(
                                      metin: '$bekleyen bekleyen',
                                      renk: Colors.orange,
                                      ikon: Icons.schedule,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _aciklamalar[_secilen],
                                style: TextStyle(
                                  color: vibe.mutedText,
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(child: icerik),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return VibeGradientScaffold(
          appBar: appBar,
          body: icerik,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _secilen,
            onDestinationSelected: (i) => setState(() => _secilen = i),
            destinations: [
              for (var i = 0; i < _kisaEtiketler.length; i++)
                NavigationDestination(
                  icon: _rozetliIkon(i, secili: false),
                  selectedIcon: _rozetliIkon(i, secili: true),
                  label: _kisaEtiketler[i],
                ),
            ],
          ),
        );
      },
    );
  }
}
