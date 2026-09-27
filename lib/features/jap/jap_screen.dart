import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/services/feedback_service.dart';
import '../../data/repositories/jap_repository.dart';
import '../../main.dart';
import 'deity_background.dart';
import 'jap_logic.dart';
import 'tap_visual.dart';

/// A mantra of 108 taps.
const int kMalaSize = 108;

/// Side length of the square box a tap glow is laid out in. The caller supplies
/// the [Positioned] so the glow is a pure overlay: it can never take part in
/// normal layout and can never be responsible for a tap count.
const double kTapGlowExtent = 120;

/// Reserved square so the mantra title never sits underneath the overflow menu.
const double _kMenuGutter = 40;

class JapScreen extends StatefulWidget {
  const JapScreen({super.key, this.repository});

  /// Injectable for tests; production uses the sqflite-backed repository.
  final JapRepository? repository;

  @override
  State<JapScreen> createState() => _J();
}

class _J extends State<JapScreen> {
  /// Guard against a tap burst spawning an unbounded number of animations.
  static const int _maxGlows = 20;

  late final JapRepository repo;

  int session = 0;
  int lifetime = 0;
  int streak = 0;

  /// Persisted count for today **as it stood when the session began**.
  ///
  /// The displayed day total is `_todayBaseline + session`, so the figure is
  /// correct the instant a tap happens and never double counts once the queue
  /// has flushed the session into the store.
  int _todayBaseline = 0;

  /// Total Jap for today, live.
  int get today => _todayBaseline + session;

  /// Cached from [InheritedAppState] in [didChangeDependencies] so that event
  /// handlers never register an inherited-widget dependency themselves.
  String mantra = '';
  int dailyGoal = 108;
  String vibrationMode = FeedbackModes.vibOff;
  String soundMode = FeedbackModes.soundOff;
  bool _synced = false;

  JapTapQueue? _queue;
  String? _queueMantra;

