import 'package:flutter/material.dart';
import '../../main.dart';
import '../../core/localization/app_localizations.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _S();
}

class _S extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final s = InheritedAppState.of(context);
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  s.onboardingDone ? const Shell() : const OnboardingScreen()));
    });
  }

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: 140,
                height: 140,
                child: Image(
                    image: AssetImage('assets/branding/japmitra_logo.png'))),
            const SizedBox(height: 16),
            Text(l.t('app'),
                style: Theme.of(c)
                    .textTheme
                    .headlineLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(l.t('tag')),
            const SizedBox(height: 24),
            Text(l.t('made'), style: Theme.of(c).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
