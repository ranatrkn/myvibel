// Tek gönderi detay ekranı (feed alıntıları, DM iletileri vb.).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/alinti_gonderi.dart';
import 'package:myvibel/sosyal/sosyal_core.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/widgets/post_card.dart';
import 'package:myvibel/widgets/vibe_yukleniyor.dart';
import 'package:myvibel/widgets/vibe_gradient_scaffold.dart';

class GonderiDetaySayfasi extends StatelessWidget {
  const GonderiDetaySayfasi({
    super.key,
    required this.postId,
    required this.currentUserId,
    this.onKendiProfilineGit,
    this.onAlintiYap,
  });

  final String postId;
  final String currentUserId;
  final VoidCallback? onKendiProfilineGit;
  final ValueChanged<AlintiGonderiBaglam>? onAlintiYap;

  int _intDeger(dynamic value, int varsayilan) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return varsayilan;
  }

  @override
  Widget build(BuildContext context) {
    return VibeGradientScaffold(
      appBar: VibeGradientScaffold.seffafBaslik('Gönderi'),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: SosyalCore.gonderiRef(postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: VibeYukleniyor());
          }

          final doc = snapshot.data;
          final post = doc?.data();
          if (post == null || doc?.exists != true) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bu gönderi silinmiş veya artık görüntülenemiyor.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            children: [
              PostCard(
                key: ValueKey(postId),
                postId: postId,
                postOwnerId: (post['userId'] ?? '').toString(),
                kullaniciAdi:
                    (post['kullaniciAdi'] ?? 'Vibe Kullanıcısı').toString(),
                metin: (post['metin'] ?? '').toString(),
                mentionUidleri: SosyalServis.bahsetmeUidHaritasiParse(
                  post['mentionUidleri'],
                ),
                photoUrl: (post['photoUrl'] ?? '').toString(),
                avatarKey: (post['avatarKey'] ?? '').toString(),
                baslangicBegeniSayisi: _intDeger(post['begeniSayisi'], 0),
                baslangicYorumSayisi: _intDeger(post['yorumSayisi'], 0),
                userId: currentUserId,
                createdAt: post['createdAt'],
                ownerHesapGizli: post['ownerHesapGizli'] == true,
                alintiSnapshot: AlintiGonderiSnapshot.haritadan(
                  post['alintiSnapshot'],
                  postId: post['alintiPostId']?.toString(),
                ),
                onKendiProfilineGit: onKendiProfilineGit,
                onAlintiYap: onAlintiYap,
              ),
            ],
          );
        },
      ),
    );
  }
}
