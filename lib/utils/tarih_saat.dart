// Firestore Timestamp değerlerini okunabilir tarih metnine çevirir
import 'package:cloud_firestore/cloud_firestore.dart';

// Timestamp'i gg.aa.yyyy ss:dd formatına dönüştürür
String tarihSaatYaz(dynamic value) {
  if (value is! Timestamp) return "Tarih yok"; // Geçersiz değer kontrolü

  final tarih = value.toDate(); // DateTime'a çevir
  final gun = tarih.day.toString().padLeft(2, "0");
  final ay = tarih.month.toString().padLeft(2, "0");
  final yil = tarih.year.toString();
  final saat = tarih.hour.toString().padLeft(2, "0");
  final dakika = tarih.minute.toString().padLeft(2, "0");

  return "$gun.$ay.$yil $saat:$dakika";
}
