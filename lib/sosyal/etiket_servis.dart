// Hashtag, bahsetme ve etiket arama işlemleri
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vibe_life/sosyal/bildirim_servis.dart';
import 'package:vibe_life/sosyal/sosyal_core.dart';

// Etiket normalizasyonu ve arama servisi
class EtiketServis {
  // Etiket metnini standart forma getirir
  static String etiketNormalize(String ham) {
    var tag = ham.trim();
    if (tag.startsWith('#')) {
      tag = tag.substring(1); // Baştaki # işaretini kaldır
    }
    tag = tag.split(RegExp(r'\s+')).first; // İlk kelimeyi al
    return tag
        .toLowerCase()
        .replaceAll("ı", "i")
        .replaceAll("İ", "i")
        .replaceAll("ş", "s")
        .replaceAll("ğ", "g")
        .replaceAll("ç", "c")
        .replaceAll("ö", "o")
        .replaceAll("ü", "u"); // Türkçe karakterleri normalize et
  }

  // Arama metninden hashtag etiketi çıkarır
  static String? aramaMetnindenEtiket(String arama) {
    final trimmed = arama.trim();
    if (trimmed.isEmpty) return null;

    final hashMatch = RegExp(
            r'#([a-zA-Z0-9_\.\u00C0-\u024F\u0130\u0131\u015f\u011f\u00fc\u00f6\u00e7]+)')
        .firstMatch(trimmed);
    if (hashMatch != null) {
      final tag = etiketNormalize(hashMatch.group(1)!);
      return tag.isEmpty ? null : tag;
    }

    if (trimmed.startsWith('#')) {
      final tag = etiketNormalize(trimmed);
      return tag.isEmpty ? null : tag;
    }

    return null;
  }

  // Gönderi belirtilen etiketi içeriyor mu
  static bool _gonderiEtiketIcermiyor(
    Map<String, dynamic> data,
    String tag, {
    bool metinFallback = false,
  }) {
    if (data["raporNedeniyleGizli"] == true) return false; // Gizli gönderi

    final tags = data["tags"];
    if (tags is List) {
      for (final raw in tags) {
        if (etiketNormalize(raw.toString()) == tag) return true;
      }
    }

    if (!metinFallback) return false;

    // tags yoksa metinden etiket ara
    final metin = (data["metin"] ?? "").toString().toLowerCase();
    final regex = RegExp(
      r'#([a-zA-Z0-9_\.\u00C0-\u024F\u0130\u0131\u015f\u011f\u00fc\u00f6\u00e7]+)',
    );
    for (final match in regex.allMatches(metin)) {
      final ad = match.group(1);
      if (ad != null && etiketNormalize(ad) == tag) return true;
    }
    return false;
  }

  // Etiket aramasında gönderi görünür mü
  static bool gonderiEtiketAramasindaGorulebilir({
    required Map<String, dynamic> post,
    required String izleyiciUid,
    required Set<String> takipEdilenIdler,
    required Set<String> engelIdleri,
  }) {
    if (post["raporNedeniyleGizli"] == true) return false;

    final ownerId = post["userId"]?.toString() ?? "";
    if (ownerId.isEmpty) return false;
    if (ownerId == izleyiciUid) return true; // Kendi gönderisi
    if (engelIdleri.contains(ownerId)) return false; // Engel var

    if (post["ownerHesapGizli"] == true &&
        !takipEdilenIdler.contains(ownerId)) {
      return false; // Gizli hesap ve takip yok
    }

    return true;
  }

  // Id listesini whereIn limitine göre böler
  static List<List<String>> _idParcalari(Iterable<String> ids) {
    final temiz = ids.where((id) => id.trim().isNotEmpty).toSet().toList()
      ..sort();
    final parcalar = <List<String>>[];
    for (var i = 0; i < temiz.length; i += SosyalCore.whereInLimit) {
      final end = i + SosyalCore.whereInLimit;
      parcalar.add(temiz.sublist(i, end > temiz.length ? temiz.length : end));
    }
    return parcalar;
  }

  // İzleyicinin görebileceği owner id'leri
  static Set<String> _izinliOwnerIdleri({
    required String izleyiciUid,
    required Set<String> takipEdilenIdler,
    required Set<String> engelIdleri,
  }) {
    return {
      izleyiciUid,
      ...takipEdilenIdler,
    }..removeWhere((id) => id.isEmpty || engelIdleri.contains(id));
  }

  // Belgeleri benzersiz şekilde hedefe ekler
  static void _benzersizEkle(
    Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> hedef,
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    bool Function(QueryDocumentSnapshot<Map<String, dynamic>>) filtre,
  ) {
    for (final doc in docs) {
      if (filtre(doc)) {
        hedef[doc.id] = doc; // Aynı id tekrar yazılmaz
      }
    }
  }

