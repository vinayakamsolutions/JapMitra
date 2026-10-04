import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/services/feedback_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/deity_photo_store.dart';
import '../../data/local/jap_store.dart';
import '../../data/repositories/jap_repository.dart';
import '../../main.dart';
import 'deity_background.dart';
import 'jap_logic.dart';
import 'tap_visual.dart';

const _devanagariDigits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];

String _toDevanagari(int n) {
  if (n == 0) return _devanagariDigits[0];
  final buf = StringBuffer();
  var v = n;
  while (v > 0) {
    buf.write(_devanagariDigits[v % 10]);
    v ~/= 10;
  }
  return buf.toString().split('').reversed.join();
}

/// The hero jap dial: a layered disc with the 108-bead mala ring around it.
///
/// The layering mirrors the Stitch reference exactly, and every layer has its own
/// reserved area so nothing is ever drawn on top of anything else:
///
/// 1. an ambient halo;
/// 2. the decorative outer disc;
/// 3. the 108 beads, sitting in the ring of space between the two discs;
/// 4. an inner disc that carries the count.
///
/// The count therefore has a plain surface behind it and can never be read
/// against the deity artwork or the beads.
class MalaRing extends StatelessWidget {
  const MalaRing({
    super.key,
    required this.count,
    required this.total,
    required this.size,
  });

