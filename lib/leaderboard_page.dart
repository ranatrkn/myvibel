// Haftalık görev puanı liderlik tablosu.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/sosyal_servis.dart';
import 'package:vibe_life/user_profile_page.dart';
import 'package:vibe_life/widgets/vibe_avatar.dart';
import 'package:vibe_life/widgets/vibe_gradient_scaffold.dart';

// Liderlik sıralaması sayfası
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late Future<List<Map<String, dynamic>>> _tabloFuture; // Sıralama verisi

  @override
  void initState() {
    super.initState();
    _tabloFuture = SosyalServis.liderlikTablosuGetir();
  }

  int _intDeger(dynamic value, int varsayilan) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return varsayilan;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return VibeGradientScaffold(
      appBar: AppBar(
        title: const Text('Haftalık Görev Liderliği'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _tabloFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child:
                    CircularProgressIndicator(color: theme.colorScheme.primary),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    internetAwareErrorMessage(
                      error: snapshot.error ?? "Tablo yüklenemedi.",
                      fallback: "Tablo yüklenemedi.",
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: vibe.subtleText),
                  ),
                ),
              );
            }

            final liste = snapshot.data ?? [];
            if (liste.isEmpty) {
              return Center(
                child: Text(
                  "Henüz sıralama oluşmadı.",
                  style: TextStyle(color: vibe.mutedText),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: liste.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final k = liste[index];
                final uid = k["uid"] as String;
                final adSoyad = k["adSoyad"] as String;
                final kullaniciAdi = k["kullaniciAdi"] as String;
                final mascotSeviye = _intDeger(k["robotSeviye"], 1);
                final haftalikGorevPuani =
                    _intDeger(k["haftalikGorevPuani"], 0);
                final sira = index + 1;
                final benim = uid == myUid;

                return Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: benim
                        ? Border.all(
                            color: theme.colorScheme.primary, width: 1.5)
                        : Border.all(color: vibe.cardBorder),
                    color: vibe.cardColor,
                  ),
                  child: ListTile(
                    onTap: () {
                      if (uid.isEmpty) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfilePage(userId: uid),
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      backgroundColor: sira <= 3
                          ? theme.colorScheme.primary.withOpacity(0.2)
                          : vibe.inputFill,
                      child: Text(
                        "$sira",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        vibeAvatar(
                          radius: 16,
                          photoUrl: (k["photoUrl"] ?? "").toString(),
                          avatarKey: (k["avatarKey"] ?? "").toString(),
                          fallbackText: kullaniciAdi,
                          emojiSize: 14,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                adSoyad,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "@$kullaniciAdi",
                                style: TextStyle(
                                    color: vibe.mutedText, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$haftalikGorevPuani puan',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Seviye $mascotSeviye',
                          style: TextStyle(
                            color: vibe.mutedText,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
