// Yeni gönderi oluşturma sayfası.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/alinti_gonderi.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/icerik_filtre_servis.dart';
import 'package:myvibel/haftalik_gorev_servis.dart';
import 'package:myvibel/puan_animasyon.dart';
import 'package:myvibel/maestro_semantics.dart';
import 'package:myvibel/maskot_servis.dart';
import 'package:myvibel/sosyal/sosyal_core.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/widgets/alinti_gonderi_onizleme.dart';
import 'package:myvibel/widgets/bahsetme_metin_alani.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/maskot_lottie_view.dart';
import 'package:myvibel/widgets/vibe_avatar.dart';
import 'package:myvibel/widgets/vibe_ikonlar.dart';

// Gönderi paylaşım formu
class NewPostPage extends StatefulWidget {
  final VoidCallback? onPostCreated;
  final AlintiGonderiBaglam? alintiBaglam;
  final VoidCallback? onAlintiIptal;

  const NewPostPage({
    super.key,
    this.onPostCreated,
    this.alintiBaglam,
    this.onAlintiIptal,
  });

  @override
  State<NewPostPage> createState() => _NewPostPageState();
}

class _NewPostPageState extends State<NewPostPage> {
  final TextEditingController postController =
      TextEditingController(); // Gönderi metni
  bool isLoading = false; // Paylaşım sürüyor mu
  Timer? _hizTimer;
  int _kalanPaylasimMs = 0;
  // build içinde açılırsa her setState'te abonelik yenilenir, kart titrer.
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _kullaniciAkisi =
      FirebaseAuth.instance.currentUser == null
          ? const Stream.empty()
          : FirebaseFirestore.instance
              .collection("users")
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .snapshots();

