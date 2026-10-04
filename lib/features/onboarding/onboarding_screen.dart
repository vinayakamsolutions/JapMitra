import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../main.dart';
import '../home/shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController pageController = PageController();
  final TextEditingController cityController = TextEditingController();

  int page = 0;

  @override
  void dispose() {
    pageController.dispose();
    cityController.dispose();
    super.dispose();
  }

  Future<void> next() async {
    if (page < 2) {
      setState(() => page++);

      await pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> finish() async {
    final state = InheritedAppState.of(context);

    await state.setCity(cityController.text.trim());
    await state.doneOnboarding();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const Shell(),
      ),
    );
  }

  Future<void> changeLanguage(String? value) async {
    if (value == null) return;

    final state = InheritedAppState.of(context);

    await state.setLang(value);

    if (!mounted) return;

    JapMitraApp.of(context).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButton<String>(
                  value: InheritedAppState.of(context).languageCode,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: 'hi',
                      child: Text('हिन्दी'),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Text('English'),
                    ),
                  ],
                  onChanged: changeLanguage,
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _OnboardingPage(
                    icon: Icons.spa,
                    title: l.t('app'),
                    description: l.t('tag'),
                  ),
                  _OnboardingPage(
                    icon: Icons.favorite,
                    title: l.t('doJap'),
                    description: l.t('todayJap'),
                  ),
                  _OnboardingPage(
                    icon: Icons.location_city,
                    title: l.t('city'),
                    description: l.t('tag'),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: TextField(
                        controller: cityController,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: l.t('city'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).cardTheme.color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Row(
                children: [
                  if (page < 2)
                    TextButton(
                      onPressed: finish,
                      child: Text(l.t('skip')),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  FilledButton(
                    onPressed: page < 2 ? next : finish,
                    child: Text(
                      page < 2 ? l.t('next') : l.t('getStarted'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFE87822).withValues(alpha: 0.2),
                  const Color(0xFFD8A94A).withValues(alpha: 0.2),
                ],
              ),
            ),
            child: Icon(
              icon,
              size: 56,
              color: const Color(0xFFE87822),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3E2415),
                ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF8A6A3A),
                  height: 1.5,
                ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}
