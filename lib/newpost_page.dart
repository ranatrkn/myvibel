// Yeni gönderi oluşturma sayfası.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibe_life/alinti_gonderi.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/icerik_filtre_servis.dart';
import 'package:vibe_life/haftalik_gorev_servis.dart';
import 'package:vibe_life/puan_animasyon.dart';
import 'package:vibe_life/maskot_servis.dart';
import 'package:vibe_life/sosyal/sosyal_core.dart';
import 'package:vibe_life/sosyal_servis.dart';
import 'package:vibe_life/widgets/alinti_gonderi_onizleme.dart';
import 'package:vibe_life/widgets/bahsetme_metin_alani.dart';
import 'package:vibe_life/vibe_snackbar.dart';
import 'package:vibe_life/widgets/maskot_lottie_view.dart';

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

  @override
  void dispose() {
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
      final photoUrl =
          (userData?["photoUrl"] ?? user.photoURL ?? "").toString();
      final avatarKey = (userData?["avatarKey"] ?? "").toString();

      final hesapGizli = userData?["hesapGizli"] == true;
      final mentionUidleri = await SosyalServis.bahsetmeUidleriniCoz(metin);

      Map<String, dynamic>? alintiAlanlari;
      final alinti = widget.alintiBaglam;
      if (alinti != null) {
        final alintiSnap = await FirebaseFirestore.instance
            .collection('posts')
            .doc(alinti.postId)
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
          ).toMap(),
        };
      }

      final firestore = FirebaseFirestore.instance;
      final postRef = firestore.collection("posts").doc();
      final batch = firestore.batch();

      batch.set(postRef, {
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
      });
      batch.update(firestore.collection("users").doc(user.uid), {
        "puan": FieldValue.increment(10),
        "gonderiSayisi": FieldValue.increment(1),
        "sonGonderiPuanPostId": postRef.id,
      });

      try {
        await batch.commit();
      } on FirebaseException catch (e) {
        mesajGoster(_firestoreHataMesaji(e));
        return;
      }

      await SosyalServis.gonderiPaylasimHizLimitiKaydet(user.uid);
      unawaited(MascotServis.sosyalOdulKaydet(user.uid, MascotServis.vilGonderi));

      if (mentionUidleri.isNotEmpty) {
        await SosyalServis.bahsetmeBildirimleriGonder(
          gonderenUid: user.uid,
          mentionUidleri: mentionUidleri,
          kaynak: "post",
          postId: postRef.id,
        );
      }

      final gorevSonuc = await HaftalikGorevServis.aksiyonKaydet(
        user.uid,
        GorevAksiyon.gonderi,
      );
      await MascotServis.sosyalAksiyon(user.uid, 'gonderi');

      postController.clear();

      if (!mounted) return;

      puanAnimasyonuGoster(context, 10);
      if (gorevSonuc.basarili) {
        for (final mesaj in gorevSonuc.mesajlar) {
          mesajGoster(mesaj, tip: VibeMesajTipi.basari);
        }
      } else if (gorevSonuc.hata != null &&
          gorevSonuc.hata != HaftalikGorevServis.gorevlerAcilmaHatasi) {
        mesajGoster(gorevSonuc.hata!, tip: VibeMesajTipi.uyari);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      widget.onPostCreated?.call();
    } catch (e) {
      mesajGoster(
        internetAwareErrorMessage(
          error: e,
          fallback: "Gönderi paylaşılamadı.",
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Firestore hata kodunu mesaja çevirir
  String _firestoreHataMesaji(FirebaseException e) {
    if (e.code == "permission-denied") {
      return "Gönderi paylaşılamadı. Lütfen tekrar dene.";
    }
    return "Gönderi kaydedilemedi. Lütfen tekrar dene.";
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
                            IconButton(
                              onPressed: widget.onAlintiIptal,
                              icon: Icon(Icons.close, color: vibe.mutedText),
                              tooltip: 'Alıntıyı kaldır',
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        height: gonderiKutusuYuksekligi,
                        child: Container(
                          width: double.infinity,
                          decoration: vibe.cardDecoration(),
                          clipBehavior: Clip.antiAlias,
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
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : gonderiPaylas,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            isLoading
                                ? 'Paylaşılıyor...'
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
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: user != null
                            ? FirebaseFirestore.instance
                                .collection("users")
                                .doc(user.uid)
                                .snapshots()
                            : const Stream.empty(),
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
                              mascotIsmi.isEmpty ? "maskotun" : mascotIsmi;

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
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.contain,
                                  tamEkranAc: false,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Her paylaşım $gosterilecekIsim için puan kazandırır.",
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
