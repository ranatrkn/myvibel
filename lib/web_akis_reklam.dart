// package:web SDK 3.4+; Flutter web derlemesi onu sağlar, pubspec 3.3 kısıtı eklenemez.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

const _istemci = 'ca-pub-4786108844945952';
const _slot = '4142900267';
const _yerlesim = '-gw-3+1f-3d+2z';
const _yerlesimYukseklik = 280.0;

final _fabrikalar = <String>{};
final _kutular = <String, web.HTMLDivElement>{};
Future<void>? _script;

Widget akisReklamGorunumu(String slot) {
  return _AkisReklam(slot: slot);
}

class _AkisReklam extends StatefulWidget {
  const _AkisReklam({required this.slot});

  final String slot;

  @override
  State<_AkisReklam> createState() => _AkisReklamState();
}

class _AkisReklamState extends State<_AkisReklam> {
  var _hazir = false;
  var _yukseklik = 0.0;
  Timer? _olcum;

  String get _tur => 'akis-reklam-${widget.slot}';

  @override
  void initState() {
    super.initState();
    unawaited(_hazirla());
  }

  @override
  void dispose() {
    _olcum?.cancel();
    super.dispose();
  }

  Future<void> _hazirla() async {
    await _scriptYukle();
    if (!mounted) return;
    setState(() => _hazir = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reklamiIt();
      _olcumeBasla();
    });
  }

  void _olcumeBasla() {
    _olcum?.cancel();
    var kalan = 40;
    _olcum = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      kalan--;
      final doldu = _olc();
      if (doldu || kalan <= 0 || !mounted) {
        timer.cancel();
      }
    });
  }

  bool _olc() {
    final kutu = _kutular[_tur];
    if (kutu == null) return false;
    var h = 0.0;
    final iframe = kutu.querySelector('iframe');
    if (iframe != null) {
      final el = iframe as web.HTMLElement;
      h = el.getBoundingClientRect().height.toDouble();
      if (h < 8) h = el.offsetHeight.toDouble();
    }
    if (h < 8) {
      h = kutu.getBoundingClientRect().height.toDouble();
    }
    if (h < 40) return false;
    final hedef = h.clamp(80.0, 400.0);
    if ((hedef - _yukseklik).abs() < 2) return true;
    if (!mounted) return true;
    setState(() => _yukseklik = hedef);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hazir) return const SizedBox.shrink();
    _fabrikaKaydet(_tur);
    final acik = _yukseklik > 0;
    return ClipRect(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: acik ? _yukseklik + 20 : 0,
        width: double.infinity,
        margin: acik
            ? const EdgeInsets.symmetric(horizontal: 15, vertical: 10)
            : EdgeInsets.zero,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: _yerlesimYukseklik,
          maxHeight: 400,
          child: HtmlElementView(viewType: _tur),
        ),
      ),
    );
  }
}

void _fabrikaKaydet(String tur) {
  if (!_fabrikalar.add(tur)) return;
  ui_web.platformViewRegistry.registerViewFactory(tur, (int id) {
    final kutu = web.HTMLDivElement();
    kutu.style.width = '100%';
    kutu.style.minHeight = '${_yerlesimYukseklik.toInt()}px';
    final ins = web.document.createElement('ins');
    ins.setAttribute('class', 'adsbygoogle');
    ins.setAttribute('style', 'display:block');
    ins.setAttribute('data-ad-format', 'fluid');
    ins.setAttribute('data-ad-layout-key', _yerlesim);
    ins.setAttribute('data-ad-client', _istemci);
    ins.setAttribute('data-ad-slot', _slot);
    kutu.appendChild(ins);
    _kutular[tur] = kutu;
    return kutu;
  });
}

Future<void> _scriptYukle() {
  return _script ??= () async {
    if (web.document.querySelector('script[src*="adsbygoogle.js"]') != null) {
      return;
    }
    final script = web.HTMLScriptElement()
      ..async = true
      ..crossOrigin = 'anonymous'
      ..src =
          'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$_istemci';
    web.document.head?.appendChild(script);
    await script.onLoad.first;
  }();
}

void _reklamiIt() {
  final pencere = web.window as JSObject;
  final mevcut = pencere.getProperty<JSAny?>('adsbygoogle'.toJS);
  final JSArray<JSAny?> dizi;
  if (mevcut == null || mevcut.isUndefinedOrNull) {
    dizi = JSArray<JSAny?>();
    pencere.setProperty('adsbygoogle'.toJS, dizi);
  } else {
    dizi = mevcut as JSArray<JSAny?>;
  }
  dizi.callMethod('push'.toJS, JSObject());
}