  final _glows = <(int, Offset)>[];
  int _glowId = 0;
  Timer? _statsDebounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = InheritedAppState.of(context);
    mantra = app.selectedMantra;
    dailyGoal = app.dailyGoal;
    vibrationMode = app.vibrationMode;
    soundMode = app.soundMode;
    if (_synced && mantra.isNotEmpty) return;
    _synced = true;
    repo = widget.repository ?? JapRepository();
    _load();
  }

  @override
  void dispose() {
    _statsDebounce?.cancel();
    _queue?.flush();
    super.dispose();
  }

  Future<void> _load() async {
    final name = mantra;
    final stats = await _statsFor(name);
    if (!mounted) return;
    setState(() {
      session = 0;
      _todayBaseline = stats.today;
      lifetime = stats.lifetime;
      streak = stats.streak;
      _queue = JapTapQueue(repo, name);
      _queueMantra = name;
    });
  }

  Future<({int today, int lifetime, int streak})> _statsFor(String m) async {
    final c = await repo.todayCountForMantra(m);
    final l = await repo.lifetime(mantra: m);
    final s = await repo.streaks(m);
    return (today: c, lifetime: l, streak: s.current);
  }

  Future<void> _refreshStats() async {
    final stats = await _statsFor(mantra);
    if (!mounted) return;
    setState(() {
      // The flush has already written this session, so subtract it from the
      // stored total to keep the baseline meaning "before this session".
      _todayBaseline = (stats.today - session).clamp(0, stats.today);
      lifetime = stats.lifetime;
      streak = stats.streak;
    });
  }

  /// The single entry point for counting one Jap.
  ///
  /// Order is fixed and synchronous: count and repaint first, then queue the
  /// visual effect, then hand the tap to the debounced persistence queue.
  /// Nothing here awaits, so a burst of taps can never be dropped, blocked or
  /// counted twice.
  void _recordTap(Offset at) {
    if (mantra.isEmpty) return;
    if (_queue == null || _queueMantra != mantra) {
      _queue = JapTapQueue(repo, mantra);
      _queueMantra = mantra;
    }

    final next = session + 1;
    final id = _glowId++;
    setState(() {
      session = next;
      _glows.add((id, at));
      if (_glows.length > _maxGlows) {
        _glows.removeRange(0, _glows.length - _maxGlows);
      }
    });

    // Async, debounced persistence — never awaited by the tap.
    _queue!.recordTap();
    _scheduleStatsRefresh();

    // Fire-and-forget feedback — never blocks counting.
    const FeedbackService().onJap(
      vibrationMode: vibrationMode,
      soundMode: soundMode,
      sessionCount: next,
      malaSize: kMalaSize,
    );

    if (next % kMalaSize == 0) _celebrateMala();
  }

  void _removeGlow(int id) {
    if (!mounted) return;
    final index = _glows.indexWhere((g) => g.$1 == id);
    if (index < 0) return;
    setState(() => _glows.removeAt(index));
  }

  void _scheduleStatsRefresh() {
    _statsDebounce?.cancel();
    _statsDebounce = Timer(const Duration(milliseconds: 350), _refreshStats);
  }

  void _celebrateMala() {
    const FeedbackService().onMalaComplete();
    final info = mantraInfoFor(mantra);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('🙏 ${info.completionMessage}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _endSession() async {
    final l = AppLocalizations.of(context);
    await _queue?.flush();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(l.t('endSessionTitle')),
        content: Text(l.t('endSessionBody')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(l.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(dc, true),
              child: Text(l.t('confirm'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _refreshStats();
    if (!mounted) return;
    setState(() => session = 0);
  }

  Future<void> _confirmReset() async {
    final l = AppLocalizations.of(context);
    await _queue?.flush();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(l.t('confirmReset')),
        content: Text(l.t('resetExplain')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(l.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(dc, true), child: Text(l.t('ok'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await repo.resetTodayForMantra(mantra);
    if (!mounted) return;
    setState(() {
      session = 0;
      _todayBaseline = 0;
      _queue = JapTapQueue(repo, mantra);
      _queueMantra = mantra;
    });
  }

  Future<void> _openMantraPicker() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const MantraScreen()));
    if (!mounted) return;
    setState(() => _glows.clear());
    await _load();
  }

  @override
  Widget build(BuildContext c) {
    final app = InheritedAppState.of(c);
    final l = AppLocalizations.of(c);
    final info = mantraInfoFor(app.selectedMantra);
    // Two honest views of the same data: the mala is about this session, the
    // daily goal is about the whole day including this session.
    final sessionState = JapCounterState(
        count: session, malaSize: kMalaSize, dailyGoal: app.dailyGoal);
    final dayState = JapCounterState(
        count: today, malaSize: kMalaSize, dailyGoal: app.dailyGoal);
    final completedMalas = today ~/ kMalaSize;

    return DeityBackground(
      deityKey: info.deityKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              // Every dimension below is derived from the space the layout
              // actually received, never from a hardcoded screen size.
              final hPad = box.maxWidth * 0.06;
              final vPad = box.maxHeight * 0.015;
              final counterFont = math
                  .min(box.maxWidth * 0.26, box.maxHeight * 0.17)
                  .clamp(44.0, 112.0);

              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  // 1. Tap surface: fills whatever the layout gives it and is
                  //    never sized by the animation, persistence or background.
                  Positioned.fill(
                    child: Semantics(
                      container: true,
                      button: true,
                      label: l.t('tapAccessibility'),
                      onTap: () => _recordTap(
                          Offset(box.maxWidth / 2, box.maxHeight / 2)),
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) => _recordTap(e.localPosition),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),

                  // 2. Read-only content. IgnorePointer keeps the whole layer
                  //    transparent to input so taps reach the surface above.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _Content(
                        info: info,
                        sessionState: sessionState,
                        dayState: dayState,
                        mantra: app.selectedMantra,
                        today: today,
                        lifetime: lifetime,
                        streak: streak,
                        completedMalas: completedMalas,
                        dailyGoal: app.dailyGoal,
                        todayLabel: l.t('today'),
                        lifetimeLabel: l.t('lifetime'),
                        streakLabel: l.t('streak'),
                        malaLabel: l.t('mala'),
                        malaCompleteLabel: l.t('malaComplete'),
                        goalLabel: l.t('goal'),
                        hintLabel: l.t('tapHint'),
                        horizontalPadding: hPad,
                        verticalPadding: vPad,
                        counterFontSize: counterFont,
                        // Visual only: the persisted mantra size, applied by
                        // _Content. No counting or persistence code reads it.
                        mantraFontSize: app.mantraFontSize,
                      ),
                    ),
                  ),

                  // 3. The only interactive chrome. Sits above the tap surface
                  //    so its own taps are not counted as Jap.
                  Positioned(
                    top: vPad,
                    right: hPad,
                    child: PopupMenuButton<String>(
                      tooltip: l.t('more'),
                      icon:
                          const Icon(Icons.more_vert, color: Color(0xFF5A3A1A)),
                      onSelected: (v) {
                        if (v == 'mantra') _openMantraPicker();
                        if (v == 'end') _endSession();
                        if (v == 'reset') _confirmReset();
                      },
                      itemBuilder: (bc) => [
                        PopupMenuItem(
                          value: 'mantra',
                          child: _menuRow(
                              Icons.edit_outlined, l.t('selectMantra')),
                        ),
                        PopupMenuItem(
                          value: 'end',
                          child: _menuRow(
                              Icons.flag_outlined, l.t('endSessionTitle')),
                        ),
                        PopupMenuItem(
                          value: 'reset',
                          child: _menuRow(Icons.delete_outline, l.t('reset')),
                        ),
                      ],
                    ),
                  ),

                  // 4. Tap effect overlay: pure decoration, no layout, no input.
                  //    Each effect is clamped to the viewport so a tap near an
                  //    edge is still fully visible instead of being cut off.
                  for (final g in _glows)
                    Positioned(
                      left: (g.$2.dx - kTapGlowExtent / 2).clamp(
                          0.0, math.max(0.0, box.maxWidth - kTapGlowExtent)),
                      top: (g.$2.dy - kTapGlowExtent / 2).clamp(
                          0.0, math.max(0.0, box.maxHeight - kTapGlowExtent)),
                      width: kTapGlowExtent,
                      height: kTapGlowExtent,
                      child: GoldenTapGlow(
                        key: ValueKey(g.$1),
                        // The mantra, never the count: the number is already
                        // shown by the counter, so repeating it here is noise.
                        mantra: app.selectedMantra,
                        onDone: () => _removeGlow(g.$1),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _menuRow(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF5A3A1A)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Color(0xFF3E2415)),
            ),
          ),
        ],
      );
}

/// Responsive, non-overflowing read-only content of the Jap screen.
///
/// Everything is sized from the incoming constraints: a vertical scroll view
/// acts purely as a safety net (it can never report an overflow) and the column
/// spreads its children with [MainAxisAlignment.spaceEvenly] so tall screens do
/// not leave a dead lower half.
class _Content extends StatelessWidget {
  const _Content({
    required this.info,
    required this.sessionState,
    required this.dayState,
    required this.mantra,
    required this.today,
    required this.lifetime,
    required this.streak,
    required this.completedMalas,
    required this.dailyGoal,
    required this.todayLabel,
    required this.lifetimeLabel,
    required this.streakLabel,
    required this.malaLabel,
    required this.malaCompleteLabel,
    required this.goalLabel,
    required this.hintLabel,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.counterFontSize,
    required this.mantraFontSize,
  });

  final MantraInfo info;

  /// Mala progress for this session.
  final JapCounterState sessionState;

  /// Daily goal progress for the whole day.
  final JapCounterState dayState;
  final String mantra;
  final int today;
  final int lifetime;
  final int streak;
  final int completedMalas;
  final int dailyGoal;
  final String todayLabel;
  final String lifetimeLabel;
  final String streakLabel;
  final String malaLabel;
  final String malaCompleteLabel;
  final String goalLabel;
  final String hintLabel;
  final double horizontalPadding;
  final double verticalPadding;
  final double counterFontSize;

  /// Persisted visual size of the mantra line, in logical pixels.
  ///
  /// Only [_mantraTitle] reads it. Counting, progress, queueing and storage are
  /// untouched by it, so changing the setting can never change a stored count.
  final double mantraFontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final gap = (box.maxHeight * 0.03).clamp(8.0, 18.0);
        // The height the mantra line may occupy: a fraction of both the chosen
        // size and the viewport, so the line never squeezes the counter out of a
        // short screen.
        final mantraHeight = (mantraFontSize * 2.2)
            .clamp(28.0, math.max(28.0, box.maxHeight * 0.24))
            .toDouble();
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, verticalPadding,
              horizontalPadding, verticalPadding),
          // The scroll view guarantees the column can never report an overflow;
          // the minHeight constraint is what lets spaceEvenly spread the content
          // on tall screens instead of leaving a dead lower half.
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minHeight: math.max(0, box.maxHeight - verticalPadding * 2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _mantraTitle(theme, mantraHeight),
                _statsRow(theme),
                _counter(theme),
                _malaBlock(theme, gap),
                _goalBlock(theme, gap),
                _hint(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mantraTitle(ThemeData theme, double height) => Row(
        children: [
          const SizedBox(width: _kMenuGutter),
          Expanded(
            child: SizedBox(
              height: height,
              child: FittedBox(
                // scaleDown keeps every preset usable on a 320px screen and at
                // a 3.5x system text scale: the text shrinks, it never clips.
                fit: BoxFit.scaleDown,
                child: Text(
                  mantra,
                  key: const Key('jap_mantra_name'),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  softWrap: true,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF5A3A1A),
                    fontWeight: FontWeight.w600,
                    fontSize: mantraFontSize,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: _kMenuGutter),
        ],
      );

  Widget _statsRow(ThemeData theme) => Row(
        children: [
          Expanded(
              child: _stat(theme, todayLabel, '$today',
                  valueKey: const Key('jap_today'))),
          Expanded(
              child: _stat(theme, lifetimeLabel, '$lifetime',
                  valueKey: const Key('jap_lifetime'))),
          Expanded(
              child: _stat(theme, streakLabel, '$streak',
                  valueKey: const Key('jap_streak'))),
        ],
      );

  Widget _stat(ThemeData theme, String label, String value, {Key? valueKey}) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _statValueHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                key: valueKey,
                maxLines: 1,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF3E2415),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: const Color(0xFF8A6A3A)),
          ),
        ],
      );

  /// Counter occupies a slot derived from the viewport and is additionally
  /// guarded by [FittedBox], so a six digit count can never push neighbours out.
  Widget _counter(ThemeData theme) => SizedBox(
        height: counterFontSize * 1.25,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$session',
              key: const Key('jap_counter'),
              maxLines: 1,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5A3A1A),
                fontSize: counterFontSize,
                height: 1,
              ),
            ),
          ),
        ),
      );

  int get session => sessionState.count;

  Widget _malaBlock(ThemeData theme, double gap) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$malaLabel ${sessionState.mala}  •  ${sessionState.currentJap}/$kMalaSize',
            key: const Key('jap_mala_label'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: const Color(0xFF7A5A2A),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: gap * 0.5),
          SizedBox(
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: sessionState.malaProgress,
                minHeight: 6,
                color: const Color(0xFFE87822),
                backgroundColor:
                    const Color(0xFFE87822).withValues(alpha: 0.15),
              ),
            ),
          ),
          SizedBox(height: gap * 0.5),
          Text(
            '$malaCompleteLabel: $completedMalas',
            key: const Key('jap_mala_completed'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: const Color(0xFFA98050)),
          ),
        ],
      );

  Widget _goalBlock(ThemeData theme, double gap) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: dayState.goalProgress,
                minHeight: 4,
                color: const Color(0xFFD8A94A),
                backgroundColor:
                    const Color(0xFFD8A94A).withValues(alpha: 0.15),
              ),
            ),
          ),
          SizedBox(height: gap * 0.4),
          Text(
            '$goalLabel ${dayState.count} / $dailyGoal',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: const Color(0xFF7A5A2A)),
          ),
        ],
      );

  Widget _hint(ThemeData theme) => Text(
        hintLabel,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style:
            theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFA98050)),
      );

  static const double _statValueHeight = 30;
}

