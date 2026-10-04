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
    Future.delayed(const Duration(milliseconds: 900), () {
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8ED), Color(0xFFFFF0D8)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE87822).withValues(alpha: 0.2),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const ClipOval(
                  child: Image(
                    image: AssetImage('assets/branding/japmitra_logo.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l.t('app'),
                style: Theme.of(c).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3E2415)),
              ),
              const SizedBox(height: 8),
              Text(
                l.t('tag'),
                style: Theme.of(c)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: const Color(0xFF8A6A3A)),
              ),
              const SizedBox(height: 32),
              Text(
                l.t('made'),
                style: Theme.of(c)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: const Color(0xFFB08040)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