  @override
  void initState() {
    super.initState();
    _hizTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _hizLimitiniGuncelle();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(SosyalCore.rateLimitPrefsYukle().then((_) {
        if (mounted) _hizLimitiniGuncelle();
      }));
    });
  }

  void _hizLimitiniGuncelle() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final kalan = SosyalCore.gonderiPaylasimKalanMs(uid);
    if (kalan == _kalanPaylasimMs) return;
    setState(() => _kalanPaylasimMs = kalan);
  }

  @override
  void dispose() {
    _hizTimer?.cancel();
    postController.dispose();
    super.dispose();
  }

  // Gönderiyi Firestore'a kaydeder ve puan/görev günceller
  Future<void> gonderiPaylas() async {
    final metin = postController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      mesajGoster("Kullanıcı bulunamadı. Tekrar giriş yap.");
      return;
    }

    if (metin.isEmpty) {
      mesajGoster("Paylaşmak için bir şeyler yaz.");
      return;
    }

    if (metin.length > SosyalCore.gonderiMetinMaxKarakter) {
      mesajGoster(
        "Gönderi en fazla ${SosyalCore.gonderiMetinMaxKarakter} karakter olabilir.",
      );
      return;
    }

    if (IcerikFiltreServis.uygunsuzMu(metin)) {
      mesajGoster(IcerikFiltreServis.uygunsuzMetinHata);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await SosyalServis.gonderiPaylasimHizLimitiKontrol(user.uid);
      await MascotServis.etkilesimEngelliyseAt(
        user.uid,
        aksiyonTipi: 'gonderi',
      );

      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final kullaniciAdi =
          userData?["kullaniciAdi"] ?? user.displayName ?? "Vibe Kullanıcısı";
      final avatarKey = (userData?["avatarKey"] ?? "").toString();
      final photoUrl = vibeDenormalizePhotoUrl(
        avatarKey: avatarKey,
        photoUrl: userData?["photoUrl"]?.toString(),
        authPhotoUrl: user.photoURL,
      );

      final hesapGizli = userData?["hesapGizli"] == true;
      final mentionUidleri = await SosyalServis.bahsetmeUidleriniCoz(metin);

      Map<String, dynamic>? alintiAlanlari;
      final alinti = widget.alintiBaglam;
      if (alinti != null) {
        final alintiSnap = await SosyalCore.gonderiRef(alinti.postId)
            .get();
        if (!alintiSnap.exists) {
          mesajGoster('Alıntılanan gönderi bulunamadı.');
          return;
        }
        final alintiPost = alintiSnap.data() ?? {};
        if (alintiPost['ownerHesapGizli'] == true) {
          mesajGoster('Gizli hesap gönderileri alıntılanamaz.');
          return;
        }
        if (alintiPost['raporNedeniyleGizli'] == true) {
          mesajGoster('Bu gönderi alıntılanamaz.');
          return;
        }
        alintiAlanlari = {
          'alintiPostId': alinti.postId,
          'alintiSnapshot': AlintiGonderiSnapshot.gonderiden(
            alinti.postId,
            alintiPost,
            icAlintiDahilEt: false,
          ).toMap(),
        };
      }

      if (!userDoc.exists) {
        mesajGoster('Profilin henüz hazır değil. Çıkış yapıp tekrar giriş dene.');
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final postRef = firestore.collection("posts").doc();
      final userRef = firestore.collection("users").doc(user.uid);
      final postVerisi = {
        "userId": user.uid,
        "kullaniciAdi": kullaniciAdi,
        "photoUrl": photoUrl,
        "avatarKey": avatarKey,
        "metin": metin,
        "tags": SosyalServis.etiketleriAyikla(metin),
        "bahsetmeler": SosyalServis.bahsetmeleriAyikla(metin),
        "mentionUidleri": mentionUidleri,
        "begeniSayisi": 0,
        "yorumSayisi": 0,
        "skor": 0,
        "sikayetSayisi": 0,
        "raporNedeniyleGizli": false,
        "ownerHesapGizli": hesapGizli,
        "createdAt": FieldValue.serverTimestamp(),
        ...?alintiAlanlari,
      };

      try {
        await firestore.runTransaction((tx) async {
          final userSnap = await tx.get(userRef);
          if (!userSnap.exists) {
            throw 'Profil bulunamadı. Tekrar giriş yap.';
          }
          tx.set(postRef, postVerisi);
          tx.update(userRef, {
            "puan": FieldValue.increment(10),
            "gonderiSayisi": FieldValue.increment(1),
            "sonGonderiPuanPostId": postRef.id,
          });
        });
      } on FirebaseException catch (e) {
        mesajGoster(
          internetAwareErrorMessage(
            error: e,
            fallback: 'Gönderi yazılamadı. Biraz sonra tekrar dene.',
          ),
        );
        return;
      }

      await SosyalServis.gonderiPaylasimHizLimitiKaydet(user.uid);

      try {
        await MascotServis.sosyalOdulKaydet(user.uid, MascotServis.vilGonderi);
      } catch (e) {
        debugPrint('gonderi maskot odul: $e');
      }

      if (mentionUidleri.isNotEmpty) {
        try {
          await SosyalServis.bahsetmeBildirimleriGonder(
            gonderenUid: user.uid,
            mentionUidleri: mentionUidleri,
            kaynak: "post",
            postId: postRef.id,
          );
        } catch (e) {
          debugPrint('bahsetme bildirim: $e');
        }
      }

      HaftalikGorevSonuc? gorevSonuc;
      try {
        gorevSonuc = await HaftalikGorevServis.aksiyonKaydet(
          user.uid,
          GorevAksiyon.gonderi,
        );
      } catch (e) {
        debugPrint('haftalik gorev: $e');
      }
      try {
        await MascotServis.sosyalAksiyon(user.uid, 'gonderi');
      } catch (e) {
        debugPrint('sosyalAksiyon gonderi: $e');
      }

      postController.clear();

      if (!mounted) return;

      mesajGoster('Gönderi paylaşıldı.', tip: VibeMesajTipi.basari);
      puanAnimasyonuGoster(context, 10);
      if (gorevSonuc != null && gorevSonuc.basarili) {
        for (final mesaj in gorevSonuc.mesajlar) {
          mesajGoster(mesaj, tip: VibeMesajTipi.basari);
        }
      } else if (gorevSonuc?.hata != null &&
          gorevSonuc!.hata != HaftalikGorevServis.gorevlerAcilmaHatasi) {
        mesajGoster(gorevSonuc.hata!, tip: VibeMesajTipi.uyari);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      widget.onPostCreated?.call();
    } catch (e) {
      mesajGoster(
        internetAwareErrorMessage(
          error: e,
          fallback: 'Gönderi yazılamadı. Biraz sonra tekrar dene.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _hizLimitiniGuncelle();
      }
    }
  }

  void mesajGoster(String mesaj, {VibeMesajTipi tip = VibeMesajTipi.hata}) {
    vibeSnackbarGoster(context, mesaj, tip: tip);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final vibe = context.vibe;

    final ekranYuksekligi = MediaQuery.sizeOf(context).height;
    final gonderiKutusuYuksekligi =
        (ekranYuksekligi * 0.27).clamp(220.0, 290.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.alintiBaglam != null
                            ? 'Alıntılı Gönderi'
                            : 'Yeni Gönderi Oluştur',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                      if (widget.alintiBaglam != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: AlintiGonderiOnizleme(
                                snapshot: widget.alintiBaglam!.snapshot,
                                currentUserId: user?.uid,
                                detayaGit: false,
                              ),
                            ),
                            maestroButton(
                              label: MaestroSemantics.alintiyiKaldir,
                              onTap: widget.onAlintiIptal,
                              child: IconButton(
                                onPressed: widget.onAlintiIptal,
                                icon: Icon(Icons.close, color: vibe.mutedText),
                                tooltip: MaestroSemantics.alintiyiKaldir,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        height: gonderiKutusuYuksekligi,
                        child: Container(
                          width: double.infinity,
                          decoration: vibe.kahramanKart(radius: 20),
                          clipBehavior: Clip.antiAlias,
                          child: Semantics(
                            label: MaestroSemantics.gonderiMetni,
                            textField: true,
                            child: BahsetmeMetinAlani(
                              controller: postController,
                              haricUid: user?.uid,
                              expands: true,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 16,
                                height: 1.45,
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                hintText: widget.alintiBaglam != null
                                    ? 'Yorumunu ekle...'
                                    : 'Bugün vibe\'ın nasıl?',
                                hintStyle: TextStyle(color: vibe.mutedText),
                                contentPadding: const EdgeInsets.all(18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide.none,
                                ),
                                filled: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: maestroButton(
                          label: widget.alintiBaglam != null
                              ? MaestroSemantics.alintiyiPaylas
                              : MaestroSemantics.paylas,
                          onTap: isLoading || _kalanPaylasimMs > 0
                              ? null
                              : gonderiPaylas,
                          child: ElevatedButton.icon(
                          onPressed: isLoading || _kalanPaylasimMs > 0
                              ? null
                              : gonderiPaylas,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Icon(VibeIkon.gonder),
                          label: Text(
                            isLoading
                                ? 'Paylaşılıyor...'
                                : _kalanPaylasimMs > 0
                                    ? 'Paylaş (${(_kalanPaylasimMs / 1000).ceil()} sn)'
                                    : widget.alintiBaglam != null
                                        ? 'Alıntıyı paylaş'
                                        : 'Paylaş',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: vibe.primaryButton,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: _kullaniciAkisi,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox.shrink();
                          }
                          final data = snapshot.data?.data();
                          final mascot = MascotServis.tryParse(data?["robot"]);
                          if (mascot == null) {
                            return const SizedBox.shrink();
                          }
                          final seviye = mascot.seviye;
                          final mascotIsmi = mascot.isim.trim();
                          final gosterilecekIsim =
                              mascotIsmi.isEmpty ? "Vibel" : mascotIsmi;
                          final yumurtaDonemi =
                              seviye < MascotServis.toklukAcilisSeviyesi;

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: vibe.cardDecoration(radius: 18),
                            child: Row(
                              children: [
                                MascotLottieView(
                                  seviye: seviye,
                                  gorselDurum: mascot.gorselDurum,
                                  renk: mascot.renk,
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.contain,
                                  tamEkranAc: false,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    yumurtaDonemi
                                        ? "Her gönderi $gosterilecekIsim için +${MascotServis.vilGonderi} gelişim puanı."
                                        : "Her gönderi +${MascotServis.vilGonderi} vil kazandırır.",
                                    style: TextStyle(
                                      color: vibe.subtleText,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
