// Maskot Lottie dosyalarını bellekte önbelleğe alır.
import 'package:lottie/lottie.dart';

class MascotLottieCache {
  MascotLottieCache._();

  static const tumAnimasyonlar = [
    'assets/animations/blue1_5.json',
    'assets/animations/blue6_10.json',
    'assets/animations/blue11_20.json',
    'assets/animations/blue11_20_uyku.json',
    'assets/animations/blue11_20_yorgun.json',
    'assets/animations/blue21.json',
    'assets/animations/blue21_uyku.json',
    'assets/animations/blue21_uzgun.json',
    'assets/animations/blue21_yorgun.json',
  ];

  static final Map<String, Future<LottieComposition>> _compositionlar = {};

  static Future<LottieComposition> yukle(String asset) {
    return _compositionlar.putIfAbsent(
      asset,
      () => AssetLottie(asset).load(),
    );
  }

  static Future<void> onbellegeAl() async {
    await Future.wait(tumAnimasyonlar.map(yukle));
  }
}
