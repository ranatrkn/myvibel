// @bahsetme önerili metin giriş alanı.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myvibel/app_theme.dart';
import 'package:myvibel/sosyal_servis.dart';
import 'package:myvibel/yas_hesap_kontrol.dart';
import 'package:myvibel/widgets/bahsetme_yardimci.dart';
import 'package:myvibel/widgets/vibe_avatar.dart';
import 'package:myvibel/widgets/web_shell.dart';

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
  final FocusNode? focusNode;

  /// Masaüstü web: Enter gönderir, Shift+Enter alt satır.
  final VoidCallback? enterIleGonder;

  /// Masaüstü web, çok satırlı alan: Enter alt satır, Ctrl/Cmd+Enter gönderir.
  final VoidCallback? ctrlEnterIleGonder;

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
    this.focusNode,
    this.enterIleGonder,
    this.ctrlEnterIleGonder,
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

    if (YasHesapKontrol.maybeOf(context)?.kullaniciOnerisiAcik == false) {
      setState(() {
        _aktifSorgu = null;
        _oneriler = [];
        _oneriYukleniyor = false;
      });
      return;
    }

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
                          userId: (k["uid"] ?? "").toString(),
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
            child: _ctrlEnterSarmala(
              TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                style: widget.style,
                expands: true,
                maxLines: null,
                maxLength: widget.maxLength,
                textAlignVertical: TextAlignVertical.top,
                onChanged: (_) => _metinDegisti(),
                decoration: widget.decoration,
              ),
            ),
          )
        else
          _enterSarmala(
            TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              style: widget.style,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              onChanged: (_) => _metinDegisti(),
              decoration: widget.decoration,
            ),
          ),
      ],
    );
  }

  Widget _ctrlEnterSarmala(Widget alan) {
    final gonder = widget.ctrlEnterIleGonder;
    if (gonder == null || !webMasaustuMu(context)) return alan;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent ||
            (event.logicalKey != LogicalKeyboardKey.enter &&
                event.logicalKey != LogicalKeyboardKey.numpadEnter)) {
          return KeyEventResult.ignored;
        }
        final klavye = HardwareKeyboard.instance;
        if (!klavye.isControlPressed && !klavye.isMetaPressed) {
          return KeyEventResult.ignored;
        }
        gonder();
        return KeyEventResult.handled;
      },
      child: alan,
    );
  }

  Widget _enterSarmala(Widget alan) {
    final gonder = widget.enterIleGonder;
    if (gonder == null || !webMasaustuMu(context)) return alan;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent ||
            (event.logicalKey != LogicalKeyboardKey.enter &&
                event.logicalKey != LogicalKeyboardKey.numpadEnter)) {
          return KeyEventResult.ignored;
        }
        if (HardwareKeyboard.instance.isShiftPressed) {
          // Web textarea Shift+Enter'da çift satır ekleyebiliyor; tek satırı biz ekleriz.
          _satirEkle();
          return KeyEventResult.handled;
        }
        if (oneriSecimiAcik) {
          _kullaniciSec(
            (_oneriler.first["kullaniciAdi"] ?? "kullanici").toString(),
          );
        } else {
          gonder();
        }
        return KeyEventResult.handled;
      },
      child: alan,
    );
  }

  void _satirEkle() {
    final c = widget.controller;
    final metin = c.text;
    final secim = c.selection;
    final bas = secim.isValid ? secim.start : metin.length;
    final son = secim.isValid ? secim.end : metin.length;
    final limit = widget.maxLength;
    if (limit != null && metin.length - (son - bas) + 1 > limit) return;
    c.value = TextEditingValue(
      text: metin.replaceRange(bas, son, '\n'),
      selection: TextSelection.collapsed(offset: bas + 1),
    );
    _metinDegisti();
  }

  bool get oneriSecimiAcik => _aktifSorgu != null && _oneriler.isNotEmpty;
}
