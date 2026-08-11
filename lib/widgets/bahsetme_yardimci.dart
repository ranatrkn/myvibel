// @bahsetme metin alanı yardımcı fonksiyonları.
import 'package:flutter/material.dart';

// Aktif @ sorgusu bilgisi
class BahsetmeSorgusu {
  final int baslangic; // @ karakterinin konumu
  final String onEk; // @ sonrası yazılan metin

  const BahsetmeSorgusu({
    required this.baslangic,
    required this.onEk,
  });
}

// İmleç konumundaki @ sorgusunu bulur
BahsetmeSorgusu? aktifBahsetmeSorgusu(String metin, int imlec) {
  if (imlec < 0 || imlec > metin.length) return null;

  final sol = metin.substring(0, imlec);
  final atIndex = sol.lastIndexOf("@");
  if (atIndex < 0) return null;

  // Önceki karakter kelime içindeyse geçersiz
  if (atIndex > 0) {
    final onceki = sol[atIndex - 1];
    if (RegExp(r'[a-zA-Z0-9_\.]').hasMatch(onceki)) {
      return null;
    }
  }

  final onEk = sol.substring(atIndex + 1);
  if (onEk.contains(" ") || onEk.contains("\n")) return null;
  if (onEk.length > 30) return null;

  return BahsetmeSorgusu(baslangic: atIndex, onEk: onEk);
}

// Seçilen kullanıcı adını metne ekler
void bahsetmeEkle(
  TextEditingController controller,
  int imlec,
  String kullaniciAdi,
) {
  final metin = controller.text;
  final sorgu = aktifBahsetmeSorgusu(metin, imlec);
  if (sorgu == null) return;

  final yeniMetin =
      "${metin.substring(0, sorgu.baslangic)}@$kullaniciAdi ${metin.substring(imlec)}";
  final yeniImlec = sorgu.baslangic + kullaniciAdi.length + 2;

  controller.value = TextEditingValue(
    text: yeniMetin,
    selection: TextSelection.collapsed(offset: yeniImlec),
  );
}
