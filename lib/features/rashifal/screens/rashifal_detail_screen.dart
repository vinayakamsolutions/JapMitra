import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import '../models/daily_rashifal.dart';
import '../services/rashifal_repository.dart';
import '../widgets/rashifal_common.dart';

/// One sign's reading, with its date and source kept beside the content.
class RashifalDetailScreen extends StatefulWidget {
  const RashifalDetailScreen({
    super.key,
    required this.signKey,
    required this.date,
    this.repository,
  });

  final String signKey;
  final DateTime date;
  final RashifalRepository? repository;

  @override
  State<RashifalDetailScreen> createState() => _RashifalDetailScreenState();
}

class _RashifalDetailScreenState extends State<RashifalDetailScreen> {
  late final RashifalRepository _repo;
  bool _loading = true;
  RashifalDayResult? _result;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RashifalRepository();
    _load();
  }

  Future<void> _load() async {
    final request = ++_requestVersion;
    setState(() => _loading = true);
    RashifalDayResult? result;
    try {
      result = await _repo
          .getForDate(widget.date)
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      result = null;
    }
    if (!mounted || request != _requestVersion) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final app = InheritedAppState.of(context);
    final reading = _result?.data.signsFor(app.languageCode)[widget.signKey];
    final isMine = app.rashiSign == widget.signKey;
    final toolbarHeight =
        (MediaQuery.textScalerOf(context).scale(20) * 1.4 + 16)
            .clamp(kToolbarHeight, double.infinity);

    return Scaffold(
      backgroundColor: RashifalPalette.canvas,
      appBar: AppBar(
        backgroundColor: RashifalPalette.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: RashifalPalette.ink,
        toolbarHeight: toolbarHeight,
        title: Text(l.t('rashifal'), style: const TextStyle(fontSize: 20)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            _header(context, l, app.languageCode, isMine),
            const SizedBox(height: 16),
            if (_loading)
              const RashifalLoadingCard()
            else if (reading == null)
              RashifalUnavailableCard(
                title: l.t('unavailable'),
                message: l.t('rashifalUnavailableNote'),
                onRetry: _load,
              )
            else
              ..._categories(context, reading),
            const SizedBox(height: 20),
            const RashifalDisclaimerCard(),
          ],
        ),
      ),
    );
  }

  Widget _header(
      BuildContext c, AppLocalizations l, String language, bool isMine) {
    return RashifalCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(19),
              border: Border.fromBorderSide(AppTheme.hairline(0.42)),
            ),
            child: ExcludeSemantics(
              child: Text(
                glyphForSign(widget.signKey),
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                    fontSize: 32, color: RashifalPalette.saffron),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            signNameFor(widget.signKey, language: language),
            style: Theme.of(c).textTheme.headlineSmall?.copyWith(
                  color: RashifalPalette.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.event_outlined,
                  size: 18, color: RashifalPalette.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatRashifalDate(widget.date, language),
                  style: Theme.of(c).textTheme.bodyLarge?.copyWith(
                        color: RashifalPalette.muted,
                        fontSize: 17,
                        height: 1.5,
                      ),
                ),
              ),
            ],
          ),
          if (isMine) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.star_outline,
                      size: 18, color: RashifalPalette.saffron),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.t('myRashi'),
                    style: Theme.of(c).textTheme.bodyMedium?.copyWith(
                          color: RashifalPalette.saffron,
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ],
          if (!_loading && _result != null) ...[
            const SizedBox(height: 14),
            RashifalSourceBadge(fromCache: _result!.fromCache, compact: false),
          ],
        ],
      ),
    );
  }

  List<Widget> _categories(BuildContext c, SignRashifal r) {
    final l = AppLocalizations.of(c);
    final sections = [
      (Icons.wb_sunny_outlined, 'general', r.general),
      (Icons.work_outline, 'career', r.career),
      (Icons.account_balance_wallet_outlined, 'finance', r.finance),
      (Icons.favorite_outline, 'relationships', r.love),
      (Icons.monitor_heart_outlined, 'health', r.health),
      (Icons.lightbulb_outline, 'dailyGuidance', r.guidance),
    ];
    return [
      for (final section in sections) ...[
        RashifalCategoryCard(
          icon: section.$1,
          title: l.t(section.$2),
          value: section.$3,
        ),
        const SizedBox(height: 12),
      ],
      _luckyCards(c, l, r),
    ];
  }

  /// Short values can share a row; narrow screens and enlarged text stack them
  /// in reading order rather than squeezing the labels or truncating values.
  Widget _luckyCards(BuildContext c, AppLocalizations l, SignRashifal r) {
    final number = RashifalCategoryCard(
      icon: Icons.numbers_outlined,
      title: l.t('luckyNumber'),
      value: '${r.luckyNumber}',
      highlight: true,
    );
    final colour = RashifalCategoryCard(
      icon: Icons.palette_outlined,
      title: l.t('luckyColour'),
      value: r.luckyColour,
      highlight: true,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        if (constraints.maxWidth < 300 * scale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [number, const SizedBox(height: 12), colour],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: number),
            const SizedBox(width: 12),
            Expanded(child: colour),
          ],
        );
      },
    );
  }
}
