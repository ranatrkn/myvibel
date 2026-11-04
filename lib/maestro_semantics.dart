// Maestro ve ekran okuyucu testleri icin tutarli erisim etiketleri.
import 'package:flutter/material.dart';

abstract final class MaestroSemantics {
  static const altMenuAna = 'Alt menü Ana';
  static const altMenuKesfet = 'Alt menü Keşfet';
  static const altMenuYeni = 'Alt menü Yeni gönderi';
  static const altMenuBildirim = 'Alt menü Bildirimler';
  static const altMenuProfil = 'Alt menü Profil';

  static const maskotOdasi = 'Vibel odası';
  static const arkadaslikBaglari = 'Arkadaşlık bağları';
  static const maskotYemekVer = "Vibel'e yemek ver";
  static const retyRengi = 'Vibel rengi';
  static const ayarlar = 'Ayarlar';
  static const arkadaslaraOner = 'Arkadaşlarına öner';
  static const cikisYap = 'Çıkış Yap';
  static const gonderiMenusu = 'Gönderi menüsü';

  static const gonderiMetni = 'Gönderi metni';
  static const paylas = 'Paylaş';
  static const alintiyiPaylas = 'Alıntıyı paylaş';
  static const alintiyiKaldir = 'Alıntıyı kaldır';
  static const gonderiyiBegen = 'Gönderiyi beğen';
  static const begenenleriGoster = 'Beğenenleri göster';
  static const yorumlariAc = 'Yorumları aç';
  static const yorumGonder = 'Yorum gönder';
  static const yorumuYanitla = 'Yorumu yanıtla';
  static const yorumYanitlariniAc = 'Yanıtları göster';
  static const yorumYanitlariniGizle = 'Yanıtları gizle';
  static const yorumuSil = 'Yorumu sil';
  static const yanitiIptal = 'Yanıtı iptal et';
  static const gonderiyiIlet = 'Gönderiyi ilet';
  static const gonderiyiAlintila = 'Gönderiyi alıntıla';
  static const gonderiyiSil = 'Gönderiyi sil';
  static const mesajlar = 'Mesajlar';
  static const mesajGonder = 'Mesaj gönder';
  static const yeniSohbet = 'Yeni sohbet';
  static const liderlikTablosu = 'Liderlik tablosu';
  static const profilDuzenle = 'Profili düzenle';
  static const tumunuOkundu = 'Tümünü okundu işaretle';
  static const takipciSayaci = 'Takipçi listesi';
  static const takipEdilenSayaci = 'Takip edilen listesi';
  static const googleIleGiris = 'Google ile giriş';
  static const appleIleGiris = 'Apple ile giriş';
  static const googleProfilKaydet = 'Google profilini kaydet';
  static const aramayiTemizle = 'Aramayı temizle';
  static const kapat = 'Kapat';
  static const listeGorunumu = 'Liste görünümü';
  static const izgaraGorunumu = 'Izgara görünümü';
  static const temaKoyu = 'Koyu';
  static const temaAcik = 'Açık';
  static String vilBakiyesi(int vil) => 'Vil bakiyesi $vil';
}

/// Maestro'nun tek, sabit bir etiket görmesi için çocuğu gizler.
Widget maestroButton({
  required String label,
  required Widget child,
  bool selected = false,
  VoidCallback? onTap,
}) {
  return Semantics(
    label: label,
    button: true,
    container: true,
    selected: selected,
    onTap: onTap,
    child: ExcludeSemantics(child: child),
  );
}
