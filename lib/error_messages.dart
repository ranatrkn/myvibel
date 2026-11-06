// Hata mesajlarını kullanıcı dostu Türkçe metne çevirir.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

bool _teknikIngilizceMesaj(String metin) {
  final t = metin.toLowerCase();
  const ipuclari = [
    'permission',
    'the caller',
    'cloud_firestore',
    'firebase',
    '[firestore]',
    'app check',
    'app-check',
    'missing or insufficient',
    'unavailable',
    'deadline-exceeded',
    'network-request-failed',
    'socketexception',
    'failed host lookup',
    'client is offline',
  ];
  return ipuclari.any(t.contains);
}

/// Firebase Auth'un ham İngilizce mesajları (ör. "The supplied auth credential
/// is incorrect...") kullanıcıya gösterilmez; uygulamanın kendi Türkçe
/// mesajları geçer.
bool _ingilizceAuthMesaji(String metin) => RegExp(
  r'\b(the|is|has|an|invalid|incorrect|expired|malformed|password|user|email)\b',
  caseSensitive: false,
).hasMatch(metin);

String _izinMesaji(String fallback) {
  // Genel “kullanıcı adını değiştir” gibi yanıltıcı fallback’leri ezme.
  final f = fallback.trim();
  if (f.isNotEmpty &&
      f != 'İşlem başarısız.' &&
      !f.toLowerCase().contains('kullanıcı adını değiştir') &&
      !_teknikIngilizceMesaj(f)) {
    return f;
  }
  return 'Bu işlem için iznin yok veya vil/puan kuralı uymadı.';
}

bool _gercekAgHatasi(String text) {
  const ipuclari = [
    'network-request-failed',
    'socketexception',
    'failed host lookup',
    'client is offline',
    'failed to get document because the client is offline',
    'network error',
    'connection error',
    'connection refused',
    'connection reset',
  ];
  return ipuclari.any(text.contains);
}

const internetYokUyari = 'İnternet yok.';

String _sunucuBaglantiMesaji() =>
    'Sunucuya bağlanılamadı. Sayfayı yenile (Ctrl+F5) ve tekrar dene.';

bool internetYokGibi(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('sunucuya bağlanılamadı')) return false;
  const kesin = [
    'network-request-failed',
    'socketexception',
    'failed host lookup',
    'network is unreachable',
    'failed to fetch',
    'err_internet_disconnected',
    'err_name_not_resolved',
    'networkerror',
    'xmlhttprequest error',
    'connection refused',
    'connection reset',
    'network error',
    'connection error',
  ];
  if (kesin.any(text.contains)) return true;
  if (kIsWeb) return false;
  return text.contains('client is offline') ||
      text.contains('unavailable') ||
      text.contains('the client is offline');
}

/// İnternet kesikse kısa uyarı, değilse sunucu metni.
String baglantiUyariMesaji(Object error) {
  if (internetYokGibi(error)) return internetYokUyari;
  return _sunucuBaglantiMesaji();
}

// Hatayı analiz edip anlaşılır mesaj döndürür
String internetAwareErrorMessage({
  required Object error,
  String fallback = 'İşlem başarısız.',
}) {
  if (error is String && error.trim().isNotEmpty) {
    final metin = error.trim();
    final lower = metin.toLowerCase();
    if (_gercekAgHatasi(lower) ||
        lower.contains('unavailable') ||
        lower.contains('deadline-exceeded') ||
        lower.contains('timed out') ||
        lower.contains('timeout')) {
      return baglantiUyariMesaji(error);
    }
    if (lower.contains('app-check') || lower.contains('app check')) {
      return 'Güvenlik doğrulaması başarısız. Sayfayı yenile veya daha sonra dene.';
    }
    if (lower.contains('permission')) {
      return _izinMesaji(fallback);
    }
    if (_teknikIngilizceMesaj(metin)) {
      return fallback;
    }
    return metin;
  }

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'network-request-failed':
        return baglantiUyariMesaji(error);
      case 'too-many-requests':
        return 'Çok fazla deneme. Biraz sonra tekrar dene.';
      case 'user-disabled':
        return 'Bu hesap devre dışı.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        final mesaj = error.message?.trim() ?? '';
        return mesaj.isNotEmpty && !_ingilizceAuthMesaji(mesaj)
            ? mesaj
            : 'Giriş bilgileri hatalı.';
      default:
        if (error.code.contains('app-check')) {
          return 'Güvenlik doğrulaması başarısız. Sayfayı yenile veya daha sonra dene.';
        }
        break;
    }
  }

  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      return _izinMesaji(fallback);
    }
    if (error.code == 'unavailable' ||
        error.code == 'deadline-exceeded' ||
        (error.message?.toLowerCase().contains('offline') ?? false)) {
      return baglantiUyariMesaji(error);
    }
    if (error.code.contains('app-check') ||
        (error.message?.toLowerCase().contains('app check') ?? false) ||
        (error.message?.toLowerCase().contains('app-check') ?? false)) {
      return 'Güvenlik doğrulaması başarısız. Sayfayı yenile veya daha sonra dene.';
    }
    final detay = error.message?.trim();
    if (detay != null &&
        detay.isNotEmpty &&
        !_teknikIngilizceMesaj(detay)) {
      return detay;
    }
  }

  final text = error.toString().toLowerCase();
  if (_gercekAgHatasi(text) ||
      text.contains('unavailable') ||
      text.contains('deadline-exceeded') ||
      text.contains('timed out') ||
      text.contains('timeout')) {
    return _sunucuBaglantiMesaji();
  }
  if (text.contains('app-check') || text.contains('app check')) {
    return 'Güvenlik doğrulaması başarısız. Sayfayı yenile veya daha sonra dene.';
  }
  if (_teknikIngilizceMesaj(error.toString())) {
    if (text.contains('permission')) return _izinMesaji(fallback);
    return fallback;
  }
  return fallback;
}
