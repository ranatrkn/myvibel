// Sosyal alt servislerin tek noktadan erişim cephesi
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vibe_life/sosyal/begeni_yorum_servis.dart';
import 'package:vibe_life/sosyal/bildirim_servis.dart';
import 'package:vibe_life/sosyal/engel_servis.dart';
import 'package:vibe_life/sosyal/etiket_servis.dart';
import 'package:vibe_life/sosyal/mesaj_servis.dart';
import 'package:vibe_life/sosyal/sosyal_core.dart';
import 'package:vibe_life/sosyal/takip_servis.dart';

export 'sosyal/takip_servis.dart' show TakipDurumu, TakipIslemSonucu;

// Tüm sosyal işlemleri yönlendiren ana servis
class SosyalServis {
  // Gönderi paylaşım hız limiti kontrolü
  static Future<void> gonderiPaylasimHizLimitiKontrol(String uid) =>
      SosyalCore.gonderiPaylasimHizLimitiKontrol(uid);

  // Gönderi paylaşım zamanını kaydet
  static Future<void> gonderiPaylasimHizLimitiKaydet(String uid) =>
      SosyalCore.gonderiPaylasimHizLimitiKaydet(uid);

  // Kullanıcı özet bilgisi getir
  static Future<Map<String, dynamic>?> kullaniciOzetGetir(String uid) =>
      SosyalCore.kullaniciOzetGetir(uid);

  // Etiket metnini normalize et
  static String etiketNormalize(String ham) => EtiketServis.etiketNormalize(ham);

  // Arama metninden etiket çıkar
  static String? aramaMetnindenEtiket(String arama) =>
      EtiketServis.aramaMetnindenEtiket(arama);

  // Etiket aramasında gönderi görünürlüğü
  static bool gonderiEtiketAramasindaGorulebilir({
    required Map<String, dynamic> post,
    required String izleyiciUid,
    required Set<String> takipEdilenIdler,
    required Set<String> engelIdleri,
  }) =>
      EtiketServis.gonderiEtiketAramasindaGorulebilir(
        post: post,
        izleyiciUid: izleyiciUid,
        takipEdilenIdler: takipEdilenIdler,
        engelIdleri: engelIdleri,
      );

  // Takip edilen kullanıcı id'lerini getir
  static Future<Set<String>> takipEdilenIdleriGetir(String uid) =>
      TakipServis.takipEdilenIdleriGetir(uid);

  // Hashtag ile gönderileri getir
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      hashtagGonderileriniGetir(
    String hamEtiket, {
    required String izleyiciUid,
    required Set<String> takipEdilenIdler,
    required Set<String> engelIdleri,
    int limit = 30,
  }) =>
      EtiketServis.hashtagGonderileriniGetir(
        hamEtiket,
        izleyiciUid: izleyiciUid,
        takipEdilenIdler: takipEdilenIdler,
        engelIdleri: engelIdleri,
        limit: limit,
      );

  // Bilinen etiketleri topla
  static Future<Set<String>> bilinenEtiketleriGetir({
    required String izleyiciUid,
    required Set<String> takipEdilenIdler,
    required Set<String> engelIdleri,
    int postLimit = 120,
  }) =>
      EtiketServis.bilinenEtiketleriGetir(
        izleyiciUid: izleyiciUid,
        takipEdilenIdler: takipEdilenIdler,
        engelIdleri: engelIdleri,
        postLimit: postLimit,
      );

  // Etiket önerileri listesi
  static List<String> etiketOnerileri(
    Set<String> bilinenEtiketler,
    String sorgu, {
    int limit = 8,
  }) =>
      EtiketServis.etiketOnerileri(bilinenEtiketler, sorgu, limit: limit);

  // Firestore destekli etiket araması
  static Future<List<String>> etiketleriAra({
    required String sorgu,
    required String izleyiciUid,
    required Set<String> takipEdilenIdler,
    required Set<String> engelIdleri,
    required Set<String> bilinenEtiketler,
    int limit = 8,
  }) =>
      EtiketServis.etiketleriAra(
        sorgu: sorgu,
        izleyiciUid: izleyiciUid,
        takipEdilenIdler: takipEdilenIdler,
        engelIdleri: engelIdleri,
        bilinenEtiketler: bilinenEtiketler,
        limit: limit,
      );

  // Metinden hashtag etiketleri ayıkla
  static List<String> etiketleriAyikla(String metin) =>
      EtiketServis.etiketleriAyikla(metin);

  // Metinden @ bahsetmeleri ayıkla
  static List<String> bahsetmeleriAyikla(String metin) =>
      EtiketServis.bahsetmeleriAyikla(metin);