// ---------------------------------------------------------------------------
// Mantra Picker
// ---------------------------------------------------------------------------

class MantraScreen extends StatefulWidget {
  const MantraScreen({super.key});
  @override
  State<MantraScreen> createState() => _M();
}

class _M extends State<MantraScreen> {
  final repo = JapRepository();
  final ctrl = TextEditingController();
  List<String> custom = [];

  @override
  void initState() {
    super.initState();
    repo.customMantras().then((v) {
      if (mounted) setState(() => custom = v);
    });
  }

  @override
  Widget build(BuildContext c) {
    final app = InheritedAppState.of(c);
    final l = AppLocalizations.of(c);
    final all = [...defaultMantras.map((e) => e[1]), ...custom];
    return Scaffold(
      appBar: AppBar(title: Text(l.t('selectMantra'))),
      body: ListView(
        children: [
          for (final m in all)
            ListTile(
              title: Text(m, style: const TextStyle(fontSize: 18)),
              subtitle: Text(
                isBuiltInMantra(m)
                    ? defaultMantras.firstWhere((e) => e[1] == m)[0]
                    : l.t('customMantra'),
              ),
              selected: m == app.selectedMantra,
              trailing: custom.contains(m)
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await repo.deleteCustom(m);
                        final v = await repo.customMantras();
                        if (mounted) setState(() => custom = v);
                      },
                    )
                  : null,
              onTap: () async {
                await app.setMantra(m);
                if (c.mounted) Navigator.pop(c);
              },
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: '+ ${l.t('customMantra')}',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    try {
                      await repo.addCustom(ctrl.text);
                      final v = await repo.customMantras();
                      ctrl.clear();
                      if (mounted) setState(() => custom = v);
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.t('emptyMantra'))),
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
