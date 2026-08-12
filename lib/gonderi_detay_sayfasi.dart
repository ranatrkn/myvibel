// Tek gönderi detay ekranı (feed alıntıları, DM iletileri vb.).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vibe_life/alinti_gonderi.dart';
import 'package:vibe_life/sosyal_servis.dart';
import 'package:vibe_life/widgets/post_card.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Gönderi')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snapshot.data;
          final post = doc?.data();
          if (post == null || doc?.exists != true) {
            return const Center(child: Text('Gönderi bulunamadı.'));
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
