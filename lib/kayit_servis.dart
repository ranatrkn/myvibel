// E-posta doğrulanmadan tam profil oluşturulmaz; iptal edilince kayıt silinir.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_eposta.dart';
import 'error_messages.dart';
import 'firebase_options.dart';
import 'maskot_servis.dart';
import 'rety_renk.dart';
import 'sosyal/etiket_servis.dart';
import 'yas_dogrulama.dart';
import 'yasal_icerik.dart';

class KayitServis {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _beklemeSuresi = Duration(hours: 48);
  static const _profilCachePrefix = 'profil_tamam_';

  static String profilOnbellekAnahtari(String uid) => '$_profilCachePrefix$uid';

  /// Uygulama profili (users koleksiyonu) oluşmuş mu?
  static Future<bool> profilTamamlandiMi(String uid) async {
    // Web: SDK “offline” takılmasın diye önce REST.
    if (kIsWeb) {
      try {
        final varMi = await _profilRestVarMi(uid);
        if (varMi) await profilTamamlandiOnbellegeAl(uid);
        return varMi;
      } catch (e) {
        debugPrint('profilTamamlandiMi REST: $e');
      }
    }

    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 12));
      if (doc.exists) {
        await profilTamamlandiOnbellegeAl(uid);
      }
      return doc.exists;
    } on TimeoutException {
      debugPrint('profilTamamlandiMi timeout');
      return false;
    } catch (e) {
      debugPrint('profilTamamlandiMi: $e');
      return false;
    }
  }

  static Future<bool> _profilRestVarMi(String uid) async {
    final opts = DefaultFirebaseOptions.currentPlatform;
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${opts.projectId}'
      '/databases/(default)/documents/users/${Uri.encodeComponent(uid)}'
      '?key=${Uri.encodeQueryComponent(opts.apiKey)}',
    );
    final token = await _auth.currentUser?.getIdToken();
    final yanit = await http.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 12));
    if (yanit.statusCode == 200) return true;
    if (yanit.statusCode == 404) return false;
    throw StateError('profil REST ${yanit.statusCode}');
  }

  /// Önceki oturumda doğrulanmış profil varsa Firestore beklemeden aç.
  static Future<bool> profilTamamlandiMiHizli(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('$_profilCachePrefix$uid') == true) {
      unawaited(profilTamamlandiMi(uid));
      return true;
    }
    return profilTamamlandiMi(uid);
  }

  static Future<void> profilTamamlandiOnbellegeAl(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_profilCachePrefix$uid', true);
  }

  static Future<void> profilOnbelleginiTemizle(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_profilCachePrefix$uid');
  }

  /// Bekleyen kayıt var mı?
  static Future<bool> bekleyenKayitVarMi(String uid) async {
    try {
      final doc = await _db
          .collection('pendingProfiles')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 12));
      return doc.exists;
    } catch (e) {
      debugPrint('bekleyenKayitVarMi: $e');
      return false;
    }
  }

  /// Bekleyen kayıt / kullanıcı adı rezervasyonu süresi dolmuş mu?
  /// Pending yoksa false döner (henüz yazılmamış veya hiç yok) —
  /// "yok = süresi dolmuş" saymak kayıt anında Auth hesabını sildiriyordu.
  static Future<bool> bekleyenKayitSuresiDolmusMu(String uid) async {
    try {
      final pending = await _db
          .collection('pendingProfiles')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 12));
      if (!pending.exists) return false;

      final kucuk = pending.data()?['kullaniciAdiKucuk']?.toString() ?? '';
      if (kucuk.isNotEmpty) {
        final hold = await _db
            .collection('usernameHolds')
            .doc(kucuk)
            .get()
            .timeout(const Duration(seconds: 8));
        if (hold.exists) return _holdSuresiDolmus(hold.data());
      }

      final createdAt = pending.data()?['createdAt'];
      if (createdAt is Timestamp) {
        return createdAt.toDate().add(_beklemeSuresi).isBefore(DateTime.now());
      }
      return false;
    } catch (e) {
      debugPrint('bekleyenKayitSuresiDolmusMu: $e');
      return false;
    }
  }

  /// Auth hesabı + bekleyen profil oluşturur; users/usernames henüz yazılmaz.
  /// Mail gönderilemezse hata metni döner; kayıt yine de tamamlanmış olur.
  static Future<String?> bekleyenKayitOlustur({
    required String adSoyad,
    required String kullaniciAdi,
    required String kullaniciAdiKucuk,
    required String email,
    required String sifre,
    required DateTime dogumTarihi,
  }) async {
    if (!YasDogrulama.kayitIcinUygunMu(dogumTarihi)) {
      throw YasDogrulama.kayitYasMesaji(YasalIcerik.uygulamaAdi);
    }

    final dogumTs = Timestamp.fromDate(YasDogrulama.sadeceTarih(dogumTarihi));
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: sifre,
    );
    final user = credential.user;
    if (user == null) {
      throw 'Kullanıcı oluşturulamadı.';
    }

    final usernameRef = _db.collection('usernames').doc(kullaniciAdiKucuk);
    final holdRef = _db.collection('usernameHolds').doc(kullaniciAdiKucuk);
    final pendingRef = _db.collection('pendingProfiles').doc(user.uid);

    try {
      await user.updateDisplayName(kullaniciAdi);

      final expiresAt =
          Timestamp.fromDate(DateTime.now().add(_beklemeSuresi));

      await _db.runTransaction((tx) async {
        final uSnap = await tx.get(usernameRef);
        if (uSnap.exists) {
          throw 'Bu kullanıcı adı zaten alınmış.';
        }

        final hSnap = await tx.get(holdRef);
        if (hSnap.exists &&
            hSnap.data()?['uid'] != user.uid &&
            !_holdSuresiDolmus(hSnap.data())) {
          throw 'Bu kullanıcı adı şu an başka bir kayıtta.';
        }

        tx.set(holdRef, {
          'uid': user.uid,
          'kullaniciAdiKucuk': kullaniciAdiKucuk,
          'expiresAt': expiresAt,
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.set(pendingRef, {
          'uid': user.uid,
          'adSoyad': adSoyad,
          'kullaniciAdi': kullaniciAdi,
          'kullaniciAdiKucuk': kullaniciAdiKucuk,
          'email': email,
          'dogumTarihi': dogumTs,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      await bekleyenKayitKayitlariniSil(
        user.uid,
        kullaniciAdiKucukHint: kullaniciAdiKucuk,
      );
      await _authHesabiniSil(user);
      rethrow;
    }

    try {
      await epostaDogrulamaMailiGonder(user);
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Kayıt sonrası e-posta gönderilemedi: ${e.code} ${e.message}');
      return epostaGonderimHataMesaji(e);
    }
  }

  /// E-posta doğrulandıktan veya linkle girişten sonra gerçek profili oluşturur.
  static Future<void> profilOlustur({
    required String uid,
    required String adSoyad,
    required String kullaniciAdi,
    required String kullaniciAdiKucuk,
    required String email,
    DateTime? dogumTarihi,
    String photoUrl = '',
  }) async {
    if (kullaniciAdiKucuk.length < 3) {
      throw 'Kayıt bilgisi geçersiz. Lütfen yeniden kayıt ol.';
    }

    final userRef = _db.collection('users').doc(uid);
    final usernameRef = _db.collection('usernames').doc(kullaniciAdiKucuk);
    final holdRef = _db.collection('usernameHolds').doc(kullaniciAdiKucuk);
    final pendingRef = _db.collection('pendingProfiles').doc(uid);

    await _db.runTransaction((tx) async {
      final mevcutProfil = await tx.get(userRef);
      if (mevcutProfil.exists) return;

      final uSnap = await tx.get(usernameRef);
      final holdSnap = await tx.get(holdRef);
      final pendingSnap = await tx.get(pendingRef);

      final cocuk =
          dogumTarihi != null && YasDogrulama.cocukHesabiMi(dogumTarihi);

      if (uSnap.exists) {
        throw 'Bu kullanıcı adı artık alınmış. Farklı bir ad ile yeniden kayıt ol.';
      }
      if (holdSnap.exists) {
        final holdUid = holdSnap.data()?['uid']?.toString() ?? '';
        if (holdUid.isNotEmpty &&
            holdUid != uid &&
            !_holdSuresiDolmus(holdSnap.data())) {
          throw 'Bu kullanıcı adı şu an başka bir kayıtta.';
        }
      }

      tx.set(userRef, {
        'uid': uid,
        'adSoyad': adSoyad,
        'kullaniciAdi': kullaniciAdi,
        'kullaniciAdiKucuk': kullaniciAdiKucuk,
        'photoUrl': '',
        'avatarKey': 'koala_blue',
        'aramaSkoru': 0,
        'puan': 0,
        'gonderiSayisi': 0,
        'begeniSayisi': 0,
        'yorumSayisi': 0,
        'hesapGizli': cocuk,
        'cocukHesabi': cocuk,
        'robot': {
          'isim': MascotServis.varsayilanIsim,
          'renk': RetyRenk.varsayilan.id,
          'seviye': 1,
          'gelisimPuani': 0,
          'etkilesimPuani': 0,
          'enerji': 50,
          'mutluluk': 50,
          'sonUygulamaMs': DateTime.now().millisecondsSinceEpoch,
          'sonEtkilesimMs': DateTime.now().millisecondsSinceEpoch,
          'sonMutlulukTickMs': DateTime.now().millisecondsSinceEpoch,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      // E-posta / doğum tarihi public profilde değil.
      tx.set(userRef.collection('private').doc('account'), {
        'email': email,
        if (dogumTarihi != null)
          'dogumTarihi':
              Timestamp.fromDate(YasDogrulama.sadeceTarih(dogumTarihi)),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(userRef.collection('private').doc('loginEmail'), {
        'email': email.trim().toLowerCase(),
      });

      tx.set(usernameRef, {
        'uid': uid,
        'kullaniciAdi': kullaniciAdi,
        'email': email.trim().toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (pendingSnap.exists) tx.delete(pendingRef);
      if (holdSnap.exists) tx.delete(holdRef);
    });
    await profilTamamlandiOnbellegeAl(uid);
  }

  /// Eski public profildeki e-posta/doğum tarihini private/account'a taşır.
  static Future<void> hassasProfiliAyir(String uid) async {
    if (uid.isEmpty) return;
    final userRef = _db.collection('users').doc(uid);
    try {
      final snap = await userRef.get();
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;
      final email = data['email'];
      final dogum = data['dogumTarihi'];
      if (email == null && dogum == null) return;

      final privateRef = userRef.collection('private').doc('account');
      final privateSnap = await privateRef.get();
      final privateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (email != null && email.toString().isNotEmpty) {
        privateData['email'] = email.toString();
      }
      if (dogum != null) {
        privateData['dogumTarihi'] = dogum;
      }
      if (!privateSnap.exists) {
        await privateRef.set(privateData);
      } else {
        await privateRef.set(privateData, SetOptions(merge: true));
      }

      await userRef.update({
        'email': FieldValue.delete(),
        'dogumTarihi': FieldValue.delete(),
      });

      // Kullanıcı adı ile giriş için usernames belgesine e-posta yaz.
      final kucuk = data['kullaniciAdiKucuk']?.toString().trim().toLowerCase() ?? '';
      final emailStr = (email ??
              privateData['email'] ??
              _auth.currentUser?.email)
          ?.toString()
          .trim();
      if (kucuk.length >= 3 && emailStr != null && emailStr.contains('@')) {
        final emailNorm = emailStr.toLowerCase();
        await _db.collection('usernames').doc(kucuk).set({
          'email': emailNorm,
        }, SetOptions(merge: true));
        await userRef.collection('private').doc('loginEmail').set({
          'email': emailNorm,
        });
      }
    } catch (e) {
      debugPrint('hassasProfiliAyir: $e');
    }
  }

  /// Auth e-postasını usernames belgesine yazar (eski hesaplar / kullanıcı adı girişi).
  static Future<void> kullaniciAdiGirisEmailiniSenkronla(String uid) async {
    if (uid.isEmpty) return;
    final email = _auth.currentUser?.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty || !email.contains('@')) return;
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final kucuk = EtiketServis.etiketNormalize(
        snap.data()?['kullaniciAdiKucuk']?.toString() ?? '',
      ).replaceAll(RegExp(r'[^a-z0-9._]'), '');
      if (kucuk.length < 3) return;
      // Sadece email — rules update hasOnly ile uyumlu.
      await _db.collection('usernames').doc(kucuk).set({
        'email': email,
      }, SetOptions(merge: true));
      await _db
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('loginEmail')
          .set({'email': email});
    } catch (e) {
      debugPrint('kullaniciAdiGirisEmailiniSenkronla: $e');
    }
  }

  static String _girisKullaniciAdiNormalize(String ham) {
    var kucuk = EtiketServis.etiketNormalize(ham.trim());
    if (kucuk.startsWith('@')) kucuk = kucuk.substring(1);
    kucuk = kucuk.replaceAll(RegExp(r'[^a-z0-9._]'), '');
    return kucuk;
  }

  /// Giriş alanı: e-posta veya kullanıcı adı → Auth e-postası.
  static Future<String> girisKimliginiCoz(String girdi) async {
    final ham = girdi.trim();
    if (ham.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'E-posta veya kullanıcı adı gir.',
      );
    }
    if (ham.contains('@') && ham.indexOf('@') > 0) {
      // Kullanıcı adı değil, gerçek e-posta (başta @ olan bahsetmeyi ayır).
      return ham.toLowerCase();
    }

    final kucuk = _girisKullaniciAdiNormalize(ham);
    if (kucuk.length < 3) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Geçerli bir e-posta veya kullanıcı adı gir.',
      );
    }

    try {
      // Web'de Firestore SDK sık “offline” sanıyor; önce REST dene.
      if (kIsWeb) {
        try {
          return await _kullaniciAdindanEmailRest(kucuk);
        } catch (e) {
          if (e is FirebaseAuthException) rethrow;
          debugPrint('girisKimliginiCoz web REST ilk deneme: $e');
        }
      }
      return await _kullaniciAdindanEmailCoz(kucuk);
    } on FirebaseAuthException {
      rethrow;
    } on FirebaseException catch (e) {
      // Web'de Firestore SDK bazen sahte "offline" verir; REST ile yedekle.
      debugPrint('girisKimliginiCoz SDK: ${e.code} ${e.message}');
      try {
        return await _kullaniciAdindanEmailRest(kucuk);
      } on FirebaseAuthException {
        rethrow;
      } catch (restHata) {
        debugPrint('girisKimliginiCoz REST: $restHata');
        throw FirebaseAuthException(
          code: 'network-request-failed',
          message: baglantiUyariMesaji(restHata),
        );
      }
    } catch (e) {
      debugPrint('girisKimliginiCoz: $e');
      try {
        return await _kullaniciAdindanEmailRest(kucuk);
      } on FirebaseAuthException {
        rethrow;
      } catch (restHata) {
        throw FirebaseAuthException(
          code: 'network-request-failed',
          message: baglantiUyariMesaji(restHata),
        );
      }
    }
  }

  static Future<String> _kullaniciAdindanEmailCoz(String kucuk) async {
    final doc = await _db
        .collection('usernames')
        .doc(kucuk)
        .get()
        .timeout(const Duration(seconds: 12));
    if (!doc.exists) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Bu kullanıcı adı bulunamadı.',
      );
    }

    var email = doc.data()?['email']?.toString().trim().toLowerCase() ?? '';
    if (email.contains('@')) return email;

    // Eski kayıtlarda email usernames'te yok; profil / loginEmail'den dene.
    final uid = doc.data()?['uid']?.toString() ?? '';
    if (uid.isNotEmpty) {
      final userRef = _db.collection('users').doc(uid);
      try {
        final userSnap =
            await userRef.get().timeout(const Duration(seconds: 10));
        email = userSnap.data()?['email']?.toString().trim().toLowerCase() ?? '';
        if (email.contains('@')) return email;
      } catch (e) {
        debugPrint('girisKimliginiCoz public profil: $e');
      }
      try {
        final loginSnap = await userRef
            .collection('private')
            .doc('loginEmail')
            .get()
            .timeout(const Duration(seconds: 10));
        email = loginSnap.data()?['email']?.toString().trim().toLowerCase() ?? '';
        if (email.contains('@')) return email;
      } catch (e) {
        debugPrint('girisKimliginiCoz loginEmail: $e');
      }
    }

    throw FirebaseAuthException(
      code: 'user-not-found',
      message:
          'Bu kullanıcı adı için giriş henüz hazır değil. Bir kez e-posta ile giriş yap, sonra kullanıcı adınla da girebilirsin.',
    );
  }

  /// Firestore SDK (web) bağlanamazsa public get kurallarıyla REST yedek.
  static Future<String> _kullaniciAdindanEmailRest(String kucuk) async {
    final opts = DefaultFirebaseOptions.currentPlatform;
    final encoded = Uri.encodeComponent(kucuk);
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${opts.projectId}'
      '/databases/(default)/documents/usernames/$encoded'
      '?key=${Uri.encodeQueryComponent(opts.apiKey)}',
    );

    final yanit = await http.get(uri).timeout(const Duration(seconds: 15));
    if (yanit.statusCode == 404) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Bu kullanıcı adı bulunamadı.',
      );
    }
    if (yanit.statusCode != 200) {
      throw StateError('REST usernames ${yanit.statusCode}: ${yanit.body}');
    }

    final json = jsonDecode(yanit.body);
    if (json is! Map<String, dynamic>) {
      throw StateError('REST usernames beklenmeyen gövde');
    }
    final fields = json['fields'];
    if (fields is! Map) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Bu kullanıcı adı bulunamadı.',
      );
    }

    var email = _firestoreRestString(fields, 'email')?.toLowerCase() ?? '';
    if (email.contains('@')) return email;

    final uid = _firestoreRestString(fields, 'uid') ?? '';
    if (uid.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message:
            'Bu kullanıcı adı için giriş henüz hazır değil. Bir kez e-posta ile giriş yap, sonra kullanıcı adınla da girebilirsin.',
      );
    }

    final loginUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${opts.projectId}'
      '/databases/(default)/documents/users/${Uri.encodeComponent(uid)}'
      '/private/loginEmail'
      '?key=${Uri.encodeQueryComponent(opts.apiKey)}',
    );
    final loginYanit =
        await http.get(loginUri).timeout(const Duration(seconds: 15));
    if (loginYanit.statusCode == 200) {
      final loginJson = jsonDecode(loginYanit.body);
      if (loginJson is Map<String, dynamic>) {
        final loginFields = loginJson['fields'];
        if (loginFields is Map) {
          email =
              _firestoreRestString(loginFields, 'email')?.toLowerCase() ?? '';
          if (email.contains('@')) return email;
        }
      }
    }

    throw FirebaseAuthException(
      code: 'user-not-found',
      message:
          'Bu kullanıcı adı için giriş henüz hazır değil. Bir kez e-posta ile giriş yap, sonra kullanıcı adınla da girebilirsin.',
    );
  }

  static String? _firestoreRestString(Map fields, String alan) {
    final deger = fields[alan];
    if (deger is Map && deger['stringValue'] is String) {
      return (deger['stringValue'] as String).trim();
    }
    return null;
  }

  /// E-posta doğrulandıktan sonra gerçek profili oluşturur (eski akış).
  static Future<void> dogrulamaSonrasiKaydiTamamla() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'Oturum bulunamadı.';
    }

    await user.reload();
    final guncel = _auth.currentUser;
    if (guncel == null || !guncel.emailVerified) {
      throw 'E-posta henüz doğrulanmamış.';
    }
    await guncel.getIdToken(true);

    final userRef = _db.collection('users').doc(guncel.uid);
    final mevcutProfil = await userRef.get();
    if (mevcutProfil.exists) return;

    final pendingRef = _db.collection('pendingProfiles').doc(guncel.uid);
    final pendingSnap = await pendingRef.get();
    if (!pendingSnap.exists) {
      throw 'Kayıt bilgisi bulunamadı. Lütfen yeniden kayıt ol.';
    }

    final pending = pendingSnap.data() ?? {};
    final kullaniciAdi = pending['kullaniciAdi']?.toString() ?? '';
    final kullaniciAdiKucuk = pending['kullaniciAdiKucuk']?.toString() ?? '';
    final adSoyad = pending['adSoyad']?.toString() ?? '';
    final email = pending['email']?.toString() ?? guncel.email ?? '';
    final dogumTarihi = _dogumTarihiOku(pending['dogumTarihi']);

    if (kullaniciAdiKucuk.length < 3) {
      throw 'Kayıt bilgisi geçersiz. Lütfen yeniden kayıt ol.';
    }

    if (dogumTarihi != null && !YasDogrulama.kayitIcinUygunMu(dogumTarihi)) {
      throw YasDogrulama.kayitYasMesaji(YasalIcerik.uygulamaAdi);
    }

    await profilOlustur(
      uid: guncel.uid,
      adSoyad: adSoyad,
      kullaniciAdi: kullaniciAdi,
      kullaniciAdiKucuk: kullaniciAdiKucuk,
      email: email,
      dogumTarihi: dogumTarihi,
    );
  }

  /// Tamamlanmamış profil dokümanını (users + usernames) siler.
  static Future<void> yarimProfiliSil(
    String uid, {
    String? kullaniciAdiKucuk,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final userSnap = await userRef.get();
    var kucuk = kullaniciAdiKucuk?.trim().toLowerCase() ?? '';
    if (kucuk.isEmpty) {
      kucuk =
          userSnap.data()?['kullaniciAdiKucuk']?.toString().trim().toLowerCase() ??
              '';
    }

    final batch = _db.batch();
    if (userSnap.exists) batch.delete(userRef);
    if (kucuk.isNotEmpty) {
      final usernameRef = _db.collection('usernames').doc(kucuk);
      final username = await usernameRef.get();
      if (username.exists && username.data()?['uid']?.toString() == uid) {
        batch.delete(usernameRef);
      }
    }
    await batch.commit();
    await profilOnbelleginiTemizle(uid);
  }

  /// Tamamlanmamış kayıt iptal: bekleyen Firestore + Auth hesabı silinir.
  /// Profil (`users`) oluşmuşsa yalnızca oturum kapatılır.
  /// [authSilmedenOnceYenidenDogrula] Google hesaplarında delete öncesi çağrılır.
  static Future<void> bekleyenKayitIptal({
    Future<void> Function()? authSilmedenOnceYenidenDogrula,
    String? mevcutSifre,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      await _auth.signOut();
      return;
    }

    final uid = user.uid;
    final displayHint = user.displayName?.trim().toLowerCase();
    final profilVar = await profilTamamlandiMi(uid);

    if (!profilVar) {
      if (authSilmedenOnceYenidenDogrula != null) {
        try {
          await authSilmedenOnceYenidenDogrula();
        } on FirebaseAuthException catch (e) {
          if (e.code == 'canceled' || e.code == 'sign_in_canceled') {
            await profilOnbelleginiTemizle(uid);
            if (_auth.currentUser != null) await _auth.signOut();
            return;
          }
          rethrow;
        }
      }
      if (mevcutSifre != null &&
          mevcutSifre.isNotEmpty &&
          user.email != null &&
          user.email!.contains('@')) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: mevcutSifre,
        );
        await user.reauthenticateWithCredential(credential);
      }
      final guncel = _auth.currentUser;
      if (guncel != null) {
        await guncel.delete();
      }
    }

    await bekleyenKayitKayitlariniSil(
      uid,
      kullaniciAdiKucukHint: displayHint,
      yarimUsernameSil: !profilVar,
    );

    await profilOnbelleginiTemizle(uid);
    if (_auth.currentUser != null) {
      await _auth.signOut();
    }
  }

  /// pendingProfiles, usernameHolds ve (isteğe bağlı) yarım usernames temizliği.
  static Future<void> bekleyenKayitKayitlariniSil(
    String uid, {
    String? kullaniciAdiKucukHint,
    bool yarimUsernameSil = true,
  }) async {
    final pendingRef = _db.collection('pendingProfiles').doc(uid);
    final pending = await pendingRef.get();
    final pendingKucuk =
        pending.data()?['kullaniciAdiKucuk']?.toString().trim().toLowerCase() ??
            '';

    final adaylar = <String>{};
    if (pendingKucuk.isNotEmpty) adaylar.add(pendingKucuk);
    final hint = kullaniciAdiKucukHint?.trim().toLowerCase() ?? '';
    if (hint.length >= 3) adaylar.add(hint);

    try {
      final holdSnap = await _db
          .collection('usernameHolds')
          .where('uid', isEqualTo: uid)
          .get();
      for (final doc in holdSnap.docs) {
        adaylar.add(doc.id);
      }
    } catch (e) {
      debugPrint('usernameHolds uid sorgusu: $e');
    }

    final batch = _db.batch();
    batch.delete(pendingRef);

    for (final kucuk in adaylar) {
      final holdRef = _db.collection('usernameHolds').doc(kucuk);
      final hold = await holdRef.get();
      if (hold.exists && hold.data()?['uid']?.toString() == uid) {
        batch.delete(holdRef);
      }

      if (yarimUsernameSil) {
        final usernameRef = _db.collection('usernames').doc(kucuk);
        final username = await usernameRef.get();
        if (username.exists &&
            username.data()?['uid']?.toString() == uid) {
          final userDoc = await _db.collection('users').doc(uid).get();
          if (!userDoc.exists) {
            batch.delete(usernameRef);
          }
        }
      }
    }

    await batch.commit();
  }

  static DateTime? _dogumTarihiOku(dynamic raw) {
    if (raw is Timestamp) return YasDogrulama.sadeceTarih(raw.toDate());
    return null;
  }

  static bool _holdSuresiDolmus(Map<String, dynamic>? data) {
    if (data == null) return true;
    final expiresAt = data['expiresAt'];
    if (expiresAt is! Timestamp) return true;
    return expiresAt.toDate().isBefore(DateTime.now());
  }

  /// Doğrulanmamış / süresi dolmuş / bekleyen kaydı olmayan boş oturumu siler.
  static Future<bool> gecersizOturumuTemizle(User user) async {
    if (await profilTamamlandiMi(user.uid)) return false;

    final oauthMu = user.providerData.any(
      (info) =>
          info.providerId == 'google.com' || info.providerId == 'apple.com',
    );
    // Google/Apple oturumu: profil tamamlama / Feed'e bırak.
    // Şifre bağlanınca emailVerified false olsa bile silme.
    if (oauthMu) return false;

    final bekleyen = await bekleyenKayitVarMi(user.uid);
    if (bekleyen) {
      if (!await bekleyenKayitSuresiDolmusMu(user.uid)) return false;
    } else if (epostaDogrulamaBekliyorMu(user) || !user.emailVerified) {
      // Pending henüz yazılmadan AuthGate yarışa girebiliyor; taze hesabı silme.
      final created = user.metadata.creationTime;
      if (created == null ||
          DateTime.now().difference(created) < const Duration(minutes: 15)) {
        return false;
      }
      // Eski, pending'siz, doğrulanmamış e-posta oturumu → temizle.
    } else {
      return false;
    }

    await bekleyenKayitIptal();
    return true;
  }

  static Future<void> _authHesabiniSil(User user) async {
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth hesap silme: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('Auth hesap silme (genel): $e');
    }
  }
}