  // createdAt alanını milisaniyeye çevirir
  static int _createdAtMs(Map<String, dynamic> data) {
    final createdAt = data["createdAt"];
    if (createdAt is Timestamp) {
      return createdAt.millisecondsSinceEpoch;
    }
    return 0;
  }

  // Hashtag ile eşleşen gönderileri getirir
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      hashtagGonderileriniGetir(
    String hamEtiket, {
    required String izleyiciUid,
    required Set<String> takipEdilenIdler,
    required Set<String> engelIdleri,
    int limit = 30,
  }) async {
    final tag = etiketNormalize(hamEtiket);
    if (tag.isEmpty) return [];
    final hedefBelgeSayisi = (limit * 2).clamp(20, 120).toInt();
    final fallbackLimit = (limit * 4).clamp(60, 160).toInt();

    bool gorulebilir(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final data = doc.data();
      return _gonderiEtiketIcermiyor(data, tag) &&
          gonderiEtiketAramasindaGorulebilir(
            post: data,
            izleyiciUid: izleyiciUid,
            takipEdilenIdler: takipEdilenIdler,
            engelIdleri: engelIdleri,
          );
    }

    bool gorulebilirMetinFallback(
        QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final data = doc.data();
      return _gonderiEtiketIcermiyor(
            data,
            tag,
            metinFallback: true,
          ) &&
          gonderiEtiketAramasindaGorulebilir(
            post: data,
            izleyiciUid: izleyiciUid,
            takipEdilenIdler: takipEdilenIdler,
            engelIdleri: engelIdleri,
          );
    }

    final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    try {
      // Önce tags dizisinden doğrudan sorgula
      final snap = await SosyalCore.db
          .collection("posts")
          .where("tags", arrayContains: tag)
          .where("ownerHesapGizli", isEqualTo: false)
          .where("raporNedeniyleGizli", isEqualTo: false)
          .limit(limit * 2)
          .get();
      _benzersizEkle(docsById, snap.docs, gorulebilir);
    } catch (e) {
      debugPrint("hashtagGonderileriniGetir tags query failed: $e");
    }

    final izinliOwnerIdleri = _izinliOwnerIdleri(
      izleyiciUid: izleyiciUid,
      takipEdilenIdler: takipEdilenIdler,
      engelIdleri: engelIdleri,
    );
    for (final parca in _idParcalari(izinliOwnerIdleri)) {
      if (docsById.length >= hedefBelgeSayisi) break;
      try {
        // Gizli hesap gönderilerini owner ile sorgula
        final snap = await SosyalCore.db
            .collection("posts")
            .where("tags", arrayContains: tag)
            .where("userId", whereIn: parca)
            .where("raporNedeniyleGizli", isEqualTo: false)
            .limit(limit * 2)
            .get();
        _benzersizEkle(docsById, snap.docs, gorulebilir);
      } catch (e) {
        debugPrint("hashtagGonderileriniGetir allowed owners query failed: $e");
      }
    }

    if (docsById.isEmpty) {
      try {
        // tags sorgusu boşsa metin fallback dene
        final snap = await SosyalCore.db
            .collection("posts")
            .where("ownerHesapGizli", isEqualTo: false)
            .where("raporNedeniyleGizli", isEqualTo: false)
            .orderBy("createdAt", descending: true)
            .limit(fallbackLimit)
            .get();
        _benzersizEkle(docsById, snap.docs, gorulebilirMetinFallback);
      } catch (e) {
        debugPrint("hashtagGonderileriniGetir fallback failed: $e");
      }

      for (final parca in _idParcalari(izinliOwnerIdleri)) {
        if (docsById.length >= hedefBelgeSayisi) break;
        try {
          final snap = await SosyalCore.db
              .collection("posts")
              .where("userId", whereIn: parca)
              .where("raporNedeniyleGizli", isEqualTo: false)
              .orderBy("createdAt", descending: true)
              .limit(fallbackLimit)
              .get();
          _benzersizEkle(docsById, snap.docs, gorulebilirMetinFallback);
        } catch (e) {
          debugPrint("hashtagGonderileriniGetir allowed fallback failed: $e");
        }
      }
    }

    var docs = docsById.values.toList();
    docs.sort(
      (a, b) => _createdAtMs(b.data()).compareTo(_createdAtMs(a.data())),
    ); // En yeni önce

    if (docs.length > limit) {
      docs = docs.sublist(0, limit);
    }
    return docs;
  }

