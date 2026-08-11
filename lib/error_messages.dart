// Hata mesajlarını kullanıcı dostu Türkçe metne çevirir.
import 'package:cloud_firestore/cloud_firestore.dart';

// Hatayı analiz edip anlaşılır mesaj döndürür
String internetAwareErrorMessage({
  required Object error,
  String fallback = "İşlem başarısız.",
}) {
  if (error is String && error.trim().isNotEmpty) {
    return error.trim(); // Zaten metin ise doğrudan kullan
  }

  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      final detay = error.message?.trim();
      if (detay != null && detay.isNotEmpty) {
        return 'İşlem reddedildi: $detay';
      }
      return 'İşlem reddedildi. Firebase App Check veya güvenlik kuralları '
          'engelledi. Console\'da debug token ve Firestore ayarlarını kontrol edin.';
    }
    if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
      return 'internet bağlantısı yok';
    }
    if (error.message != null && error.message!.trim().isNotEmpty) {
      return error.message!.trim();
    }
  }

  final text = error.toString().toLowerCase();
  const internetHints = [
    "network-request-failed",
    "socketexception",
    "failed host lookup",
    "timed out",
    "timeout",
    "deadline-exceeded",
    "unavailable",
    "network error",
    "connection error",
  ];

  final isInternetError = internetHints.any(text.contains);
  if (isInternetError) return "internet bağlantısı yok";
  return fallback;
}
