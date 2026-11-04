// Kayıt ve yaş sınırı (beyan; e-Devlet henüz yok).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class YasDogrulama {
  YasDogrulama._();

  static const minimumYas = 15;
  static const tamYetkiYasi = 18;

  static int yasHesapla(DateTime dogumTarihi, [DateTime? referans]) {
    final bugun = referans ?? DateTime.now();
    var yas = bugun.year - dogumTarihi.year;
    if (bugun.month < dogumTarihi.month ||
        (bugun.month == dogumTarihi.month && bugun.day < dogumTarihi.day)) {
      yas--;
    }
    return yas;
  }

  static bool kayitIcinUygunMu(DateTime dogumTarihi) =>
      yasHesapla(dogumTarihi) >= minimumYas;

  /// 15 doldu, 18 dolmadı — kısıtlı çocuk hesabı.
  static bool cocukHesabiMi(DateTime dogumTarihi) {
    final yas = yasHesapla(dogumTarihi);
    return yas >= minimumYas && yas < tamYetkiYasi;
  }

  static bool tamYetkiliMi(DateTime dogumTarihi) =>
      yasHesapla(dogumTarihi) >= tamYetkiYasi;

  static DateTime? timestampten(dynamic raw) {
    if (raw is Timestamp) return sadeceTarih(raw.toDate());
    if (raw is DateTime) return sadeceTarih(raw);
    return null;
  }

  /// DatePicker: en geç seçilebilir doğum günü (tam $minimumYas yaş).
  static DateTime datePickerSonTarih([DateTime? referans]) {
    final bugun = referans ?? DateTime.now();
    return DateTime(bugun.year - minimumYas, bugun.month, bugun.day);
  }

  static DateTime sadeceTarih(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String tarihMetni(DateTime tarih) =>
      '${tarih.day.toString().padLeft(2, '0')}.'
      '${tarih.month.toString().padLeft(2, '0')}.'
      '${tarih.year}';

  static String kayitYasMesaji(String uygulamaAdi) =>
      '$uygulamaAdi yalnızca $minimumYas yaş ve üzeri kullanıcılar içindir.';

  /// Küçük ekranlarda Material input-mode taşmasını önleyen doğum tarihi seçici.
  static Future<DateTime?> dogumTarihiSec(
    BuildContext context, {
    DateTime? baslangic,
  }) async {
    final bugun = DateTime.now();
    final son = datePickerSonTarih(bugun);
    var ilk = baslangic ?? DateTime(bugun.year - 20, bugun.month, bugun.day);
    if (ilk.isAfter(son)) ilk = son;
    if (ilk.isBefore(DateTime(bugun.year - 100))) {
      ilk = DateTime(bugun.year - 100);
    }

    return showDatePicker(
      context: context,
      helpText: 'Doğum Tarihi',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      initialDate: ilk,
      firstDate: DateTime(bugun.year - 100),
      lastDate: son,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.0,
            ),
          ),
          child: child,
        );
      },
    );
  }
}
