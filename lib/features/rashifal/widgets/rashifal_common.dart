/// Shared building blocks for the Rashifal screens.
///
/// The visual language is the app's warm spiritual palette: a cream canvas,
/// saffron accents, subtle gold, soft rounded cards. Nothing here is dark or
/// heavy, and every card leaves room for a long line of guidance.
library;

import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';

/// Local presentation colors aligned with the app-wide premium theme.
class RashifalPalette {
  const RashifalPalette._();

  static const canvas = AppTheme.cream;
  static const ink = AppTheme.brown;
  static const muted = AppTheme.brownSoft;
  static const saffron = AppTheme.saffron;
  static const gold = AppTheme.gold;
  static const line = Color(0xFFE8DCC3);
  static const wash = AppTheme.goldSoft;
}

/// A small label used above a group of content, so a section announces itself
/// without a loud banner.
class RashifalSectionLabel extends StatelessWidget {
  const RashifalSectionLabel(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: RashifalPalette.gold),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: RashifalPalette.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
          ),
        ),
      ],
    );
  }
}

/// A softly outlined surface shared by Rashifal content and its Home entry.
class RashifalCard extends StatelessWidget {
  const RashifalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.highlighted = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Card(
      color: highlighted ? RashifalPalette.wash : AppTheme.white,
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      margin: EdgeInsets.zero,
      shadowColor: AppTheme.brown.withValues(alpha: 0.10),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.cardRadius,
        side: AppTheme.hairline(highlighted ? 0.42 : 0.20),
      ),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: AppTheme.cardRadius,
              child: content,
            ),
    );
  }
}

/// A deliberate loading surface; request timing is owned by the screen.
class RashifalLoadingCard extends StatelessWidget {
  const RashifalLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return RashifalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: RashifalPalette.saffron,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l.t('rashifal'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: RashifalPalette.ink,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Placeholder bars carry the shape of the incoming reading so the
          // card does not jump when the real content arrives.
          for (final width in const [1.0, 0.92, 0.6]) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: LinearProgressIndicator(
                  value: width,
                  color: RashifalPalette.wash,
                  backgroundColor: RashifalPalette.wash.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// The twelve zodiac signs, in the traditional order.
///
/// [0] is the stable key used in storage and in the generated JSON, [1] the
/// Devanagari name, [2] the Latin name and [3] the symbol. Both scripts are
/// retained here so callers can choose the display language without changing
/// a sign's stored identity.
const signs = [
  ['mesha', 'मेष', 'Mesha', '♈'],
  ['vrishabha', 'वृषभ', 'Vrishabha', '♉'],
  ['mithun', 'मिथुन', 'Mithun', '♊'],
  ['karka', 'कर्क', 'Karka', '♋'],
  ['simha', 'सिंह', 'Simha', '♌'],
  ['kanya', 'कन्या', 'Kanya', '♍'],
  ['tula', 'तुला', 'Tula', '♎'],
  ['vrishchik', 'वृश्चिक', 'Vrishchik', '♏'],
  ['dhanu', 'धनु', 'Dhanu', '♐'],
  ['makar', 'मकर', 'Makar', '♑'],
  ['kumbh', 'कुंभ', 'Kumbh', '♒'],
  ['meen', 'मीन', 'Meen', '♓'],
];

/// Finds a sign by its stable key.
List<String>? signForKey(String? key) {
  if (key == null) return null;
  for (final s in signs) {
    if (s[0] == key) return s;
  }
  return null;
}

/// The zodiac glyph for a sign key, looked up from the shared sign table.
String glyphForSign(String signKey) {
  for (final s in signs) {
    if (s[0] == signKey) return s[3];
  }
  return '✶';
}

/// The localized display name, or both scripts when no language is supplied.
String signNameFor(String signKey, {String? language}) {
  for (final s in signs) {
    if (s[0] != signKey) continue;
    if (language == 'hi') return s[1];
    if (language == 'en') return s[2];
    return '${s[1]} / ${s[2]}';
  }
  return signKey;
}

/// Readable context that accompanies every reading without overpowering it.
class RashifalDisclaimerCard extends StatelessWidget {
  const RashifalDisclaimerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return RashifalCard(
      highlighted: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline,
              size: 22,
              color: RashifalPalette.saffron,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.t('rashifalDisclaimer'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    color: RashifalPalette.muted,
                    height: 1.6,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One labelled category of a reading.
///
/// The icon chip and the label sit above the value, so a long paragraph keeps a
/// clear hierarchy instead of sharing a line with its label.
class RashifalCategoryCard extends StatelessWidget {
  const RashifalCategoryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String value;

  /// Gives lucky values a subtle accent without reducing their readable size.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RashifalCard(
      highlighted: highlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The label and its chip share one wrapping row, so a long localized
          // title reflows beside the icon instead of clipping it.
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: highlight
                      ? Colors.white.withValues(alpha: 0.7)
                      : RashifalPalette.wash,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Icon(icon, size: 22, color: RashifalPalette.saffron),
                ),
              ),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: RashifalPalette.ink,
                ),
              ),
            ],
          ),
          // A hairline under the label: the reading below is prose, and the
          // reader's eye should land on it, not on the heading.
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              thickness: 1,
              color: RashifalPalette.line,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              color: RashifalPalette.ink,
              height: 1.65,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// The honest "nothing here" state.
///
/// Shown when a day has neither a bundled, fresh nor a cached payload. It
/// explains the situation and offers to try again, and it never dresses up
/// absence as a reading.
class RashifalUnavailableCard extends StatelessWidget {
  const RashifalUnavailableCard({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return RashifalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: RashifalPalette.wash,
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                size: 32,
                color: RashifalPalette.saffron,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 18,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: RashifalPalette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              color: RashifalPalette.muted,
              height: 1.6,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.saffron,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: const StadiumBorder(),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  const Icon(Icons.refresh, size: 20),
                  Text(
                    retryLabel ?? l.t('rashifalRetry'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Where the displayed day came from.
///
/// Wraps naturally so the source remains visible at large accessibility sizes.
class RashifalSourceBadge extends StatelessWidget {
  const RashifalSourceBadge({
    super.key,
    required this.fromCache,
    required this.compact,
  });

  final bool fromCache;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label =
        fromCache ? l.t('rashifalFromCache') : l.t('rashifalFromRemote');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.fromBorderSide(AppTheme.hairline(0.28)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 8 : 12,
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              fromCache
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_download_outlined,
              size: 20,
              color: RashifalPalette.saffron,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    height: 1.5,
                    color: RashifalPalette.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Month names for the date line, keyed by language.
///
/// A small explicit list keeps the date readable without pulling in locale data
/// just to name a month.
String monthName(int month, String language) {
  const hi = <String>[
    'जनवरी',
    'फ़रवरी',
    'मार्च',
    'अप्रैल',
    'मई',
    'जून',
    'जुलाई',
    'अगस्त',
    'सितंबर',
    'अक्टूबर',
    'नवंबर',
    'दिसंबर',
  ];
  const en = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  if (month < 1 || month > 12) return '';
  return language == 'en' ? en[month - 1] : hi[month - 1];
}

/// `28 सितंबर 2026` / `28 September 2026`.
String formatRashifalDate(DateTime date, String language) =>
    '${date.day} ${monthName(date.month, language)} ${date.year}';
