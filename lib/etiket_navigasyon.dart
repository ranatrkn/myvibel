// Hashtag tıklamalarında etiket sayfasına yönlendirme.
import 'package:myvibel/tek_sefer_navigasyon.dart';
import 'package:flutter/material.dart';
import 'package:myvibel/etiket_sayfasi.dart';
import 'package:myvibel/sosyal_servis.dart';

// Etiketi normalize edip ilgili sayfaya gider
void etiketSayfasinaGit(BuildContext context, String hamEtiket) {
  final tag = SosyalServis.etiketNormalize(hamEtiket);
  if (tag.isEmpty) return;

  tekSeferPush(
    context,
    MaterialPageRoute(
      builder: (_) => EtiketSayfasi(etiket: tag),
    ),
  );
}
