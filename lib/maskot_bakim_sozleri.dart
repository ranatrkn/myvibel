// Açlık / uyku cümleleri — bildirim ve Vibel kutusu ortak.
class MaskotBakimSozleri {
  MaskotBakimSozleri._();

  static const toklukEsik = 25;
  static const enerjiEsik = 50;
  static const kutuAralik = Duration(minutes: 1);

  static const aclikYaklasma =
      'Karnım sızlanmaya başladı. Az kaldı, aç kalacağım.';
  static const uykuYaklasma =
      'Gözlerim kapanıyor. Az kaldı, uyumam lazım.';

  static const aclikCumleleri = [
    'Karnım gurulduyor... beni biraz besler misin?',
    'Çok açım. Bir tabak yeter.',
    'Beni unutma. Midem isyan etti.',
    'Hey, buradayım. Ve epey acıktım.',
    'Bir ısırık bile iyi gelir. Lütfen?',
    'Tokluk barım düştü düşecek... yardım!',
    'Çok açım, yanıma gelir misin?',
    'Karnım çok acıktı, unutma beni.',
    'Açlıktan sallanıyorum. Gel artık.',
    'Bana yemek yoksa biraz küserim ha.',
    'Enerjim kaçıyor. Bir öğün kurtarır.',
    'Hâlâ bekliyorum. Sofram boş.',
  ];

  static const uykuCumleleri = [
    'Uykum geldi, yatırmak ister misin?',
    'Çok yoruldum. Biraz uyusam iyi olur.',
    'Gözlerim kapanıyor, unutma beni.',
    'Uyumazsam ayakta duramam.',
    'Yorgunum. Beni yatırır mısın?',
    'Enerjim bitti bitiyor... yardım!',
    'Biraz uyku yeter.',
    'Hâlâ ayaktayım. Uyumak istiyorum.',
    'Gözlerim ağırlaştı. Gel artık.',
    'Uyutmazsan biraz küserim ha.',
    'Çok uykum var, yanıma gelir misin?',
    'Beni uyut lütfen, dayanamıyorum.',
  ];

  /// Kutuda "gel / yanıma gel" olmasın; uygulamadayken garip duruyor.
  static const aclikKutuCumleleri = [
    'Karnım gurulduyor... bir tabak iyi gelir.',
    'Çok açım. Bir tabak yeter.',
    'Midem isyan etti.',
    'Epey acıktım.',
    'Bir ısırık bile yeter.',
    'Tokluk barım düştü düşecek.',
    'Karnım çok acıktı.',
    'Açlıktan sallanıyorum.',
    'Yemek yoksa biraz küserim ha.',
    'Bir öğün kurtarır.',
    'Sofram boş.',
    'Karnım zil çalıyor.',
  ];

  static const uykuKutuCumleleri = [
    'Uykum geldi.',
    'Çok yoruldum. Biraz uyusam iyi olur.',
    'Gözlerim kapanıyor.',
    'Uyumazsam ayakta duramam.',
    'Yorgunum, yatmak istiyorum.',
    'Enerjim bitti bitiyor.',
    'Biraz uyku yeter.',
    'Hâlâ ayaktayım. Uyumak istiyorum.',
    'Gözlerim ağırlaştı.',
    'Uyutmazsan biraz küserim ha.',
    'Çok uykum var.',
    'Dayanamıyorum, uyumam lazım.',
  ];

  static const yumurtaKutuCumleleri = [
    'Paylaştıkça kabuğum çatlar.',
    'Beğenilerin ve yorumların büyümeme yardım eder.',
    'Paylaş, yorum yap, beğen, takip et; hepsi büyümem için.',
    'Birlikte büyüyoruz.',
    'Çerçevem dolunca seviye atlarım.',
    'Az kaldı, yakında kabuğumdan çıkacağım!',
  ];

  static List<String> uyuyorKutuCumleleri(String isim) => [
        'Şşş... $isim uyuyor. Uyanınca daha enerjik olacak.',
        '$isim tatlı rüyalarda. Uyanınca yine birlikteyiz.',
        '$isim dinleniyor. Bu arada akışa göz atabilirsin.',
      ];

  /// Tokluk %26–49: henüz aç değil, uyarı.
  static const acikmayaBasladiKutuCumleleri = [
    'Karnım az az konuşmaya başladı.',
    'Birazdan acıkabilirim.',
    'Tokluğum yavaş yavaş düşüyor.',
    'Şimdilik idare ederim, ama yakında bir tabak iyi gelir.',
    'Midem henüz sakin, biraz daha gider.',
  ];

  /// Tokluk %50+: toklukten bahsetmez, etkileşime ve uygulamayı önermeye çağırır.
  static const tesvikKutuCumleleri = [
    'Bugün akışta neler var, bakalım mı?',
    'Bir gönderi paylaşsan çok sevinirim.',
    'Beğendiğin bir gönderiye yorum bırakır mısın?',
    'Yeni insanlar keşfedelim mi?',
    'Arkadaşlarını MyVibel\'e çağır, birlikte büyüyelim.',
    'Karşılıklı takipleştiğin arkadaşlarının Vibel\'ini besleyebilirsin.',
    'Her etkileşimin beni biraz daha büyütüyor.',
    'Beni arkadaşlarına göstermek ister misin?',
    'Bugün kimi takip etsek?',
    'Bir fotoğraf paylaşmaya ne dersin?',
  ];

  static String toklukKutuNotu(int tokluk) {
    final t = tokluk.clamp(0, 100);
    if (t <= 0) {
      return 'Çok açım! 3 gün böyle kalırsam yumurtaya dönerim.';
    }
    if (t <= toklukEsik) {
      return donen(aclikKutuCumleleri);
    }
    if (t < 50) {
      return donen(acikmayaBasladiKutuCumleleri);
    }
    return donen(tesvikKutuCumleleri);
  }

  static String donen(List<String> liste, {Duration? aralik}) {
    if (liste.isEmpty) return '';
    final ms = (aralik ?? kutuAralik).inMilliseconds;
    final sira = DateTime.now().millisecondsSinceEpoch ~/ ms;
    return liste[sira % liste.length];
  }
}
