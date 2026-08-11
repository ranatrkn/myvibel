// Gradyan arka planlı ortak sayfa iskeleti.
import 'package:flutter/material.dart';
import 'package:vibe_life/app_theme.dart';

// Vibe temalı gradyan arka planlı Scaffold
class VibeGradientScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final bool extendBodyBehindAppBar;

  const VibeGradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: vibe.gradientDecoration(), // Tema gradyanı
        child: body,
      ),
    );
  }
}
