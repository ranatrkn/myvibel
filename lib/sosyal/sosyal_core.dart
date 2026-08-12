// Sosyal modül ortak yardımcıları, limitler ve Firestore işlemleri
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibe_life/sosyal/bildirim_servis.dart';

// Ortak yardımcı metotlar ve sabitler
class SosyalCore {
  static final db = FirebaseFirestore.instance; // Firestore veritabanı örneği
  static const int postRaporEsigi = 5; // Gönderi gizleme şikayet eşiği
  static const int yorumRaporEsigi = 4; // Yorum gizleme şikayet eşiği
  static const int yorumMinAralikMs = 4000; // Yorumlar arası min süre
  static const int begeniMinAralikMs = 1200; // Beğeniler arası min süre
  static const int gonderiMinAralikMs = 6000; // Gönderiler arası min süre
  /// Firestore doküman sınırına uygun pratik üst limit (UI'da sınırsız hissi).
  static const int gonderiMetinMaxKarakter = 10000;
  static const int whereInLimit = 10; // Firestore whereIn parça boyutu
  static final Map<String, int> _sonAksiyonMs = {}; // Bellekte son aksiyon zamanı
  static SharedPreferences? _rateLimitPrefs; // Kalıcı hız limiti tercihleri

  // SharedPreferences örneğini yükler
  static Future<void> rateLimitPrefsYukle() async {
    _rateLimitPrefs ??= await SharedPreferences.getInstance();
  }

  // Aksiyon hız limitini kontrol eder
  static Future<void> aksiyonHizLimitiKontrol({
    required String uid,
    required String aksiyon,
    required int minAralikMs,
    required String mesaj,
  }) async {
    await rateLimitPrefsYukle();
    final key = '$uid:$aksiyon'; // Kullanıcı ve aksiyon anahtarı
    final prefsKey = 'rate_limit:$key';
    final simdi = DateTime.now().millisecondsSinceEpoch;
    final bellekten = _sonAksiyonMs[key] ?? 0;
    final kayitli = _rateLimitPrefs!.getInt(prefsKey) ?? 0;
    final son = bellekten > kayitli ? bellekten : kayitli; // En güncel zamanı al
    if (son > 0 && simdi - son < minAralikMs) {
      throw mesaj; // Çok hızlıysa hata fırlat
    }
  }

  // Son aksiyon zamanını kaydeder
  static Future<void> aksiyonHizLimitiKaydet({
    required String uid,
    required String aksiyon,
  }) async {
    await rateLimitPrefsYukle();
    final key = '$uid:$aksiyon';
    final prefsKey = 'rate_limit:$key';
    final simdi = DateTime.now().millisecondsSinceEpoch;
    _sonAksiyonMs[key] = simdi; // Belleğe yaz
    await _rateLimitPrefs!.setInt(prefsKey, simdi); // Kalıcı depoya yaz
  }

  // Gönderi paylaşım hız limitini kontrol eder
  static Future<void> gonderiPaylasimHizLimitiKontrol(String uid) {
    return aksiyonHizLimitiKontrol(
      uid: uid,
      aksiyon: 'post',
      minAralikMs: gonderiMinAralikMs,
      mesaj: 'Cok hizli gonderi paylasiyorsun. Lutfen biraz bekle.',
    );
  }

  // Gönderi paylaşım zamanını kaydeder
  static Future<void> gonderiPaylasimHizLimitiKaydet(String uid) {
    return aksiyonHizLimitiKaydet(uid: uid, aksiyon: 'post');
  }