  final int count;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Ambient halo.
          Container(
            width: size * 0.96,
            height: size * 0.96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.gold.withValues(alpha: 0.12),
            ),
          ),
          // 2. Decorative outer disc.
          Container(
            width: size * 0.86,
            height: size * 0.86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerLow,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF5C4535).withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
          // 3. The 108 beads.
          CustomPaint(
            size: Size.square(size),
            painter: _MalaRingPainter(
              count: count,
              total: total,
              activeColor: AppTheme.saffron,
              inactiveColor: AppTheme.gold.withValues(alpha: 0.28),
            ),
          ),
          // 4. Inner disc carrying the count.
          Container(
            width: size * 0.58,
            height: size * 0.58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerLowest,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF5C4535).withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: EdgeInsets.all(size * 0.04),
                  child: Text(
                    _toDevanagari(count),
                    key: const Key('jap_counter'),
                    style: TextStyle(
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.saffron,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MalaRingPainter extends CustomPainter {
  _MalaRingPainter({
    required this.count,
    required this.total,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int count;
  final int total;
  final Color activeColor;
  final Color inactiveColor;

  /// Bead orbit as a fraction of the dial, matching the Stitch ring (r=120 in a
  /// 280 viewport is 0.417 of the box).
  static const double _radiusFactor = 0.417;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * _radiusFactor;
    if (radius <= 0 || total <= 0) return;

    // Each bead gets its own slice of the circumference. Keeping the diameter
    // comfortably below the arc spacing is what makes all `total` beads read as
    // separate beads instead of merging into a solid ring, at any dial size.
    final arc = (2 * math.pi * radius) / total;
    final beadRadius = math.min(arc * 0.34, size.width * 0.016);

    final activePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = activeColor;
    final inactivePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = inactiveColor;

    for (var i = 0; i < total; i++) {
      final angle = (i / total) * 2 * math.pi - math.pi / 2;
      final beadCenter = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawCircle(
          beadCenter, beadRadius, i < count ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(_MalaRingPainter old) =>
      old.count != count || old.total != total;
}

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

  /// The stored record for the selected mantra when the user made it, so the
  /// screen can show their chosen name and deity photo for it.
  ///
  /// Null for a built-in mantra, and also for a custom mantra that has no photo
  /// yet, in which case the normal deity artwork is used.
  CustomMantra? _customRecord;

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
    final custom = await _customRecordFor(name);
    if (!mounted) return;
    setState(() {
      session = 0;
      _todayBaseline = stats.today;
      lifetime = stats.lifetime;
      streak = stats.streak;
      _queue = JapTapQueue(repo, name);
      _queueMantra = name;
      _customRecord = custom;
    });
  }

  /// Looks up [name] among the user's own mantras, tolerating a storage failure.
  ///
  /// A custom mantra without a photo is still returned, so its saved name is
  /// used; only the photo is optional.
  Future<CustomMantra?> _customRecordFor(String name) async {
    try {
      final all = await repo.custom();
      for (final m in all) {
        if (m.text == name) return m;
      }
    } catch (_) {
      // Missing custom-mantra metadata must never stop the Jap screen from
      // working; the mantra simply falls back to the built-in artwork.
    }
    return null;
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
    final info = mantraInfoFor(
      mantra,
      isCustom: _customRecord != null,
      displayName: _customRecord?.name,
      photo: _customRecord?.photo,
    );
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
    final info = mantraInfoFor(
      app.selectedMantra,
      isCustom: _customRecord != null,
      displayName: _customRecord?.name,
      photo: _customRecord?.photo,
    );
    // Two honest views of the same data: the mala is about this session, the
    // daily goal is about the whole day including this session.
    final sessionState = JapCounterState(
        count: session, malaSize: kMalaSize, dailyGoal: app.dailyGoal);
    final dayState = JapCounterState(
        count: today, malaSize: kMalaSize, dailyGoal: app.dailyGoal);
    final completedMalas = today ~/ kMalaSize;

    return DeityBackground(
      deityKey: info.deityKey,
      photo: info.photo,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // The insets are applied explicitly below rather than by a [SafeArea]
        // wrapper, because the tap surface has to keep the *whole* screen: a
        // tap anywhere counts, including over the deity artwork.
        body: LayoutBuilder(
          builder: (context, box) {
            final media = MediaQuery.of(context);
            final safeTop = media.padding.top;
            final safeBottom = media.padding.bottom;
            final safeLeft = media.padding.left;
            final safeRight = media.padding.right;

            // The deity artwork owns the top band outright. Every read-only
            // element starts below it, so the ring, the counters and the beads
            // can never be drawn across the artwork.
            //
            // The band is measured from the same box this layer is positioned
            // in, and [DeityBackground] measures it from the box it hands to
            // its child, so the two agree by construction. No safe-area inset
            // is subtracted: this layer starts at the top of the screen, not
            // below the status bar, so the artwork's top edge and the content's
            // top edge are measured from the same origin.
            final artworkBand =
                box.maxHeight * DeityBackground.kArtworkBandFraction;
            final contentTop = artworkBand;

            // Every dimension below is derived from the space the layout
            // actually received, never from a hardcoded screen size.
            final hPad = box.maxWidth * 0.06;
            final vPad = box.maxHeight * 0.015;
            final counterFont = math
                .min(box.maxWidth * 0.26, box.maxHeight * 0.17)
                .clamp(44.0, 112.0);

            // The tap effect lives in one dedicated strip below the artwork, so
            // it can never overlap the lower content either.
            final feedbackTop = contentTop;
            final feedbackBottom =
                math.max(feedbackTop, box.maxHeight - safeBottom);
            const half = kTapGlowExtent / 2;
            const minCx = half;
            final maxCx = math.max(minCx, box.maxWidth - half);
            final minCy = feedbackTop + half;
            final maxCy = math.max(minCy, feedbackBottom - half);

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
                    onTap: () =>
                        _recordTap(Offset(box.maxWidth / 2, box.maxHeight / 2)),
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) => _recordTap(e.localPosition),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),

                // 2. Read-only content, held clear of the artwork band.
                //    IgnorePointer keeps the whole layer transparent to input so
                //    taps reach the surface above.
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: contentTop,
                        bottom: safeBottom,
                        left: safeLeft,
                        right: safeRight,
                      ),
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
                ),

                // 3. The only interactive chrome. Sits above the tap surface
                //    so its own taps are not counted as Jap.
                Positioned(
                  top: safeTop + vPad,
                  right: safeRight + hPad,
                  child: PopupMenuButton<String>(
                    tooltip: l.t('more'),
                    icon: const Icon(Icons.more_vert, color: Color(0xFF5A3A1A)),
                    onSelected: (v) {
                      if (v == 'mantra') _openMantraPicker();
                      if (v == 'end') _endSession();
                      if (v == 'reset') _confirmReset();
                    },
                    itemBuilder: (bc) => [
                      PopupMenuItem(
                        value: 'mantra',
                        child:
                            _menuRow(Icons.edit_outlined, l.t('selectMantra')),
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
                //    Each effect is confined to the dedicated strip, and fully
                //    inside the viewport, so a tap near an edge is still
                //    completely visible instead of being cut off.
                for (final g in _glows)
                  Positioned(
                    left: g.$2.dx.clamp(minCx, maxCx) - half,
                    top: g.$2.dy.clamp(minCy, maxCy) - half,
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
                _deityHeader(theme),
                // The dial is the focal point of the screen, so it leads the
                // content stack and everything else supports it. This is the
                // hierarchy the Stitch reference uses.
                _counter(theme, box),
                _malaBlock(theme, gap),
                _mantraTitle(theme, mantraHeight),
                _statsRow(theme),
                _goalBlock(theme, gap),
                _hint(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Deity caption directly under the artwork band.
  ///
  /// It names the deity whose artwork fills the band above, so the artwork is
  /// never an unexplained decoration, and it is drawn in that deity's own
  /// accent so the two read as one unit.
  Widget _deityHeader(ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          info.deityName,
          key: const Key('jap_deity_name'),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: DeityArtwork.tintFor(info.deityKey),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _mantraTitle(ThemeData theme, double height) => Row(
        children: [
          const SizedBox(width: _kMenuGutter),
          Expanded(
            child: SizedBox(
              height: height,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  mantra,
                  key: const Key('jap_mantra_name'),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  softWrap: true,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: mantraFontSize,
                    height: 1.15,
                    letterSpacing: 0.5,
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
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: const Color(0xFF8A6A3A), fontSize: 11),
          ),
        ],
      );

  Widget _counter(ThemeData theme, BoxConstraints box) {
    // The dial is sized against the height that is actually left below the
    // artwork band, not the full viewport, so it can never grow into the
    // artwork and never pushes the rows beneath it off a short screen.
    final ringSize =
        math.min(box.maxWidth * 0.60, box.maxHeight * 0.30).clamp(96.0, 300.0);
    return MalaRing(
      count: sessionState.count,
      total: kMalaSize,
      size: ringSize,
    );
  }

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
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: dayState.goalProgress,
                minHeight: 6,
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
  final photos = DeityPhotoStore();

  final nameCtrl = TextEditingController();
  final textCtrl = TextEditingController();

  /// Photo picked in the form but not yet copied into app storage.
  ///
  /// It is held here rather than imported on pick because the saved path is keyed
  /// by the mantra text, which the user may still be typing. Importing at save
  /// time means an abandoned form leaves nothing behind on disk.
  String? _stagedPhoto;

  List<CustomMantra> custom = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCustom();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    textCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustom() async {
    try {
      final all = await repo.custom();
      if (mounted) setState(() => custom = all);
    } catch (_) {
      // The picker is still usable without the stored list; it just cannot show
      // previously added names and photos.
      if (mounted) setState(() => custom = const []);
    }
  }

  /// The stored photo currently attached to [text], if it has one.
  ///
  /// Custom mantras are keyed by their text, so re-saving the same text edits
  /// the same row and this is the file that row used to point at.
  String? _photoFor(String text) {
    for (final m in custom) {
      if (m.text == text && m.hasPhoto) return m.photo;
    }
    return null;
  }

  Future<void> _pickPhoto() async {
    final l = AppLocalizations.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Deity art is displayed in a bounded band, so a very large source image
        // only costs memory.
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null || !mounted) return;
      setState(() => _stagedPhoto = picked.path);
    } catch (_) {
      // No gallery, no permission, or the picker failed: keep the mantra
      // savable without a photo.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.t('photoFailed'))));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = textCtrl.text.trim();
    if (text.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l.t('emptyMantra'))));
      return;
    }
    setState(() => _saving = true);

    String? stored;
    var photoSkipped = false;
    // The photo this mantra already had, if any. Saving without one, or with a
    // differently named file, must retire the old copy instead of orphaning it.
    final previous = _photoFor(text);
    if (_stagedPhoto != null) {
      try {
        stored = await photos.importPicked(_stagedPhoto!,
            mantra: text, replacing: previous);
      } catch (_) {
        // A moved, deleted or unsupported file must not cost the user the mantra
        // itself; it is saved without a photo and they are told why.
        stored = null;
        photoSkipped = true;
      }
    }

    try {
      await repo.addCustom(text,
          name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
          photo: stored);
    } catch (_) {
      // The row was not written, so the copied photo would be unreferenced.
      await photos.discard(stored);
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l.t('emptyMantra'))));
      return;
    }

    // The row now points at [stored], so the file it used to point at is dead.
    if (previous != null && previous != stored) {
      await photos.discard(previous);
    }

    if (!mounted) return;
    nameCtrl.clear();
    textCtrl.clear();
    setState(() {
      _saving = false;
      _stagedPhoto = null;
    });
    await _loadCustom();
    messenger.showSnackBar(
      SnackBar(
          content: Text(
              photoSkipped ? l.t('photoFailed') : l.t('customMantraAdded'))),
    );
  }

  Future<void> _delete(CustomMantra m) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text(l.t('deleteCustomMantra')),
        content: Text(l.t('deleteCustomMantraBody')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dc, false),
              child: Text(l.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(dc, true), child: Text(l.t('ok'))),
        ],
      ),
    );
    if (ok != true) return;
    await repo.deleteCustom(m.text);
    // Only ever removes the copy inside app storage, never the user's original.
    await photos.discard(m.photo);
    await _loadCustom();
  }

  @override
  Widget build(BuildContext c) {
    final app = InheritedAppState.of(c);
    final l = AppLocalizations.of(c);
    final builtIn = defaultMantras.map((e) => e[1]).toList();
    return Scaffold(
      appBar: AppBar(title: Text(l.t('selectMantra'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final m in builtIn)
            ListTile(
              title: Text(m, style: const TextStyle(fontSize: 18)),
              subtitle: Text(defaultMantras.firstWhere((e) => e[1] == m)[0]),
              selected: m == app.selectedMantra,
              onTap: () async {
                await app.setMantra(m);
                if (c.mounted) Navigator.pop(c);
              },
            ),
          for (final m in custom)
            ListTile(
              leading: _thumb(m),
              title: Text(m.label, style: const TextStyle(fontSize: 18)),
              subtitle: Text(m.text),
              selected: m.text == app.selectedMantra,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l.t('deleteCustomMantra'),
                onPressed: () => _delete(m),
              ),
              onTap: () async {
                await app.setMantra(m.text);
                if (c.mounted) Navigator.pop(c);
              },
            ),
          const Divider(height: 32),
          _editor(c, l),
        ],
      ),
    );
  }

  /// Round preview of a saved deity photo, or the neutral placeholder when the
  /// mantra has none or the file has since gone missing.
  Widget _thumb(CustomMantra m) {
    const size = 40.0;
    final box = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: m.hasPhoto
          ? Image.file(
              File(m.photo!),
              width: size,
              height: size,
              // Square container plus a hard crop: the photo is never stretched.
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const Icon(
                Icons.image_not_supported_outlined,
                size: 20,
                color: AppTheme.gold,
              ),
            )
          : const Icon(Icons.auto_awesome_outlined,
              size: 20, color: AppTheme.gold),
    );
    return box;
  }

  Widget _editor(BuildContext c, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.t('customMantra'),
                  style: Theme.of(c).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l.t('customMantraName'),
                  helperText: l.t('optional'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l.t('customMantraText'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(l.t('deityPhoto'), style: Theme.of(c).textTheme.labelLarge),
              const SizedBox(height: 8),
              _photoField(c, l),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(l.t('addCustomMantra')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Preview plus pick, replace and remove controls for the deity photo.
  Widget _photoField(BuildContext c, AppLocalizations l) {
    const size = 96.0;
    final staged = _stagedPhoto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
          ),
          child: staged == null
              ? const Icon(Icons.image_outlined, size: 32, color: AppTheme.gold)
              : Image.file(
                  File(staged),
                  width: size,
                  height: size,
                  // Cover inside a square box keeps the aspect ratio intact.
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const Icon(
                    Icons.broken_image_outlined,
                    size: 32,
                    color: AppTheme.gold,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                  staged == null ? l.t('choosePhoto') : l.t('replacePhoto')),
            ),
            if (staged != null)
              TextButton.icon(
                onPressed: () => setState(() => _stagedPhoto = null),
                icon: const Icon(Icons.delete_outline),
                label: Text(l.t('removePhoto')),
              ),
          ],
        ),
      ],
    );
  }
}
