// Küfür ve cinsel içerik filtresi (gönderi, yorum, mesaj).
class IcerikFiltreServis {
  IcerikFiltreServis._();

  static const uygunsuzMetinHata =
      'Bu metin küfür veya uygunsuz ifadeler içeriyor. Lütfen düzenleyip tekrar dene.';

  static final RegExp _ayirici = RegExp(r'[^a-z0-9]+', caseSensitive: false);

  /// Tam kelime eşleşmesi (kısa kökler; yanlış pozitif riski düşük tutuldu).
  static const _tamKelimeKokler = <String>{
    'amk',
    'amq',
    'aq',
    'sik',
    'pic',
    'ibne',
    'oc',
    'got',
    'bok',
    'yarak',
    'orospu',
    'kahpe',
    'porn',
    'seks',
    'sex',
    'nude',
    'fuck',
    'shit',
    'dick',
    'cock',
    'pussy',
    'bitch',
    'horny',
  };

  /// Boşluksuz metinde aranan ifadeler (4+ karakter, hileli yazımlar).
  static const _icermeIfadeler = <String>{
    'amina',
    'amcik',
    'siker',
    'siktir',
    'sikik',
    'sikimsonik',
    'sikis',
    'sikisme',
    'orospucocugu',
    'pezevenk',
    'yarrak',
    'tasak',
    'dalyarak',
    'malafat',
    'ananisikerim',
    'ananisikim',
    'serefsiz',
    'porno',
    'pornografi',
    'masturb',
    'masturbasyon',
    'penis',
    'vajina',
    'klitoris',
    'nudes',
    'ciplak',
    'escort',
    'sext',
    'orgazm',
    'orgasm',
    'fucking',
    'cumshot',
    'blowjob',
    'handjob',
    'dildo',
    'vibrator',
    'gangbang',
    'fetish',
  };

  /// Metin uygunsuz ifade içeriyorsa `true`.
  static bool uygunsuzMu(String metin) {
    final ham = metin.trim();
    if (ham.isEmpty) return false;

    final birlestirilmis = _normalize(ham);
    if (_icermeIfadeler.any(birlestirilmis.contains)) return true;

    for (final parca in ham.split(_ayirici)) {
      final token = _normalize(parca);
      if (token.isEmpty) continue;
      if (_tamKelimeKokler.contains(token)) return true;
    }
    return false;
  }

  /// Uygunsuz metinde standart hata fırlatır.
  static void uygunsuzsaAt(String metin) {
    if (uygunsuzMu(metin)) throw uygunsuzMetinHata;
  }

  static String _normalize(String input) {
    var s = input.toLowerCase();
    const trMap = {
      'ı': 'i',
      'ğ': 'g',
      'ü': 'u',
      'ş': 's',
      'ö': 'o',
      'ç': 'c',
      'İ': 'i',
      'Ğ': 'g',
      'Ü': 'u',
      'Ş': 's',
      'Ö': 'o',
      'Ç': 'c',
    };
    for (final entry in trMap.entries) {
      s = s.replaceAll(entry.key, entry.value);
    }

    s = s
        .replaceAll('@', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('7', 't');

    s = s.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return s.replaceAllMapped(
      RegExp(r'(.)\1+'),
      (match) => match.group(1)!,
    );
  }
}
