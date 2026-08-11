// @bahsetme önerili metin giriş alanı.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/sosyal_servis.dart';
import 'package:vibe_life/widgets/bahsetme_yardimci.dart';
import 'package:vibe_life/widgets/vibe_avatar.dart';

// @ yazınca kullanıcı önerisi gösteren TextField
class BahsetmeMetinAlani extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final TextStyle? style;
  final int? maxLines;
  final int? maxLength;
  final bool expands;
  final String? haricUid;
  final ValueChanged<String>? onChanged;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;

  const BahsetmeMetinAlani({
    super.key,
    required this.controller,
    required this.decoration,
    this.style,
    this.maxLines,
    this.maxLength,
    this.expands = false,
    this.haricUid,
    this.onChanged,
    this.keyboardDismissBehavior,
  });

  @override
  State<BahsetmeMetinAlani> createState() => _BahsetmeMetinAlaniState();
}

class _BahsetmeMetinAlaniState extends State<BahsetmeMetinAlani> {
  List<Map<String, dynamic>> _oneriler = []; // Kullanıcı öneri listesi
  bool _oneriYukleniyor = false;
  BahsetmeSorgusu? _aktifSorgu; // Aktif @ sorgusu
  Timer? _debounce; // Yazma gecikmesi

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_metinDegisti);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_metinDegisti);
    super.dispose();
  }

  // Metin değişince öneri sorgusunu günceller
  void _metinDegisti() {
    widget.onChanged?.call(widget.controller.text);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _sorguyuGuncelle);
  }

  // Firestore'dan kullanıcı önerilerini getirir
  Future<void> _sorguyuGuncelle() async {
    final sorgu = aktifBahsetmeSorgusu(
      widget.controller.text,
      widget.controller.selection.baseOffset,
    );

    if (!mounted) return;

    if (sorgu == null || sorgu.onEk.isEmpty) {
      setState(() {
        _aktifSorgu = null;
        _oneriler = [];
        _oneriYukleniyor = false;
      });
      return;
    }

    setState(() {
      _aktifSorgu = sorgu;
      _oneriYukleniyor = true;
    });

    try {
      final liste = await SosyalServis.kullaniciOnerileri(
        sorgu.onEk,
        haricUid: widget.haricUid,
      );
      if (!mounted) return;
      setState(() {
        _oneriler = liste;
        _oneriYukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _oneriler = [];
        _oneriYukleniyor = false;
      });
    }
  }

  // Öneriden seçilen kullanıcıyı metne ekler
  void _kullaniciSec(String kullaniciAdi) {
    bahsetmeEkle(
      widget.controller,
      widget.controller.selection.baseOffset,
      kullaniciAdi,
    );
    setState(() {
      _aktifSorgu = null;
      _oneriler = [];
    });
    widget.onChanged?.call(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;
    final oneriGoster =
        _aktifSorgu != null && (_oneriYukleniyor || _oneriler.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (oneriGoster)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: vibe.cardDecoration(radius: 14),
            child: _oneriYukleniyor && _oneriler.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _oneriler.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: vibe.cardBorder,
                    ),
                    itemBuilder: (context, index) {
                      final k = _oneriler[index];
                      final adSoyad =
                          (k["adSoyad"] ?? "Vibe Kullanıcısı").toString();
                      final kullaniciAdi =
                          (k["kullaniciAdi"] ?? "kullanici").toString();
                      return ListTile(
                        dense: true,
                        leading: vibeAvatar(
                          radius: 18,
                          photoUrl: (k["photoUrl"] ?? "").toString(),
                          avatarKey: (k["avatarKey"] ?? "").toString(),
                          fallbackText: adSoyad,
                          emojiSize: 16,
                          fallbackIconSize: 18,
                        ),
                        title: Text(
                          adSoyad,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          "@$kullaniciAdi",
                          style: const TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () => _kullaniciSec(kullaniciAdi),
                      );
                    },
                  ),
          ),
        if (widget.expands)
          Expanded(
            child: TextField(
              controller: widget.controller,
              style: widget.style,
              expands: true,
              maxLines: null,
              maxLength: widget.maxLength,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (_) => _metinDegisti(),
              decoration: widget.decoration,
            ),
          )
        else
          TextField(
            controller: widget.controller,
            style: widget.style,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            onChanged: (_) => _metinDegisti(),
            decoration: widget.decoration,
          ),
      ],
    );
  }
}
