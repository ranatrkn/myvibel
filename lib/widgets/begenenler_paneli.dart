// Gönderi sahibinin beğenenler listesi
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/vibe_avatar.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';

void begenenlerPaneliniAc(BuildContext context, {required String postId}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.vibe.sheetBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (context) => BegenenlerPaneli(postId: postId),
  );
}

class BegenenlerPaneli extends StatefulWidget {
  final String postId;

  const BegenenlerPaneli({super.key, required this.postId});

  @override
  State<BegenenlerPaneli> createState() => _BegenenlerPaneliState();
}

class _BegenenlerPaneliState extends State<BegenenlerPaneli> {
  final List<BegenenKayit> _kayitlar = [];
  DocumentSnapshot<Map<String, dynamic>>? _sonBelge;
  bool _yukleniyor = true;
  bool _devamYukleniyor = false;
  bool _devamVar = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle({bool devam = false}) async {
    if (devam) {
      if (_devamYukleniyor || !_devamVar) return;
      _devamYukleniyor = true;
      setState(() {});
    } else {
      setState(() {
        _yukleniyor = true;
        _hata = null;
      });
    }

    try {
      final sayfa = await SosyalServis.begenenleriGetir(
        postId: widget.postId,
        baslangic: devam ? _sonBelge : null,
      );
      if (!mounted) return;
      setState(() {
        if (devam) {
          _kayitlar.addAll(sayfa.kayitlar);
        } else {
          _kayitlar
            ..clear()
            ..addAll(sayfa.kayitlar);
        }
        _sonBelge = sayfa.sonBelge;
        _devamVar = sayfa.devamVar;
        _yukleniyor = false;
        _devamYukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _devamYukleniyor = false;
        _hata = internetAwareErrorMessage(
          error: e,
          fallback: 'Beğenenler yüklenemedi.',
        );
      });
      if (devam) {
        vibeSnackbarGoster(context, _hata!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final yukseklik = MediaQuery.of(context).size.height * 0.62;

    return SizedBox(
      height: yukseklik,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: vibe.cardBorder,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Beğenenler',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Divider(color: theme.dividerColor),
          Expanded(
            child: _yukleniyor
                ? Center(
                    child: VibeYukleniyor(
                      renk: theme.colorScheme.primary,
                    ),
                  )
                : _hata != null && _kayitlar.isEmpty
                    ? Center(
                        child: Text(
                          _hata!,
                          style: TextStyle(color: vibe.mutedText),
                        ),
                      )
                    : _kayitlar.isEmpty
                        ? Center(
                            child: Text(
                              'Henüz beğeni yok.',
                              style: TextStyle(color: vibe.mutedText),
                            ),
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification.metrics.extentAfter < 240) {
                                _yukle(devam: true);
                              }
                              return false;
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                              itemCount:
                                  _kayitlar.length + (_devamYukleniyor ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= _kayitlar.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: VibeYukleniyor(),
                                    ),
                                  );
                                }
                                final kayit = _kayitlar[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: vibe.satirKart(),
                                  child: ListTile(
                                    onTap: () {
                                      Navigator.pop(context);
                                      profiliAc(context, kayit.userId);
                                    },
                                    leading: vibeAvatar(
                                      radius: 22,
                                      userId: kayit.userId,
                                      photoUrl: kayit.photoUrl,
                                      avatarKey: kayit.avatarKey,
                                      fallbackText: kayit.kullaniciAdi,
                                      emojiSize: 18,
                                    ),
                                    title: Text(
                                      kayit.adSoyad,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '@${kayit.kullaniciAdi}',
                                      style: TextStyle(
                                        color: vibe.mutedText,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
