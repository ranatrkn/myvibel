// Alıntılanan gönderi önizleme kartı.
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/alinti_gonderi.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/sosyal/sosyal_core.dart';
import 'package:myvibel/utils/tarih_saat.dart';
import 'package:myvibel/widgets/hashtag_metin.dart';
import 'package:myvibel/widgets/vibe_avatar.dart';

class AlintiGonderiOnizleme extends StatelessWidget {
  const AlintiGonderiOnizleme({
    super.key,
    required this.snapshot,
    this.currentUserId,
    this.onKendiProfilineGit,
    this.onAlintiYap,
    this.engellenenKullanicilar,
    this.beniEngelleyenler,
    this.compact = false,
    this.detayaGit = true,
    this.icAlintiGoster = false,
  });

  final AlintiGonderiSnapshot snapshot;
  final String? currentUserId;
  final VoidCallback? onKendiProfilineGit;
  final ValueChanged<AlintiGonderiBaglam>? onAlintiYap;
  final Set<String>? engellenenKullanicilar;
  final Set<String>? beniEngelleyenler;
  final bool compact;
  final bool detayaGit;
  /// Detay ekranında bir alt alıntıyı göster; feed/kartta false (yalnızca doğrudan alıntı).
  final bool icAlintiGoster;

  bool _senkronEngelliMi() {
    final uid = snapshot.userId;
    if (uid.isEmpty) return false;
    if (engellenenKullanicilar?.contains(uid) == true) return true;
    if (beniEngelleyenler?.contains(uid) == true) return true;
    return false;
  }

  Widget _uyariKutusu(BuildContext context, String mesaj) {
    final vibe = context.vibe;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        border: Border.all(color: vibe.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        mesaj,
        style: TextStyle(color: vibe.mutedText, fontSize: 13),
      ),
    );
  }

  Widget _engelliKutusu(BuildContext context) {
    return _uyariKutusu(context, 'Gönderi görüntülenemiyor.');
  }

  void _gonderiDetayinaGit(BuildContext context) {
    if (!detayaGit || !snapshot.mevcut || snapshot.postId.isEmpty) return;
    gonderiDetayiniAc(
      context,
      postId: snapshot.postId,
      currentUserId: currentUserId ?? '',
    );
  }

  void _profileGit(BuildContext context) {
    if (!snapshot.mevcut || snapshot.userId.isEmpty) return;
    profiliAc(context, snapshot.userId);
  }

  @override
  Widget build(BuildContext context) {
    if (!snapshot.mevcut) {
      return _uyariKutusu(
        context,
        'Alıntılanan gönderi artık mevcut değil.',
      );
    }

    if (_senkronEngelliMi()) {
      return _engelliKutusu(context);
    }

    final benimUid = currentUserId;
    final alintiSahibi = snapshot.userId;
    final engelListesiVerildi =
        engellenenKullanicilar != null || beniEngelleyenler != null;

    if (!engelListesiVerildi &&
        benimUid != null &&
        benimUid.isNotEmpty &&
        alintiSahibi.isNotEmpty) {
      return FutureBuilder<bool>(
        future: SosyalCore.engellendiMi(
          kaynakUid: benimUid,
          hedefUid: alintiSahibi,
        ),
        builder: (context, engelSnap) {
          if (engelSnap.connectionState == ConnectionState.waiting &&
              !engelSnap.hasData) {
            return _normalIcerik(context);
          }
          if (engelSnap.data == true) {
            return _engelliKutusu(context);
          }
          return _normalIcerik(context);
        },
      );
    }

    return _normalIcerik(context);
  }

  Widget _normalIcerik(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _gonderiDetayinaGit(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 10 : 12),
          decoration: BoxDecoration(
            border: Border.all(color: vibe.cardBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _profileGit(context),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    vibeAvatar(
                      radius: compact ? 14 : 16,
                      userId: snapshot.userId,
                      photoUrl: snapshot.photoUrl,
                      avatarKey: snapshot.avatarKey,
                      fallbackText: snapshot.kullaniciAdi,
                      emojiSize: compact ? 14 : 16,
                      fallbackIconSize: compact ? 16 : 18,
                      fallbackForegroundColor: theme.colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snapshot.kullaniciAdi,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: compact ? 13 : 14,
                            ),
                          ),
                          if (snapshot.createdAt != null)
                            Text(
                              tarihSaatYaz(snapshot.createdAt),
                              style: TextStyle(
                                color: vibe.faintText,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (snapshot.metin.isNotEmpty) ...[
                const SizedBox(height: 8),
                HashtagMetin(
                  metin: snapshot.metin,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.9),
                    fontSize: compact ? 13 : 14,
                    height: 1.35,
                  ),
                ),
              ],
              if (icAlintiGoster && snapshot.icAlinti != null) ...[
                const SizedBox(height: 8),
                AlintiGonderiOnizleme(
                  snapshot: snapshot.icAlinti!,
                  currentUserId: currentUserId,
                  onKendiProfilineGit: onKendiProfilineGit,
                  onAlintiYap: onAlintiYap,
                  engellenenKullanicilar: engellenenKullanicilar,
                  beniEngelleyenler: beniEngelleyenler,
                  compact: true,
                  detayaGit: detayaGit,
                  icAlintiGoster: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
