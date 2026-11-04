// Vil harcayan işlemler için tek seferlik uyarı.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/maskot_servis.dart';

class VilHarcamaUyarisi {
  static const takipCik = 'takip_cik';
  static const begeniGeriAl = 'begeni_gerial';
  static const yorumSil = 'yorum_sil';
  static const gonderiSil = 'gonderi_sil';
  static const yemek = 'yemek';
  static const arkadasYemek = 'arkadas_yemek';

  static const _anahtarOnEk = 'vil_uyari_gizle_v1_';
  static final Map<String, bool> _gizli = {};

  /// Uyarıyı gösterir. `true` = işleme devam, `false` = vazgeç.
  /// Tamam: harcar. Kutucuk işaretliyse bir daha bu işlemde uyarmaz.
  /// Vazgeç / dışarı tık / geri: harcamaz.
  static Future<bool> onayla({
    required BuildContext context,
    required String islem,
    required int maliyet,
    bool? vilHarcanacak,
  }) async {
    if (maliyet <= 0) return true;
    final harcanacak =
        vilHarcanacak ?? await MascotServis.mevcutKullaniciVilCuzdaniAcik();
    if (!harcanacak) return true;
    if (_gizli[islem] == true) return true;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('$_anahtarOnEk$islem') == true) {
      _gizli[islem] = true;
      return true;
    }
    if (!context.mounted) return false;

    final sonuc = await showDialog<({bool devam, bool gizle})>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        var tekrarGosterme = false;
        final vibe = dialogContext.vibe;
        final theme = Theme.of(dialogContext);
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: vibe.dialogBackground,
              title: Text(
                'Vil harcaması',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bu işlemi yapmak $maliyet vil harcar.',
                    style: TextStyle(color: vibe.mutedText, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: tekrarGosterme,
                    onChanged: (v) {
                      setDialogState(() => tekrarGosterme = v ?? false);
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Tekrar gösterme',
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Vazgeç'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    (devam: true, gizle: tekrarGosterme),
                  ),
                  child: const Text('Tamam'),
                ),
              ],
            );
          },
        );
      },
    );

    if (sonuc == null || !sonuc.devam) return false;
    if (sonuc.gizle) {
      _gizli[islem] = true;
      await prefs.setBool('$_anahtarOnEk$islem', true);
    }
    return true;
  }
}
