// Alıntı gönderi (quote post) modeli ve yardımcılar.
class AlintiGonderiSnapshot {
  const AlintiGonderiSnapshot({
    required this.postId,
    required this.userId,
    required this.kullaniciAdi,
    required this.metin,
    required this.photoUrl,
    required this.avatarKey,
    this.createdAt,
    this.mevcut = true,
    this.icAlinti,
  });

  final String postId;
  final String userId;
  final String kullaniciAdi;
  final String metin;
  final String photoUrl;
  final String avatarKey;
  final dynamic createdAt;
  final bool mevcut;
  /// Alıntı gönderisinin içindeki önceki alıntı (iç içe alıntı zinciri).
  final AlintiGonderiSnapshot? icAlinti;

  factory AlintiGonderiSnapshot.kayip(String postId) {
    return AlintiGonderiSnapshot(
      postId: postId,
      userId: '',
      kullaniciAdi: '',
      metin: '',
      photoUrl: '',
      avatarKey: '',
      mevcut: false,
    );
  }

  factory AlintiGonderiSnapshot.gonderiden(
    String postId,
    Map<String, dynamic> post,
  ) {
    final icHam = post['alintiSnapshot'];
    final icId = post['alintiPostId']?.toString();
    return AlintiGonderiSnapshot(
      postId: postId,
      userId: (post['userId'] ?? '').toString(),
      kullaniciAdi: (post['kullaniciAdi'] ?? 'Vibe Kullanıcısı').toString(),
      metin: (post['metin'] ?? '').toString(),
      photoUrl: (post['photoUrl'] ?? '').toString(),
      avatarKey: (post['avatarKey'] ?? '').toString(),
      createdAt: post['createdAt'],
      mevcut: true,
      icAlinti: icHam != null
          ? AlintiGonderiSnapshot.haritadan(icHam, postId: icId)
          : null,
    );
  }

  static AlintiGonderiSnapshot? haritadan(
    dynamic raw, {
    String? postId,
  }) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final id = (map['postId'] ?? postId ?? '').toString();
    if (id.isEmpty) return null;
    if (map['mevcut'] == false) {
      return AlintiGonderiSnapshot.kayip(id);
    }
    final icHam = map['icAlinti'];
    return AlintiGonderiSnapshot(
      postId: id,
      userId: (map['userId'] ?? '').toString(),
      kullaniciAdi: (map['kullaniciAdi'] ?? 'Vibe Kullanıcısı').toString(),
      metin: (map['metin'] ?? '').toString(),
      photoUrl: (map['photoUrl'] ?? '').toString(),
      avatarKey: (map['avatarKey'] ?? '').toString(),
      createdAt: map['createdAt'],
      mevcut: map['mevcut'] != false,
      icAlinti: icHam != null
          ? AlintiGonderiSnapshot.haritadan(icHam)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'kullaniciAdi': kullaniciAdi,
      'metin': metin,
      'photoUrl': photoUrl,
      'avatarKey': avatarKey,
      if (createdAt != null) 'createdAt': createdAt,
      'mevcut': mevcut,
      if (icAlinti != null) 'icAlinti': icAlinti!.toMap(),
    };
  }
}

class AlintiGonderiBaglam {
  const AlintiGonderiBaglam({
    required this.postId,
    required this.snapshot,
  });

  final String postId;
  final AlintiGonderiSnapshot snapshot;
}