  // Bahsetme uid haritasını parse et
  static Map<String, String> bahsetmeUidHaritasiParse(dynamic raw) =>
      EtiketServis.bahsetmeUidHaritasiParse(raw);

  // Kullanıcı adından uid bul
  static Future<String?> kullaniciUidGetir(String kullaniciAdiKucuk) =>
      EtiketServis.kullaniciUidGetir(kullaniciAdiKucuk);

  // Bahsetmelerin uid'lerini çöz
  static Future<Map<String, String>> bahsetmeUidleriniCoz(String metin) =>
      EtiketServis.bahsetmeUidleriniCoz(metin);

  // Kullanıcı adı önerileri getir
  static Future<List<Map<String, dynamic>>> kullaniciOnerileri(
    String hamPrefix, {
    String? haricUid,
    int limit = 8,
  }) =>
      EtiketServis.kullaniciOnerileri(hamPrefix, haricUid: haricUid, limit: limit);

  // Bahsetme bildirimlerini gönder
  static Future<void> bahsetmeBildirimleriGonder({
    required String gonderenUid,
    required Map<String, String> mentionUidleri,
    required String kaynak,
    String? postId,
    String? chatId,
  }) =>
      EtiketServis.bahsetmeBildirimleriGonder(
        gonderenUid: gonderenUid,
        mentionUidleri: mentionUidleri,
        kaynak: kaynak,
        postId: postId,
        chatId: chatId,
      );

  // Haftalık görev liderlik tablosu
  static Future<List<Map<String, dynamic>>> liderlikTablosuGetir({
    int limit = 25,
  }) =>
      TakipServis.liderlikTablosuGetir(limit: limit);

  // Bekleyen takip ödüllerini senkronize et
  static Future<void> takipOdulleriniSenkronizeEt(String uid) =>
      TakipServis.takipOdulleriniSenkronizeEt(uid);

  // Takip edilen profilleri listele
  static Future<List<Map<String, dynamic>>> takipEdilenProfilleriGetir(
    String uid,
  ) =>
      TakipServis.takipEdilenProfilleriGetir(uid);

  // Sohbet sessize alınmış mı
  static bool sohbetSessizMi({
    required String uid,
    required Map<String, dynamic> chat,
  }) =>
      MesajServis.sohbetSessizMi(uid: uid, chat: chat);

  // Sohbet sessizlik durumunu değiştir
  static Future<void> sohbetSessizliginiDegistir({
    required String chatId,
    required String uid,
    required bool sessiz,
  }) =>
      MesajServis.sohbetSessizliginiDegistir(
        chatId: chatId,
        uid: uid,
        sessiz: sessiz,
      );

  // Bildirim ekle
  static Future<void> bildirimEkle({
    required String hedefUid,
    required String tip,
    required String gonderenUid,
    String? postId,
    String? chatId,
    String? metin,
    String? postMetin,
  }) =>
      BildirimServis.bildirimEkle(
        hedefUid: hedefUid,
        tip: tip,
        gonderenUid: gonderenUid,
        postId: postId,
        chatId: chatId,
        metin: metin,
        postMetin: postMetin,
      );

  // Bildirim sil
  static Future<void> bildirimSil(String uid, String bildirimId) =>
      BildirimServis.bildirimSil(uid, bildirimId);

  // Takip isteği bildirimlerini sil
  static Future<void> takipIstegiBildirimleriniSil(
    String hedefUid,
    String istekciUid,
  ) =>
      BildirimServis.takipIstegiBildirimleriniSil(hedefUid, istekciUid);

  // Bildirimi okundu yap
  static Future<void> bildirimOkunduYap(String uid, String bildirimId) =>
      BildirimServis.bildirimOkunduYap(uid, bildirimId);

  // Tüm bildirimleri okundu yap
  static Future<void> tumBildirimleriOkunduYap(String uid) =>
      BildirimServis.tumBildirimleriOkunduYap(uid);

  // Okunmamış bildirim sayısı akışı
  static Stream<int> okunmamisBildirimSayisi(String uid) =>
      BildirimServis.okunmamisBildirimSayisi(uid);

  // Gönderilerde hesap gizliliğini güncelle
  static Future<void> kullaniciGonderilerindeGizlilikGuncelle(
    String uid,
    bool hesapGizli,
  ) =>
      EngelServis.kullaniciGonderilerindeGizlilikGuncelle(uid, hesapGizli);

  // Takip durumunu sorgula
  static Future<TakipDurumu> takipDurumuGetir(String hedefUid) =>
      TakipServis.takipDurumuGetir(hedefUid);

