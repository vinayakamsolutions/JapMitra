import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/jap_repository.dart';
import '../../main.dart';
import '../astrologer/astrologer_model.dart';
import '../astrologer/astrologer_profile_screen.dart';
import '../jap/jap_screen.dart';
import '../numerology/numerology_screen.dart';
import '../panchang/panchang_screen.dart';
import '../rashifal/screens/rashifal_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext c) {
    final s = InheritedAppState.of(c);
    final l = AppLocalizations.of(c);
    final now = DateTime.now();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _greetingHeader(c, l, s, now),
            const SizedBox(height: 20),
            _heroDevotionalCard(c),
            const SizedBox(height: 20),
            _todaysJapCard(c, l, s),
            const SizedBox(height: 20),
            _featureGrid(c, l, s),
            const SizedBox(height: 20),
            _astrologerCard(c),
            const SizedBox(height: 20),
            _inspirationCard(c, l),
          ],
        ),
      ),
    );
  }

  Widget _greetingHeader(
      BuildContext c, AppLocalizations l, AppState s, DateTime now) {
    final hour = now.hour;
    final greeting = hour < 12
        ? 'सुप्रभात'
        : hour < 17
            ? 'नमस्कार'
            : 'शुभ संध्या';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: Theme.of(c).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.brown,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${now.day}/${now.month}/${now.year} • ${s.city}',
                style: Theme.of(c).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.brownSoft,
                    ),
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.saffron.withValues(alpha: 0.10),
            border: Border.fromBorderSide(AppTheme.hairline(0.30)),
          ),
          child: const Icon(Icons.wb_twilight, color: AppTheme.saffron),
        ),
      ],
    );
  }

  Widget _heroDevotionalCard(BuildContext c) {
    return Container(
      constraints: const BoxConstraints(minHeight: 160),
      decoration: BoxDecoration(
        borderRadius: AppTheme.cardRadius,
        color: AppTheme.cream,
        border: Border.fromBorderSide(AppTheme.hairline(0.34)),
        boxShadow: AppTheme.shadow,
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -16,
            bottom: -28,
            child: Text(
              'ॐ',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: 140,
                height: 1,
                color: Color(0x14C59B3F),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.fromBorderSide(AppTheme.hairline(0.40)),
                  ),
                  child: const Text(
                    'ॐ',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 26,
                      color: AppTheme.saffron,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'शिवाय',
                  style: Theme.of(c).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.brown,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Har Har Mahadev',
                  style: Theme.of(c).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.gold,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _todaysJapCard(BuildContext c, AppLocalizations l, AppState s) {
    return FutureBuilder<int>(
      future: JapRepository()
          .todayCountForMantra(s.selectedMantra)
          .catchError((_) => 0),
      builder: (c, snap) {
        final count = snap.data ?? 0;
        final progress =
            s.dailyGoal > 0 ? (count / s.dailyGoal).clamp(0.0, 1.0) : 0.0;
        return Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: AppTheme.cardRadius,
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => const JapScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppTheme.saffron.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(15),
                          border:
                              Border.fromBorderSide(AppTheme.hairline(0.28)),
                        ),
                        child: const Icon(Icons.spa, color: AppTheme.saffron),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.t('todayJap'),
                              style:
                                  Theme.of(c).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.brown,
                                      ),
                            ),
                            Text(
                              s.selectedMantra,
                              style: Theme.of(c).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.brownSoft,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '$count / ${s.dailyGoal}',
                          textAlign: TextAlign.end,
                          style: Theme.of(c).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.saffron,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // A thin bar reads as progress; a floating ring reads as a
                  // dial. Progress is what this number means.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      color: AppTheme.saffron,
                      backgroundColor: AppTheme.gold.withValues(alpha: 0.18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 16, color: AppTheme.gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${count ~/ 108} ${l.t('mala')} • ${count % 108}/108',
                          style: Theme.of(c).textTheme.bodySmall?.copyWith(
                                color: AppTheme.brownSoft,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _featureGrid(BuildContext c, AppLocalizations l, AppState s) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _featureCard(
          c,
          icon: Icons.spa,
          title: l.t('jap'),
          color: AppTheme.saffron,
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const JapScreen()),
          ),
        ),
        _featureCard(
          c,
          icon: Icons.calendar_month,
          title: l.t('panchang'),
          color: AppTheme.gold,
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const PanchangScreen()),
          ),
        ),
        _featureCard(
          c,
          icon: Icons.auto_awesome,
          title: l.t('rashifal'),
          color: AppTheme.saffron,
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const RashifalScreen()),
          ),
        ),
        _featureCard(
          c,
          icon: Icons.numbers,
          title: l.t('numerology'),
          color: AppTheme.brownSoft,
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(builder: (_) => const NumerologyScreen()),
          ),
        ),
      ],
    );
  }

  Widget _featureCard(
    BuildContext c, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: AppTheme.cardRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.center,
            runSpacing: 12,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.fromBorderSide(AppTheme.hairline(0.26)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              Text(
                title,
                style: Theme.of(c).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.brown,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _astrologerCard(BuildContext c) {
    const profile = featuredAstrologer;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: AppTheme.cardRadius,
        onTap: () => Navigator.push(
          c,
          MaterialPageRoute(builder: (_) => const AstrologerProfileScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.goldSoft,
                      border: Border.fromBorderSide(AppTheme.hairline(0.34)),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        profile.photoAsset!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            profile.monogram,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.brown,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Acharya ${profile.name}',
                          style: Theme.of(c).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.brown,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          profile.experience,
                          style: Theme.of(c).textTheme.bodySmall?.copyWith(
                                color: AppTheme.brownSoft,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in profile.specialities)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.goldSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.brownSoft,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // A Wrap, not a Row: at a large system font on a 320pt screen
              // the price and the button genuinely cannot share one line, and
              // the button should drop below rather than be clipped.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '₹${profile.fee}',
                        style: Theme.of(c).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.saffron,
                            ),
                      ),
                      Text(
                        '• ${profile.consultationMinutes} min',
                        style: Theme.of(c).textTheme.bodySmall?.copyWith(
                              color: AppTheme.brownSoft,
                            ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppTheme.saffron,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.call, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Consult',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inspirationCard(BuildContext c, AppLocalizations l) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.goldSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.format_quote,
                      size: 18, color: AppTheme.gold),
                ),
                const SizedBox(width: 10),
                Text(
                  l.t('inspiration'),
                  style: Theme.of(c).textTheme.labelSmall?.copyWith(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              l.t('quoteDaily'),
              style: Theme.of(c).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.brownSoft,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
