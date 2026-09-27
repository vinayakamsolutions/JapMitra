import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/repositories/jap_repository.dart';
import '../../main.dart';
import '../astrologer/astrologer_model.dart';
import '../astrologer/astrologer_profile_screen.dart';
import '../jap/jap_screen.dart';
import '../numerology/numerology_screen.dart';
import '../panchang/panchang_model.dart';
import '../panchang/panchang_screen.dart';
import '../rashifal/rashifal_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext c) {
    final s = InheritedAppState.of(c);
    final l = AppLocalizations.of(c);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(l.t('app'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date and city header.
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '🙏 ${now.day}/${now.month}/${now.year} • ${s.city}',
              style: Theme.of(c).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF5A3A1A),
                  ),
            ),
          ),
          // Today's Jap card.
          FutureBuilder<int>(
            future: JapRepository().todayCountForMantra(s.selectedMantra),
            builder: (c, snap) {
              final count = snap.data ?? 0;
              final progress =
                  s.dailyGoal > 0 ? (count / s.dailyGoal).clamp(0.0, 1.0) : 0.0;
              return _premiumCard(
                c,
                icon: Icons.spa,
                title: l.t('todayJap'),
                subtitle: s.selectedMantra,
                onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(builder: (_) => const JapScreen()),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '$count / ${s.dailyGoal}',
                          style: Theme.of(c).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFE87822),
                              ),
                        ),
                        const Spacer(),
                        Text(
                          '${count ~/ 108} ${l.t('mala')}',
                          style: Theme.of(c).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF8A6A3A),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        color: const Color(0xFFE87822),
                        backgroundColor:
                            const Color(0xFFE87822).withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Panchang card.
          _panchangCard(c),
          // Rashifal card.
          _premiumCard(
            c,
            icon: Icons.auto_awesome,
            title: l.t('rashifal'),
            subtitle: l.t('rashifalDesc'),
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => const RashifalScreen()),
            ),
          ),
          // Numerology card.
          _premiumCard(
            c,
            icon: Icons.numbers,
            title: l.t('numerology'),
            subtitle: l.t('notSci'),
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => const NumerologyScreen()),
            ),
          ),
          // Astrologer consultation card.
          _astrologerCard(c),
          // Inspiration quote.
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.t('inspiration'),
                    style: Theme.of(c).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFFB08040),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.t('quoteDaily'),
                    style: Theme.of(c).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF5A3A1A),
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panchangCard(BuildContext c) {
    final s = InheritedAppState.of(c);
    final l = AppLocalizations.of(c);
    return _premiumCard(
      c,
      icon: Icons.calendar_month,
      title: l.t('panchang'),
      subtitle: '',
      onTap: () => Navigator.push(
        c,
        MaterialPageRoute(builder: (_) => const PanchangScreen()),
      ),
      child: FutureBuilder<PanchangDay?>(
        future: PanchangRepository().getDay(DateTime.now(), s.city),
        builder: (c, snap) {
          final p = snap.data;
          final sub = p == null
              ? l.t('unavailable')
              : '${l.isHindi ? p.tithi : PanchangDayEnglish.tithi(p.tithiIndex ?? 1)}  •  ${l.t('sunrise')} ${p.sunrise}';
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              sub,
              style: Theme.of(c).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF7A5A2A),
                  ),
            ),
          );
        },
      ),
    );
  }

  /// Consulting a Jyotishi is a separate feature with its own screen, not a
  /// tab: it adds no bottom-navigation destination and changes no existing one.
  Widget _astrologerCard(BuildContext c) {
    final l = AppLocalizations.of(c);
    const a = featuredAstrologer;
    return _premiumCard(
      c,
      icon: Icons.auto_awesome,
      title: l.t('astroTitle'),
      subtitle: '${a.name} • ${a.title} • ${a.availabilityLine}',
      onTap: () => Navigator.push(
        c,
        MaterialPageRoute(builder: (_) => const AstrologerProfileScreen()),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF3C97A), Color(0xFFE87822)],
              ),
            ),
            alignment: Alignment.center,
            // The approved photo when one is bundled, the monogram otherwise.
            child: a.photoAsset == null
                ? Text(
                    a.monogram,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  )
                : ClipOval(
                    child: Image.asset(
                      a.photoAsset!,
                      key: const Key('astro_home_photo'),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Text(
                        a.monogram,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  a.experience,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(c)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${a.fee} • ${a.consultationMinutes} ${l.t('astroMinutes')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(c).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8A6A3A),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumCard(
    BuildContext c, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? child,
  }) =>
      Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: const Color(0xFFE87822), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(c).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFFB08040)),
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: Text(
                      subtitle,
                      style: Theme.of(c).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8A6A3A),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (child != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: child,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}
