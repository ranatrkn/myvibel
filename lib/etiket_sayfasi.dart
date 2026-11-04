// Belirli hashtag'e ait gönderileri listeler.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/alinti_gonderi.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/feed_page.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';

// Hashtag gönderi listesi sayfası
class EtiketSayfasi extends StatefulWidget {
  const EtiketSayfasi({super.key, required this.etiket});

  final String etiket; // Görüntülenecek etiket adı

  @override
  State<EtiketSayfasi> createState() => _EtiketSayfasiState();
}

class _EtiketSayfasiState extends State<EtiketSayfasi> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _gonderiler = []; // Yüklenen gönderiler
  bool _yukleniyor = true;
  String? _hataMesaji;
  Set<String> _engelIdleri = {}; // Engellenen kullanıcılar
  Set<String> _takipEdilenIdler = {}; // Takip edilenler

  @override
  void initState() {
    super.initState();
    _gonderileriYukle();
  }

  // Firestore sayı alanını int'e çevirir
  int _intDeger(dynamic value, int varsayilan) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return varsayilan;
  }

  // Etiketli gönderileri Firestore'dan yükler
  Future<void> _gonderileriYukle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _yukleniyor = false;
        _hataMesaji = "Oturum bulunamadı.";
      });
      return;
    }

    setState(() {
      _yukleniyor = _gonderiler.isEmpty;
      _hataMesaji = null;
    });

    try {
      final sonuclar = await Future.wait([
        SosyalServis.engellenenKullanicilariGetir(user.uid),
        SosyalServis.beniEngelleyenKullanicilariGetir(user.uid),
        SosyalServis.takipEdilenIdleriGetir(user.uid),
      ]);
      _engelIdleri = {...sonuclar[0], ...sonuclar[1]};
      _takipEdilenIdler = sonuclar[2];

      final docs = await SosyalServis.hashtagGonderileriniGetir(
        widget.etiket,
        izleyiciUid: user.uid,
        takipEdilenIdler: _takipEdilenIdler,
        engelIdleri: _engelIdleri,
      );

      if (!mounted) return;
      setState(() {
        _gonderiler = docs;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hataMesaji = internetAwareErrorMessage(
          error: e,
          fallback: "Etiket gönderileri yüklenemedi.",
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final user = FirebaseAuth.instance.currentUser;

    return VibeGradientScaffold(
      appBar: AppBar(
        title: Text("#${widget.etiket}"),
      ),
      body: _yukleniyor
          ? Center(
              child: VibeYukleniyor(renk: theme.colorScheme.primary),
            )
          : _hataMesaji != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _hataMesaji!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: vibe.subtleText),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _gonderileriYukle,
                          child: const Text("Tekrar dene"),
                        ),
                      ],
                    ),
                  ),
                )
              : _gonderiler.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          "#${widget.etiket} etiketiyle gönderi bulunamadı.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: vibe.mutedText),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: VibeAppTheme.accent,
                      backgroundColor: theme.scaffoldBackgroundColor,
                      onRefresh: _gonderileriYukle,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 24),
                        itemCount: _gonderiler.length,
                        itemBuilder: (context, index) {
                          final doc = _gonderiler[index];
                          final post = doc.data();
                          return PostCard(
                            postId: doc.id,
                            postOwnerId: post["userId"] ?? "",
                            kullaniciAdi:
                                post["kullaniciAdi"] ?? "Vibe Kullanıcısı",
                            metin: post["metin"] ?? "",
                            mentionUidleri: SosyalServis.bahsetmeUidHaritasiParse(
                              post["mentionUidleri"],
                            ),
                            photoUrl: post["photoUrl"] ?? "",
                            avatarKey: post["avatarKey"] ?? "",
                            baslangicBegeniSayisi:
                                _intDeger(post["begeniSayisi"], 0),
                            baslangicYorumSayisi:
                                _intDeger(post["yorumSayisi"], 0),
                            userId: user?.uid ?? "",
                            createdAt: post["createdAt"],
                            ownerHesapGizli: post["ownerHesapGizli"] == true,
                            alintiSnapshot: AlintiGonderiSnapshot.haritadan(
                              post["alintiSnapshot"],
                              postId: post["alintiPostId"]?.toString(),
                              icAlintiDahilEt: false,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
