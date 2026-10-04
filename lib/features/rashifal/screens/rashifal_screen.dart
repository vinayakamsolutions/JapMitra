import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import '../models/daily_rashifal.dart';
import '../services/rashifal_repository.dart';
import '../widgets/rashifal_common.dart';
import 'rashifal_detail_screen.dart';

export '../widgets/rashifal_common.dart' show signs, signForKey;

/// A date-specific reader; selecting a sign also remembers it as the user's own.
class RashifalScreen extends StatefulWidget {
  const RashifalScreen({super.key, this.repository});

  final RashifalRepository? repository;

  @override
  State<RashifalScreen> createState() => _RashifalScreenState();
}

class _RashifalScreenState extends State<RashifalScreen> {
  late final RashifalRepository _repo;
  late DateTime _date;
  bool _loading = true;
  RashifalDayResult? _result;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RashifalRepository();
    _date = _repo.today;
    _load();
  }

  Future<void> _load() async {
    final request = ++_requestVersion;
    setState(() => _loading = true);
    RashifalDayResult? result;
    try {
      // Bound the UI wait, not the repository's source order or validation.
      result =
          await _repo.getForDate(_date).timeout(const Duration(seconds: 30));
    } catch (_) {
      // Storage/network errors become a retryable state, never a stuck spinner.
      result = null;
    }
    if (!mounted || request != _requestVersion) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  DateTime _shifted(int days) =>
      DateTime(_date.year, _date.month, _date.day + days);

  Future<void> _go(int days) async {
    final target = _shifted(days);
    if (_repo.isFuture(target)) return;
    setState(() => _date = target);
    await _load();
  }

  Future<void> _goToday() async {
    final today = _repo.today;
    if (_date == today) return;
    setState(() => _date = today);
    await _load();
  }

  Future<void> _openSign(String signKey) async {
    await InheritedAppState.of(context).setRashiSign(signKey);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RashifalDetailScreen(
          signKey: signKey,
          date: _date,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final app = InheritedAppState.of(context);
    final selected = signForKey(app.rashiSign);
    final isToday = _date == _repo.today;
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
            _dateBar(context, l, isToday),
            const SizedBox(height: 16),
            _mySignCard(context, l, selected),
            const SizedBox(height: 22),
            RashifalSectionLabel(
              l.t('rashifalPickSign'),
              icon: Icons.auto_awesome_outlined,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const RashifalLoadingCard()
            else if (_result == null)
              RashifalUnavailableCard(
                title: l.t('unavailable'),
                message: l.t('rashifalUnavailableNote'),
                onRetry: _load,
              )
            else
              _signGrid(context, app.languageCode, selected),
            const SizedBox(height: 20),
            const RashifalDisclaimerCard(),
          ],
        ),
      ),
    );
  }

  Widget _dateBar(BuildContext c, AppLocalizations l, bool isToday) {
    return RashifalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t(isToday ? 'rashifalToday' : 'rashifal'),
            style: Theme.of(c).textTheme.titleLarge?.copyWith(
                  color: RashifalPalette.ink,
                  fontSize: 24,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          // The day being read is the most important fact on the screen, so it
          // sits directly under the heading in terracotta.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.event_outlined,
                  size: 18, color: RashifalPalette.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatRashifalDate(
                      _date, InheritedAppState.of(c).languageCode),
                  key: const Key('rashifal_selected_date'),
                  style: Theme.of(c).textTheme.titleMedium?.copyWith(
                        color: RashifalPalette.saffron,
                        fontSize: 18,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: RashifalPalette.line),
          const SizedBox(height: 10),
          Center(child: _dayStepper(c, l, isToday)),
          if (!_loading && _result != null) ...[
            const SizedBox(height: 12),
            RashifalSourceBadge(fromCache: _result!.fromCache, compact: true),
          ],
        ],
      ),
    );
  }

  /// The three day controls share one warm pill, so they read as a single
  /// instrument rather than three unrelated buttons spread across the card.
  Widget _dayStepper(BuildContext c, AppLocalizations l, bool isToday) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RashifalPalette.wash,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l.t('rashifalPrevDay'),
              icon: const Icon(Icons.chevron_left),
              color: RashifalPalette.saffron,
              onPressed: _loading ? null : () => _go(-1),
            ),
            if (isToday)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.calendar_today_outlined,
                    size: 20, color: RashifalPalette.gold),
              )
            else
              IconButton(
                tooltip: l.t('rashifalTodayShort'),
                icon: const Icon(Icons.today_outlined),
                color: RashifalPalette.saffron,
                onPressed: _loading ? null : _goToday,
              ),
            IconButton(
              tooltip: l.t('rashifalNextDay'),
              icon: const Icon(Icons.chevron_right),
              color: RashifalPalette.saffron,
              onPressed: !_loading && !_repo.isFuture(_shifted(1))
                  ? () => _go(1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _mySignCard(
      BuildContext c, AppLocalizations l, List<String>? selected) {
    return RashifalCard(
      highlighted: selected != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star_outline,
                    size: 20, color: RashifalPalette.saffron),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.t('myRashi'),
                  style: Theme.of(c).textTheme.titleSmall?.copyWith(
                        color: RashifalPalette.ink,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (selected != null)
                IconButton(
                  tooltip: l.t('clearMySign'),
                  icon: const Icon(Icons.close, size: 20),
                  color: RashifalPalette.muted,
                  onPressed: () => InheritedAppState.of(c).setRashiSign(null),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            selected == null
                ? l.t('rashiNotSetNote')
                : signNameFor(selected[0],
                    language: InheritedAppState.of(c).languageCode),
            style: Theme.of(c).textTheme.titleLarge?.copyWith(
                  color: selected == null
                      ? RashifalPalette.muted
                      : RashifalPalette.saffron,
                  height: 1.4,
                  fontSize: 20,
                  fontWeight:
                      selected == null ? FontWeight.w400 : FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  /// Natural-height tiles respect system text scaling instead of shrinking text
  /// into a fixed aspect ratio. At large sizes the grid becomes one column.
  Widget _signGrid(BuildContext c, String language, List<String>? selected) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final columns = ((constraints.maxWidth + gap) / (124 * scale + gap))
            .floor()
            .clamp(1, 4);
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final sign in kRashifalSignKeys)
              SizedBox(
                width: tileWidth,
                child: _signCard(
                  c,
                  sign,
                  language: language,
                  isMine: selected != null && selected[0] == sign,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _signCard(
    BuildContext c,
    String signKey, {
    required String language,
    required bool isMine,
  }) {
    return Semantics(
      selected: isMine,
      child: RashifalCard(
        key: ValueKey('rashifal_sign_$signKey'),
        highlighted: isMine,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        onTap: () => _openSign(signKey),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isMine ? Colors.white : RashifalPalette.wash,
                borderRadius: BorderRadius.circular(17),
                border: Border.fromBorderSide(
                  isMine ? AppTheme.hairline(0.55) : AppTheme.hairline(0.18),
                ),
              ),
              child: ExcludeSemantics(
                child: Text(
                  glyphForSign(signKey),
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                      fontSize: 30, color: RashifalPalette.saffron),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              signNameFor(signKey, language: language),
              textAlign: TextAlign.center,
              style: Theme.of(c).textTheme.titleMedium?.copyWith(
                    color: RashifalPalette.ink,
                    fontSize: 17,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 10),
            Icon(
              isMine ? Icons.check_circle : Icons.arrow_forward,
              size: 20,
              color: isMine ? RashifalPalette.saffron : RashifalPalette.gold,
            ),
          ],
        ),
      ),
    );
  }
}
