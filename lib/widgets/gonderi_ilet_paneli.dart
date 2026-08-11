// Gönderiyi takip edilenlere DM ile iletme paneli.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/sosyal_servis.dart';
import 'package:vibe_life/vibe_snackbar.dart';
import 'package:vibe_life/widgets/vibe_avatar.dart';

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
        postId: postId,
        postMetin: postMetin,
        postKullaniciAdi: postKullaniciAdi,
      );
    },
  );
}

// Gönderi iletme alt sayfa içeriği
class _GonderiIletPaneli extends StatefulWidget {
  final String postId;
  final String postMetin;
  final String postKullaniciAdi;

  const _GonderiIletPaneli({
    required this.postId,
    required this.postMetin,
    required this.postKullaniciAdi,
  });

  @override
  State<_GonderiIletPaneli> createState() => _GonderiIletPaneliState();
}

class _GonderiIletPaneliState extends State<_GonderiIletPaneli> {
  late Future<List<Map<String, dynamic>>> _profillerFuture;
  String _islemdeUid = "";

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    _profillerFuture = SosyalServis.takipEdilenProfilleriGetir(uid);
  }

  // Seçilen kullanıcıya gönderiyi iletir
  Future<void> _ilet(String hedefUid) async {
    if (_islemdeUid.isNotEmpty) return;
    setState(() => _islemdeUid = hedefUid);
    try {
      await SosyalServis.gonderiIlet(
        postId: widget.postId,
        hedefUid: hedefUid,
        postMetin: widget.postMetin,
        postKullaniciAdi: widget.postKullaniciAdi,
      );
      if (!mounted) return;
      Navigator.pop(context);
      vibeSnackbarGoster(context, "Gönderi iletildi.", tip: VibeMesajTipi.basari);
    } catch (e) {
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: "Gönderi iletilemedi.",
        ),
      );
    } finally {
      if (mounted) setState(() => _islemdeUid = "");
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    );
                  }

                  final profiller = snapshot.data ?? [];
                  if (profiller.isEmpty) {
                    return Center(
                      child: Text(
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
                      final yukleniyor = _islemdeUid == uid;

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: vibe.cardBorder),
                        ),
                        tileColor: vibe.cardColor,
                        leading: vibeAvatar(
                          radius: 20,
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
                        trailing: yukleniyor
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : Icon(Icons.send, color: vibe.mutedText),
                        onTap: yukleniyor ? null : () => _ilet(uid),
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