  // İzleyici hedefi takip ediyor mu
  static Future<bool> takipciMi({
    required String izleyiciUid,
    required String hedefUid,
  }) =>
      TakipServis.takipciMi(izleyiciUid: izleyiciUid, hedefUid: hedefUid);

  // Gönderi izleyiciye görünür mü
  static Future<bool> gonderiGorulebilir({
    required String izleyiciUid,
    required String postOwnerUid,
  }) =>
      TakipServis.gonderiGorulebilir(
        izleyiciUid: izleyiciUid,
        postOwnerUid: postOwnerUid,
      );

  // Profil gönderileri görünür mü
  static Future<bool> profilGonderileriGorulebilir({
    required String izleyiciUid,
    required String profilUid,
    bool? hesapGizli,
  }) =>
      TakipServis.profilGonderileriGorulebilir(
        izleyiciUid: izleyiciUid,
        profilUid: profilUid,
        hesapGizli: hesapGizli,
      );

  // Eksik takip bağlantısını onar
  static Future<void> takipBaglantisiniOnar({
    required String takipEdenUid,
    required String hedefUid,
  }) =>
      TakipServis.takipBaglantisiniOnar(
        takipEdenUid: takipEdenUid,
        hedefUid: hedefUid,
      );

  // Kullanıcıyı takip et
  static Future<String> takipEt(String hedefUid) => TakipServis.takipEt(hedefUid);

  // Takipten çık
  static Future<String> takiptenCik(String hedefUid) =>
      TakipServis.takiptenCik(hedefUid);

  // Etkileşim engelli mi kontrol et
  static Future<bool> etkilesimEngelliMi(String hedefUid) =>
      TakipServis.etkilesimEngelliMi(hedefUid);

  // Takip isteğini iptal et
  static Future<String> takipIstegiIptal(String hedefUid) =>
      TakipServis.takipIstegiIptal(hedefUid);

  // Takip isteğini kabul et
  static Future<TakipIslemSonucu> takipIstegiKabul(String istekciUid) =>
      TakipServis.takipIstegiKabul(istekciUid);

  // Takip isteğini reddet
  static Future<TakipIslemSonucu> takipIstegiRed(String istekciUid) =>
      TakipServis.takipIstegiRed(istekciUid);

  // Takip butonuna basıldığında işlem yap
  static Future<String> takipButonunaBas(
      String hedefUid, TakipDurumu durum) =>
      TakipServis.takipButonunaBas(hedefUid, durum);

  // Takip butonu metnini döndür
  static String takipButonMetni(TakipDurumu durum) =>
      TakipServis.takipButonMetni(durum);

  // Kullanıcıyı engelle
  static Future<void> engelleKullanici(String hedefUid) =>
      EngelServis.engelleKullanici(hedefUid);

  // Kullanıcı adını güncelle
  static Future<void> kullaniciAdiGuncelle({
    required String uid,
    required String eskiKullaniciAdiKucuk,
    required String yeniKullaniciAdi,
    required String yeniKullaniciAdiKucuk,
  }) =>
      EngelServis.kullaniciAdiGuncelle(
        uid: uid,
        eskiKullaniciAdiKucuk: eskiKullaniciAdiKucuk,
        yeniKullaniciAdi: yeniKullaniciAdi,
        yeniKullaniciAdiKucuk: yeniKullaniciAdiKucuk,
      );

  // Sohbeti gizle
  static Future<void> sohbetiGizle({
    required String chatId,
    required String uid,
  }) =>
      MesajServis.sohbetiGizle(chatId: chatId, uid: uid);

  // Sohbet gizli mi kontrol et
  static bool sohbetGizliMi({
    required String uid,
    required Map<String, dynamic> chat,
    int? localHiddenAtMs,
  }) =>
      MesajServis.sohbetGizliMi(
        uid: uid,
        chat: chat,
        localHiddenAtMs: localHiddenAtMs,
      );

  // Sohbette okunmamış mesaj var mı
  static bool sohbetOkunmamisMi({
    required String uid,
    required Map<String, dynamic> chat,
    int? localReadAtMs,
  }) =>
      MesajServis.sohbetOkunmamisMi(
        uid: uid,
        chat: chat,
        localReadAtMs: localReadAtMs,
      );

  // Engeli kaldır
  static Future<void> engeliKaldir(String hedefUid) =>
      EngelServis.engeliKaldir(hedefUid);

  // Engel durumunu getir
  static Future<Map<String, bool>> engelDurumuGetir(String hedefUid) =>
      EngelServis.engelDurumuGetir(hedefUid);

  // Engellenen kullanıcıları getir
  static Future<Set<String>> engellenenKullanicilariGetir(String uid) =>
      EngelServis.engellenenKullanicilariGetir(uid);