  // İzleyicinin görebileceği bilinen etiketleri toplar
  static Future<Set<String>> bilinenEtiketleriGetir({
    required String izleyiciUid,
    required Set<String> takipEdilenIdler,
    required Set<String> engelIdleri,
    int postLimit = 120,
  }) async {
    final etiketler = <String>{};
    final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    try {
      final snap = await SosyalCore.db
          .collection("posts")
          .where("ownerHesapGizli", isEqualTo: false)
          .where("raporNedeniyleGizli", isEqualTo: false)
          .orderBy("createdAt", descending: true)
          .limit(postLimit)
          .get();
      _benzersizEkle(docsById, snap.docs, (_) => true);
    } catch (e) {
      debugPrint("bilinenEtiketleriGetir public query failed: $e");
    }

    final izinliOwnerIdleri = _izinliOwnerIdleri(
      izleyiciUid: izleyiciUid,
      takipEdilenIdler: takipEdilenIdler,
      engelIdleri: engelIdleri,
    );
    for (final parca in _idParcalari(izinliOwnerIdleri)) {
      try {
        final snap = await SosyalCore.db
            .collection("posts")
            .where("userId", whereIn: parca)
            .where("raporNedeniyleGizli", isEqualTo: false)
            .orderBy("createdAt", descending: true)
            .limit(postLimit)
            .get();
        _benzersizEkle(docsById, snap.docs, (_) => true);
      } catch (e) {
        debugPrint("bilinenEtiketleriGetir allowed query failed: $e");
      }
    }

    for (final doc in docsById.values) {
      final data = doc.data();
      if (!gonderiEtiketAramasindaGorulebilir(
        post: data,
        izleyiciUid: izleyiciUid,
        takipEdilenIdler: takipEdilenIdler,
        engelIdleri: engelIdleri,
      )) {
        continue;
      }

      final tags = data["tags"];
      if (tags is List) {
        for (final raw in tags) {
          final tag = etiketNormalize(raw.toString());
          if (tag.isNotEmpty) etiketler.add(tag);
        }
      }

      final metin = (data["metin"] ?? "").toString();
      for (final tag in etiketleriAyikla(metin)) {
        etiketler.add(tag); // Metinden de etiket topla
      }
    }

    return etiketler;
  }

  // Sorguya göre etiket önerileri döndürür
  static List<String> etiketOnerileri(
    Set<String> bilinenEtiketler,
    String sorgu, {
    int limit = 8,
  }) {
    final prefix = etiketNormalize(
      aramaMetnindenEtiket(sorgu) ?? sorgu,
    );
    if (prefix.isEmpty) return [];

    final sonuc = bilinenEtiketler
        .where((tag) => tag.startsWith(prefix))
        .toSet();
    if (_gecerliEtiketAdi(prefix)) {
      sonuc.add(prefix);
    }

    final liste = sonuc.toList()..sort();
    if (liste.contains(prefix)) {
      liste.remove(prefix);
      liste.insert(0, prefix);
    }
    return liste.take(limit).toList();
  }

  static bool _gecerliEtiketAdi(String tag) {
    return tag.length >= 3 && RegExp(r'^[a-z0-9_\.]+$').hasMatch(tag);
  }

