// Özel mesajlaşma, sohbet yönetimi ve gönderi iletme
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:vibe_life/sosyal/bildirim_servis.dart';
import 'package:vibe_life/sosyal/etiket_servis.dart';
import 'package:vibe_life/sosyal/sosyal_core.dart';

// Sohbet ve mesaj işlemleri servisi
class MesajServis {
  // Sohbet kullanıcı için sessize alınmış mı
  static bool sohbetSessizMi({
    required String uid,
    required Map<String, dynamic> chat,
  }) {
    final raw = chat["mutedBy"];
    if (raw is Map && raw[uid] == true) return true;
    return false;
  }

  // Sohbet sessizlik ayarını günceller
  static Future<void> sohbetSessizliginiDegistir({
    required String chatId,
    required String uid,
    required bool sessiz,
  }) async {
    final chatRef = SosyalCore.db.collection("chats").doc(chatId);
    final chatSnap = await chatRef.get();
    final chatData = chatSnap.data() ?? <String, dynamic>{};
    final rawMuted = chatData["mutedBy"];
    final mutedMap = rawMuted is Map
        ? Map<String, dynamic>.from(rawMuted)
        : <String, dynamic>{};
    mutedMap[uid] = sessiz;

    await chatRef.set(
      {"mutedBy": mutedMap},
      SetOptions(merge: true),
    );
  }

  // Sohbeti kullanıcı için gizler
  static Future<void> sohbetiGizle({
    required String chatId,
    required String uid,
  }) async {
    final chatRef = SosyalCore.db.collection("chats").doc(chatId);
    final chatSnap = await chatRef.get();
    final chatData = chatSnap.data() ?? <String, dynamic>{};
    final rawHidden = chatData["hiddenBy"];
    final hiddenMap = rawHidden is Map
        ? Map<String, dynamic>.from(rawHidden)
        : <String, dynamic>{};
    hiddenMap[uid] = FieldValue.serverTimestamp(); // Gizleme zamanını kaydet

    await chatRef.set(
      {"hiddenBy": hiddenMap},
      SetOptions(merge: true),
    );
  }

  // Sohbet kullanıcı için gizli mi
  static bool sohbetGizliMi({
    required String uid,
    required Map<String, dynamic> chat,
    int? localHiddenAtMs,
  }) {
    final lastMessageAt = chat["lastMessageAt"];
    if (lastMessageAt is! Timestamp) {
      return localHiddenAtMs != null && localHiddenAtMs > 0; // Yerel gizleme kontrolü
    }

    final rawHidden = chat["hiddenBy"];
    if (rawHidden is Map) {
      final hiddenAt = rawHidden[uid];
      if (hiddenAt is Timestamp) {
        return lastMessageAt.millisecondsSinceEpoch <=
            hiddenAt.millisecondsSinceEpoch; // Gizlemeden sonra mesaj yok
      }
    }

    if (localHiddenAtMs != null && localHiddenAtMs > 0) {
      return lastMessageAt.millisecondsSinceEpoch <= localHiddenAtMs;
    }
    return false;
  }

  // Sohbette okunmamış mesaj var mı
  static bool sohbetOkunmamisMi({
    required String uid,
    required Map<String, dynamic> chat,
    int? localReadAtMs,
  }) {
    final lastSenderUid = (chat["lastSenderUid"] ?? "").toString();
    if (lastSenderUid.isEmpty || lastSenderUid == uid) return false; // Kendi mesajı

    final lastMessageAt = chat["lastMessageAt"];
    if (lastMessageAt is! Timestamp) return false;

    final rawSeen = chat["lastSeenBy"];
    if (rawSeen is Map) {
      final mySeen = rawSeen[uid];
      if (mySeen is Timestamp) {
        return lastMessageAt.millisecondsSinceEpoch >
            mySeen.millisecondsSinceEpoch; // Son mesaj görülmeden sonra
      }
    }

    if (localReadAtMs != null) {
      return lastMessageAt.millisecondsSinceEpoch > localReadAtMs;
    }
    return true; // Görülme kaydı yoksa okunmamış
  }