  // Beni engelleyenleri getir
  static Future<Set<String>> beniEngelleyenKullanicilariGetir(String uid) =>
      EngelServis.beniEngelleyenKullanicilariGetir(uid);

  // Kullanıcıyı şikayet et
  static Future<void> kullaniciSikayetEt({
    required String hedefUid,
    required String sebep,
    String aciklama = "",
  }) =>
      EngelServis.kullaniciSikayetEt(
        hedefUid: hedefUid,
        sebep: sebep,
        aciklama: aciklama,
      );

  // Gönderiyi şikayet et
  static Future<void> gonderiSikayetEt({
    required String postId,
    required String postOwnerId,
    required String sebep,
    String aciklama = "",
  }) =>
      EngelServis.gonderiSikayetEt(
        postId: postId,
        postOwnerId: postOwnerId,
        sebep: sebep,
        aciklama: aciklama,
      );

  // Yorumu şikayet et
  static Future<void> yorumSikayetEt({
    required String postId,
    required String yorumId,
    required String yorumSahibiUid,
    required String sebep,
    String aciklama = "",
  }) =>
      EngelServis.yorumSikayetEt(
        postId: postId,
        yorumId: yorumId,
        yorumSahibiUid: yorumSahibiUid,
        sebep: sebep,
        aciklama: aciklama,
      );

  // Kendi gönderisi mi kontrol et
  static bool kendiGonderisiMi({
    required String postOwnerId,
    required String currentUserId,
  }) =>
      SosyalCore.kendiGonderisiMi(
        postOwnerId: postOwnerId,
        currentUserId: currentUserId,
      );

  // Beğeni ekle veya kaldır
  static Future<bool> begeniDegistir({
    required String postId,
    required String postOwnerId,
    required String currentUserId,
  }) =>
      BegeniYorumServis.begeniDegistir(
        postId: postId,
        postOwnerId: postOwnerId,
        currentUserId: currentUserId,
      );

  static Future<void> gecersizBegeniKayitlariniTemizle(String uid) =>
      BegeniYorumServis.gecersizBegeniKayitlariniTemizle(uid);

  // Yorum ekle
  static Future<void> yorumEkle({
    required String postId,
    required String postOwnerId,
    required String currentUserId,
    required String metin,
  }) =>
      BegeniYorumServis.yorumEkle(
        postId: postId,
        postOwnerId: postOwnerId,
        currentUserId: currentUserId,
        metin: metin,
      );

  // Gönderiyi sil
  static Future<void> gonderiSil(String postId) =>
      BegeniYorumServis.gonderiSil(postId);

  // İki kullanıcı için sohbet id üret
  static String sohbetIdUret(String uid1, String uid2) =>
      MesajServis.sohbetIdUret(uid1, uid2);

  // Sohbet id getir veya oluştur
  static Future<String> sohbetIdGetirVeyaOlustur(String hedefUid) =>
      MesajServis.sohbetIdGetirVeyaOlustur(hedefUid);

  // Kullanıcının sohbet listesi akışı
  static Stream<QuerySnapshot<Map<String, dynamic>>> sohbetlerim(String uid) =>
      MesajServis.sohbetlerim(uid);

  // Sohbet mesajları akışı
  static Stream<QuerySnapshot<Map<String, dynamic>>> sohbetMesajlari(
      String chatId) =>
      MesajServis.sohbetMesajlari(chatId);

  // Mesaj gönder
  static Future<void> mesajGonder({
    required String chatId,
    required String hedefUid,
    required String metin,
    String mesajTipi = "text",
    String postId = "",
  }) =>
      MesajServis.mesajGonder(
        chatId: chatId,
        hedefUid: hedefUid,
        metin: metin,
        mesajTipi: mesajTipi,
        postId: postId,
      );

  // Gönderiyi mesaj olarak ilet
  static Future<void> gonderiIlet({
    required String postId,
    required String hedefUid,
    required String postMetin,
    required String postKullaniciAdi,
  }) =>
      MesajServis.gonderiIlet(
        postId: postId,
        hedefUid: hedefUid,
        postMetin: postMetin,
        postKullaniciAdi: postKullaniciAdi,
      );

  // Mesajı sil
  static Future<void> mesajSil({
    required String chatId,
    required String messageId,
    required String mevcutMetin,
  }) =>
      MesajServis.mesajSil(
        chatId: chatId,
        messageId: messageId,
        mevcutMetin: mevcutMetin,
      );

  // Sohbeti görüldü olarak işaretle
  static Future<void> sohbetiGorulduIsaretle({
    required String chatId,
    Timestamp? seenAt,
  }) =>
      MesajServis.sohbetiGorulduIsaretle(chatId: chatId, seenAt: seenAt);
}
