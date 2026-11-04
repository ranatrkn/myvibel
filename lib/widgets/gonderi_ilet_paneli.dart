// Gönderiyi takip edilenlere DM ile iletme paneli.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/error_messages.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/vibe_snackbar.dart';
import 'package:myvibel/widgets/vibe_avatar.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';
import 'package:myvibel/widgets/vibe_ikonlar.dart';

// Alt sayfa olarak gönderi iletme panelini açar
Future<void> gonderiIletPaneliniGoster({
  required BuildContext context,
  required String postId,
  required String postMetin,
  required String postKullaniciAdi,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.vibe.sheetBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return _GonderiIletPaneli(
        ustContext: context,
        postId: postId,
        postMetin: postMetin,
        postKullaniciAdi: postKullaniciAdi,
      );
    },
  );
}

// Gönderi iletme alt sayfa içeriği
class _GonderiIletPaneli extends StatefulWidget {
  final BuildContext ustContext;
  final String postId;
  final String postMetin;
  final String postKullaniciAdi;

  const _GonderiIletPaneli({
    required this.ustContext,
    required this.postId,
    required this.postMetin,
    required this.postKullaniciAdi,
  });

  @override
  State<_GonderiIletPaneli> createState() => _GonderiIletPaneliState();
}

class _GonderiIletPaneliState extends State<_GonderiIletPaneli> {
  late Future<List<Map<String, dynamic>>> _profillerFuture;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    _profillerFuture = SosyalServis.takipEdilenProfilleriGetir(uid);
  }

  // Seçilen kullanıcıya gönderiyi iletir (panel hemen kapanır, gönderim arka planda)
  Future<void> _ilet(String hedefUid) async {
    final ust = widget.ustContext;
    Navigator.pop(context);
    vibeSnackbarGoster(ust, "Gönderi iletildi.", tip: VibeMesajTipi.basari);
    try {
      await SosyalServis.gonderiIlet(
        postId: widget.postId,
        hedefUid: hedefUid,
        postMetin: widget.postMetin,
        postKullaniciAdi: widget.postKullaniciAdi,
      );
    } catch (e) {
      if (!ust.mounted) return;
      ScaffoldMessenger.of(ust).hideCurrentSnackBar();
      vibeSnackbarGoster(
        ust,
        internetAwareErrorMessage(
          error: e,
          fallback: "Gönderi iletilemedi.",
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: vibe.cardBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "Gönderiyi İlet",
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Takip ettiklerinden birine DM ile iletebilirsin.",
              style: TextStyle(color: vibe.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _profillerFuture,
                builder: (context, snapshot) {
                  // Panel yüklenirken tam ekran açılıp sonra küçülmesin
                  Widget sabitAlan(Widget child) =>
                      SizedBox(height: 180, child: Center(child: child));

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return sabitAlan(
                      VibeYukleniyor(renk: theme.colorScheme.primary),
                    );
                  }

                  if (snapshot.hasError) {
                    return sabitAlan(
                      Text(
                        "Takip edilenler yüklenemedi.",
                        style: TextStyle(color: vibe.mutedText),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final profiller = snapshot.data ?? [];
                  if (profiller.isEmpty) {
                    return sabitAlan(
                      Text(
                        "İletmek için önce birini takip et.",
                        style: TextStyle(color: vibe.mutedText),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: profiller.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = profiller[index];
                      final uid = p["uid"] as String;
                      final adSoyad = p["adSoyad"] as String;
                      final kullaniciAdi = p["kullaniciAdi"] as String;

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: vibe.cardBorder),
                        ),
                        tileColor: vibe.cardColor,
                        leading: vibeAvatar(
                          radius: 20,
                          userId: uid,
                          photoUrl: (p["photoUrl"] ?? "").toString(),
                          avatarKey: (p["avatarKey"] ?? "").toString(),
                          fallbackText: kullaniciAdi,
                          emojiSize: 16,
                        ),
                        title: Text(
                          adSoyad,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          "@$kullaniciAdi",
                          style: TextStyle(color: vibe.mutedText),
                        ),
                        trailing: Icon(VibeIkon.gonder, color: vibe.mutedText),
                        onTap: () => _ilet(uid),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