  // İki kullanıcı için benzersiz sohbet id
  static String sohbetIdUret(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort(); // Sıralı id birleşimi
    return "${ids[0]}_${ids[1]}";
  }

  // Mevcut sohbet id'sini getirir veya oluşturur
  static Future<String> sohbetIdGetirVeyaOlustur(String hedefUid) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw "Oturum bulunamadı.";
    if (current.uid == hedefUid) throw "Kendinle sohbet başlatamazsın.";
    if (await SosyalCore.engellendiMi(
        kaynakUid: current.uid, hedefUid: hedefUid)) {
      throw "Bu kullanıcı ile mesajlaşamazsın.";
    }

    final chatId = sohbetIdUret(current.uid, hedefUid);
    final chatRef = SosyalCore.db.collection("chats").doc(chatId);
    final participants = [current.uid, hedefUid]..sort();
    // Rules tarafında yeni doküman okuma iznine takılmamak için
    // transaction/get yerine doğrudan merge set kullanıyoruz.
    await chatRef.set(
      {
        // Sadece participants yazılır; mevcut sohbet açılırken
        // update kuralına takılmamak için diğer alanlar dokunulmaz.
        "participants": participants,
      },
      SetOptions(merge: true),
    );
    return chatId;
  }

  // Kullanıcının sohbet listesi akışı
  static Stream<QuerySnapshot<Map<String, dynamic>>> sohbetlerim(String uid) {
    return SosyalCore.db
        .collection("chats")
        .where("participants", arrayContains: uid)
        .snapshots();
  }

  // Belirli sohbetin mesajları akışı
  static Stream<QuerySnapshot<Map<String, dynamic>>> sohbetMesajlari(
      String chatId) {
    return SosyalCore.db
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .orderBy("createdAt", descending: false)
        .snapshots();
  }

  // Sohbete yeni mesaj gönderir
  static Future<void> mesajGonder({
    required String chatId,
    required String hedefUid,
    required String metin,
    String mesajTipi = "text",
    String postId = "",
  }) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw "Oturum bulunamadı.";
    final temizMetin = metin.trim();
    if (temizMetin.isEmpty && mesajTipi != "post_forward") return;
    if (await SosyalCore.engellendiMi(
        kaynakUid: current.uid, hedefUid: hedefUid)) {
      throw "Bu kullanıcı ile mesajlaşamazsın.";
    }

    final chatRef = SosyalCore.db.collection("chats").doc(chatId);
    final msgRef = chatRef.collection("messages").doc();
    final ozetMetin =
        mesajTipi == "post_forward" ? "Bir gönderi iletti" : temizMetin;
    final mentionUidleri = mesajTipi == "text"
        ? await EtiketServis.bahsetmeUidleriniCoz(temizMetin)
        : <String, String>{};

    await SosyalCore.db.runTransaction((tx) async {
      tx.set(msgRef, {
        "senderUid": current.uid,
        "receiverUid": hedefUid,
        "metin": temizMetin,
        "mesajTipi": mesajTipi,
        "postId": postId,
        "bahsetmeler":
            mesajTipi == "text" ? EtiketServis.bahsetmeleriAyikla(temizMetin) : <String>[],
        "mentionUidleri": mentionUidleri,
        "createdAt": FieldValue.serverTimestamp(),
      });
      tx.set(
        chatRef,
        {
          "updatedAt": FieldValue.serverTimestamp(),
          "lastMessage": ozetMetin,
          "lastMessageAt": FieldValue.serverTimestamp(),
          "lastSenderUid": current.uid,
        },
        SetOptions(merge: true),
      );
    });

    if (mentionUidleri.isNotEmpty) {
      await EtiketServis.bahsetmeBildirimleriGonder(
        gonderenUid: current.uid,
        mentionUidleri: mentionUidleri,
        kaynak: "message",
        chatId: chatId,
      );
    }

    try {
      final chatSnap = await chatRef.get();
      final chatData = chatSnap.data() ?? <String, dynamic>{};
      if (!sohbetSessizMi(uid: hedefUid, chat: chatData)) {
        await BildirimServis.bildirimEkle(
          hedefUid: hedefUid,
          tip: "message",
          gonderenUid: current.uid,
          chatId: chatId,
          metin: ozetMetin,
        );
      }
    } catch (e) {
      debugPrint("mesajGonder bildirimi failed: $e");
    }
  }

  // Gönderiyi sohbet üzerinden iletir
  static Future<void> gonderiIlet({
    required String postId,
    required String hedefUid,
    required String postMetin,
    required String postKullaniciAdi,
  }) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw "Oturum bulunamadı.";
    if (current.uid == hedefUid) {
      throw "Kendine gönderi iletemezsin.";
    }
    if (await SosyalCore.engellendiMi(
        kaynakUid: current.uid, hedefUid: hedefUid)) {
      throw "Bu kullanıcı ile etkileşim kuramazsın.";
    }

    final chatId = await sohbetIdGetirVeyaOlustur(hedefUid);
    final ozet = postMetin.length > 100
        ? "${postMetin.substring(0, 100)}..."
        : postMetin;

    await mesajGonder(
      chatId: chatId,
      hedefUid: hedefUid,
      metin: "@$postKullaniciAdi: $ozet",
      mesajTipi: "post_forward",
      postId: postId,
    );
  }

  // Kendi mesajını yumuşak siler
  static Future<void> mesajSil({
    required String chatId,
    required String messageId,
    required String mevcutMetin,
  }) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) throw "Oturum bulunamadı.";

    final chatRef = SosyalCore.db.collection("chats").doc(chatId);
    final msgRef = chatRef.collection("messages").doc(messageId);

    await SosyalCore.db.runTransaction((tx) async {
      final msgSnap = await tx.get(msgRef);
      if (!msgSnap.exists) throw "Mesaj bulunamadı.";
      final msg = msgSnap.data() ?? <String, dynamic>{};
      if ((msg["senderUid"] ?? "") != current.uid) {
        throw "Sadece kendi mesajını silebilirsin.";
      }
      if (msg["deleted"] == true) return; // Zaten silinmiş

      tx.update(msgRef, {
        "deleted": true,
        "metin": "",
      });
    });

    // Özet güncellemesi başarısız olsa bile mesaj silme işlemi tamamlanmış olsun.
    try {
      final chatSnap = await chatRef.get();
      final chat = chatSnap.data() ?? <String, dynamic>{};
      final sonMesaj = (chat["lastMessage"] ?? "").toString();
      if (sonMesaj == mevcutMetin) {
        await chatRef.set(
          {
            "lastMessage": "Mesaj silindi",
            "updatedAt": FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (_) {}
  }

  // Sohbeti görüldü olarak işaretler
  static Future<void> sohbetiGorulduIsaretle({
    required String chatId,
    Timestamp? seenAt,
  }) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return;
    final chatRef = SosyalCore.db.collection("chats").doc(chatId);
    try {
      final chatSnap = await chatRef.get();
      final chatData = chatSnap.data() ?? <String, dynamic>{};
      final rawSeen = chatData["lastSeenBy"];
      final seenMap = rawSeen is Map
          ? Map<String, dynamic>.from(rawSeen)
          : <String, dynamic>{};
      seenMap[current.uid] = seenAt ?? FieldValue.serverTimestamp();

      final yeniDeger = seenMap[current.uid];
      if (rawSeen is Map) {
        final mevcut = rawSeen[current.uid];
        if (mevcut is Timestamp && yeniDeger is Timestamp) {
          if (mevcut.millisecondsSinceEpoch >= yeniDeger.millisecondsSinceEpoch) {
            return; // Zaten güncel, gereksiz yazma yok
          }
        }
      }

      await chatRef.set(
        {
          "lastSeenBy": seenMap,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      // Rules kaynaklı engelleri debug sırasında görünür kıl.
      debugPrint("sohbetiGorulduIsaretle failed: $e");
    }
  }
}
