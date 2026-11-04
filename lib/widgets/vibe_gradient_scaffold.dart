// Gradyan arka planlı ortak sayfa iskeleti.
import 'package:flutter/material.dart';
import 'package:myvibel/app_theme.dart';

/// Altındaki [VibeGradientScaffold]'lar kendi gradyanını çizmez; arka planı
/// üst katman boyar (ör. masaüstü giriş sağ paneli, dar form kutusunda şerit olmasın).
class VibeGradyanKapali extends InheritedWidget {
  const VibeGradyanKapali({super.key, required super.child});

  static bool kapaliMi(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VibeGradyanKapali>() != null;

  @override
  bool updateShouldNotify(VibeGradyanKapali oldWidget) => false;
}

// Vibe temalı gradyan arka planlı Scaffold
class VibeGradientScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;

  const VibeGradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
  });

  static AppBar seffafBaslik(
    String baslik, {
    Widget? title,
    TextStyle? titleStyle,
    List<Widget>? actions,
    Widget? leading,
    bool? centerTitle,
  }) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
      title: title ??
          Text(
            baslik,
            style: titleStyle ??
                const TextStyle(
                  fontFamily: VibeAppTheme.fontFamily,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final mediaQuery = MediaQuery.of(context);
    // AppBar.bottom (TabBar vb.) dahil gerçek yükseklik.
    final barYukseklik = appBar?.preferredSize.height ?? 0;
    final ustBosluk = appBar != null
        ? mediaQuery.padding.top + barYukseklik
        : 0.0;

    Widget icerik = body;
    if (appBar != null) {
      icerik = MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Padding(
          padding: EdgeInsets.only(top: ustBosluk),
          child: body,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: appBar != null,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: VibeGradyanKapali.kapaliMi(context)
            ? null
            : vibe.gradientDecoration(),
        child: icerik,
      ),
    );
  }
}