  // Firestore'dan etiket araması (tam eşleşme + önbellek)
  static Future<List<String>> etiketleriAra({
    required String sorgu,
    required String izleyiciUid,
    required Set<String> takipEdilenIdler,
    required Set<String> engelIdleri,
    required Set<String> bilinenEtiketler,
    int limit = 8,
  }) async {
    final prefix = etiketNormalize(
      aramaMetnindenEtiket(sorgu) ?? sorgu,
    );
    if (prefix.isEmpty) return [];

    final sonuc = etiketOnerileri(bilinenEtiketler, sorgu, limit: limit).toSet();

    if (!_gecerliEtiketAdi(prefix)) {
      return sonuc.take(limit).toList();
    }

    try {
      final snap = await SosyalCore.db
          .collection("posts")
          .where("tags", arrayContains: prefix)
          .where("raporNedeniyleGizli", isEqualTo: false)
          .limit(25)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        if (!gonderiEtiketAramasindaGorulebilir(
          post: data,
          izleyiciUid: izleyiciUid,
          takipEdilenIdler: takipEdilenIdler,
          engelIdleri: engelIdleri,
        )) {
          continue;
        }

        sonuc.add(prefix);
        final tags = data["tags"];
        if (tags is List) {
          for (final raw in tags) {
            final tag = etiketNormalize(raw.toString());
            if (tag.startsWith(prefix)) {
              sonuc.add(tag);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("etiketleriAra query failed: $e");
    }

    final liste = sonuc.toList()..sort();
    if (liste.contains(prefix)) {
      liste.remove(prefix);
      liste.insert(0, prefix);
    }
    return liste.take(limit).toList();
  }

  // Metinden hashtag etiketlerini ayıklar
  static List<String> etiketleriAyikla(String metin) {
    final regex = RegExp(
        r'#([a-zA-Z0-9_\.\u00C0-\u024F\u0130\u0131\u015f\u011f\u00fc\u00f6\u00e7]+)');
    final etiketler = <String>{};
    for (final match in regex.allMatches(metin)) {
      final tag = match.group(1);
      if (tag == null || tag.isEmpty) continue;
      etiketler.add(etiketNormalize(tag));
      if (etiketler.length >= 10) break; // En fazla 10 etiket
    }
    return etiketler.toList();
  }

  static final RegExp _bahsetmeRegex = RegExp(r'@([a-zA-Z0-9_\.]{3,30})'); // @bahsetme deseni

  // Metinden @ bahsetmelerini ayıklar
  static List<String> bahsetmeleriAyikla(String metin) {
    final bahsetmeler = <String>{};
    for (final match in _bahsetmeRegex.allMatches(metin)) {
      final ham = match.group(1);
      if (ham == null || ham.isEmpty) continue;
      final norm = etiketNormalize(ham);
      if (norm.length < 3 || norm.length > 30) continue;
      bahsetmeler.add(norm);
      if (bahsetmeler.length >= 10) break;
    }
    return bahsetmeler.toList();
  }

  // Bahsetme uid haritasını parse eder
  static Map<String, String> bahsetmeUidHaritasiParse(dynamic raw) {
    if (raw is! Map) return {};
    final map = <String, String>{};
    raw.forEach((key, value) {
      final k = key.toString();
      final v = value?.toString() ?? "";
      if (k.isNotEmpty && v.isNotEmpty) {
        map[k] = v;
      }
    });
    return map;
  }

  // Kullanıcı adından uid bulur
  static Future<String?> kullaniciUidGetir(String kullaniciAdiKucuk) async {
    final norm = etiketNormalize(kullaniciAdiKucuk);
    if (norm.isEmpty) return null;
    final doc = await SosyalCore.db.collection("usernames").doc(norm).get();
    if (!doc.exists) return null;
    return doc.data()?["uid"]?.toString();
  }

  // Metindeki bahsetmelerin uid'lerini çözer
  static Future<Map<String, String>> bahsetmeUidleriniCoz(String metin) async {
    final bahsetmeler = bahsetmeleriAyikla(metin);
    if (bahsetmeler.isEmpty) return {};

    final map = <String, String>{};
    for (final ad in bahsetmeler) {
      final uid = await kullaniciUidGetir(ad);
      if (uid != null) {
        map[ad] = uid;
      }
    }
    return map;
  }

  // Kullanıcı adı önerileri getirir
  static Future<List<Map<String, dynamic>>> kullaniciOnerileri(
    String hamPrefix, {
    String? haricUid,
    int limit = 8,
  }) async {
    final prefix = etiketNormalize(hamPrefix);
    if (prefix.isEmpty) return [];

    final snap = await SosyalCore.db
        .collection("usernames")
        .orderBy(FieldPath.documentId)
        .startAt([prefix])
        .endAt(["$prefix\uf8ff"])
        .limit(limit + 5)
        .get();

    final liste = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final uid = doc.data()["uid"]?.toString() ?? "";
      if (uid.isEmpty || uid == haricUid) continue;

      final userSnap = await SosyalCore.db.collection("users").doc(uid).get();
      if (!userSnap.exists) continue;
      final data = userSnap.data() ?? {};
      liste.add({
        "uid": uid,
        "adSoyad": data["adSoyad"] ?? "Vibe Kullanıcısı",
        "kullaniciAdi": data["kullaniciAdi"] ?? doc.id,
        "photoUrl": data["photoUrl"] ?? "",
        "avatarKey": data["avatarKey"] ?? "",
      });
      if (liste.length >= limit) break;
    }
    return liste;
  }

  // Bahsedilen kullanıcılara bildirim gönderir
  static Future<void> bahsetmeBildirimleriGonder({
    required String gonderenUid,
    required Map<String, String> mentionUidleri,
    required String kaynak,
    String? postId,
    String? chatId,
  }) async {
    String metin;
    switch (kaynak) {
      case "post":
        metin = "bir gönderide senden bahsetti";
        break;
      case "comment":
        metin = "bir yorumda senden bahsetti";
        break;
      case "message":
        metin = "bir mesajda senden bahsetti";
        break;
      default:
        metin = "senden bahsetti";
    }

    for (final entry in mentionUidleri.entries) {
      if (entry.value == gonderenUid) continue; // Kendini atla
      await BildirimServis.bildirimEkle(
        hedefUid: entry.value,
        tip: "mention",
        gonderenUid: gonderenUid,
        postId: postId,
        chatId: chatId,
        metin: metin,
      );
    }
  }
}
