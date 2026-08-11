// Hashtag tıklamalarında etiket sayfasına yönlendirme.
import 'package:flutter/material.dart';
import 'package:vibe_life/etiket_sayfasi.dart';
import 'package:vibe_life/sosyal_servis.dart';

// Etiketi normalize edip ilgili sayfaya gider
void etiketSayfasinaGit(BuildContext context, String hamEtiket) {
  final tag = SosyalServis.etiketNormalize(hamEtiket);
  if (tag.isEmpty) return;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EtiketSayfasi(etiket: tag),
    ),
  );
}