  // İki kullanıcı arasında engel var mı
  static Future<bool> engellendiMi({
    required String kaynakUid,
    required String hedefUid,
  }) async {
    try {
      // Kaynak kullanıcının engellediklerini kontrol et
      final blocked = await db
          .collection("users")
          .doc(kaynakUid)
          .collection("blocked")
          .doc(hedefUid)
          .get();
      if (blocked.exists) return true;

      // Kaynak kullanıcıyı engelleyenleri kontrol et
      final blockedBy = await db
          .collection("users")
          .doc(kaynakUid)
          .collection("blockedBy")
          .doc(hedefUid)
          .get();
      return blockedBy.exists;
    } on FirebaseException catch (e) {
      // Okuma engellenirse etkileşimi güvenli tarafta kapat.
      debugPrint("engellendiMi read denied ($kaynakUid -> $hedefUid): ${e.code}");
      return true;
    }
  }

  // Takip etkileşimi engelli mi kontrol eder
  static Future<bool> takipEtkilesimEngelliMi({
    required String takipEdenUid,
    required String hedefUid,
  }) async {
    final current = FirebaseAuth.instance.currentUser?.uid;
    if (current == null) return true; // Oturum yoksa engelli say

    if (current == takipEdenUid) {
      return engellendiMi(kaynakUid: takipEdenUid, hedefUid: hedefUid);
    }
    if (current == hedefUid) {
      return engellendiMi(kaynakUid: hedefUid, hedefUid: takipEdenUid);
    }

    // Üçüncü kişi görünümünde her iki tarafı kontrol et
    final engelA = await engellendiMi(
      kaynakUid: current,
      hedefUid: takipEdenUid,
    );
    if (engelA) return true;
    return engellendiMi(kaynakUid: current, hedefUid: hedefUid);
  }

  // Kullanıcı doküman verisini getirir
  static Future<Map<String, dynamic>?> kullaniciVerisi(String uid) async {
    final doc = await db.collection("users").doc(uid).get();
    return doc.data();
  }

  // Kullanıcı özet bilgisini döndürür
  static Future<Map<String, dynamic>?> kullaniciOzetGetir(String uid) async {
    final data = await kullaniciVerisi(uid);
    if (data == null) return null;
    return {
      "adSoyad": data["adSoyad"] ?? "Vibe Kullanıcısı",
      "kullaniciAdi": data["kullaniciAdi"] ?? "kullanici",
      "photoUrl": data["photoUrl"] ?? "",
      "avatarKey": data["avatarKey"] ?? "",
    };
  }

  // Gönderi sahibi mevcut kullanıcı mı
  static bool kendiGonderisiMi({
    required String postOwnerId,
    required String currentUserId,
  }) {
    return postOwnerId.isNotEmpty && postOwnerId == currentUserId;
  }

  // Alt koleksiyondaki tüm belgeleri siler
  static Future<void> altKoleksiyonuSil(
    CollectionReference<Map<String, dynamic>> koleksiyon,
  ) async {
    final snap = await koleksiyon.limit(400).get();
    if (snap.docs.isEmpty) return;

    var batch = db.batch();
    var sayac = 0;

    for (final doc in snap.docs) {
      batch.delete(doc.reference);
      sayac++;
      if (sayac >= 400) {
        await batch.commit(); // Batch limitine ulaşınca commit
        batch = db.batch();
        sayac = 0;
      }
    }
    if (sayac > 0) await batch.commit();

    // Daha fazla belge varsa özyinelemeli devam et
    if (snap.docs.length >= 400) {
      await altKoleksiyonuSil(koleksiyon);
    }
  }

  // Belge silmeyi hata yutarak dener
  static Future<void> guvenliSil(
      DocumentReference<Map<String, dynamic>> ref) async {
    try {
      await ref.delete();
    } catch (e) {
      debugPrint("engelleKullanici cleanup failed (${ref.path}): $e");
    }
  }

  // Takip isteği bildirimlerini güvenle siler
  static Future<void> guvenliTakipIstegiBildirimleriniSil(
    String hedefUid,
    String istekciUid,
  ) async {
    try {
      await BildirimServis.takipIstegiBildirimleriniSil(hedefUid, istekciUid);
    } catch (e) {
      debugPrint(
        "takipIstegiBildirimleriniSil failed ($hedefUid/$istekciUid): $e",
      );
    }
  }
}
