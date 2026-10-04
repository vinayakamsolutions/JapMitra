import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../main.dart';
import 'cities.dart';
import 'panchang_model.dart';

class PanchangScreen extends StatefulWidget {
  const PanchangScreen({super.key, this.initialMonth});

  /// Month to open on. Defaults to the current month; tests pass a fixed one so
  /// the grid is deterministic regardless of the day they run.
  final DateTime? initialMonth;

  @override
  State<PanchangScreen> createState() => _P();
}

class _P extends State<PanchangScreen> {
  static const _accent = Color(0xFFE87822);
  static const _gold = Color(0xFFB08040);

  /// Kept across rebuilds so revisiting a month is free, matching the
  /// repository's own cache.
  final _repo = PanchangRepository();

  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMonth;
    if (initial != null) month = DateTime(initial.year, initial.month);
  }

  /// The day whose detail is shown inline. Null until a month is loaded.
  int? selectedDay;

  PanchangMonthView? _view;
  int _loadToken = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load once per context change so the very first frame is not blank, and
    // again after the city changes.
    final city = InheritedAppState.of(context).city;
    if (_view == null || _viewCity != city) {
      _viewCity = city;
      _load();
    }
  }

  String? _viewCity;

  Future<void> _load() async {
    final token = ++_loadToken;
    final city = InheritedAppState.of(context).city;
    final view = await _repo.buildMonth(month, city);
    // A newer request may have started while this one awaited.
    if (!mounted || token != _loadToken) return;
    setState(() {
      _view = view;
      final today =
          DateUtils.isSameDay(month, DateTime.now()) ? DateTime.now().day : 1;
      // Keep the user's choice when it is still inside the month.
      selectedDay ??= today;
      if (selectedDay! > view.dayCount) selectedDay = view.dayCount;
      if (selectedDay! < 1) selectedDay = 1;
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      month = DateTime(month.year, month.month + delta);
      _view = null;
      selectedDay = null;
    });
    _load();
  }

  void _selectDay(int day) => setState(() => selectedDay = day);

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final ml = MaterialLocalizations.of(c);
    final state = InheritedAppState.of(c);
    final view = _view;
    return Scaffold(
      appBar: AppBar(
        title: Text('${l.t('panchang')} • ${state.city}'),
        actions: [
          IconButton(
            tooltip: l.t('city'),
            icon: const Icon(Icons.location_city),
            onPressed: () => _pickCity(c),
          ),
        ],
      ),
      body: view == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                _monthBar(c, l, ml, view),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    view.lunarMonthLabel(english: !l.isHindi),
                    style: Theme.of(c).textTheme.labelLarge?.copyWith(
                          color: _gold,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                _weekdayHeader(c, ml),
                const SizedBox(height: 4),
                _grid(c, l, view),
                const SizedBox(height: 16),
                _inlineDetail(c, l, view),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(l.t('panchangDisclaimer'),
                        style: Theme.of(c).textTheme.bodySmall),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _monthBar(BuildContext c, AppLocalizations l, MaterialLocalizations ml,
      PanchangMonthView view) {
    return Row(
      children: [
        IconButton(
          tooltip: l.t('prevDay'),
          onPressed: () => _shiftMonth(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(
              ml.formatMonthYear(view.month),
              style: Theme.of(c).textTheme.titleLarge,
            ),
          ),
        ),
        IconButton(
          tooltip: l.t('nextDay'),
          onPressed: () => _shiftMonth(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  /// Localized weekday captions, Sunday first to match the grid.
  Widget _weekdayHeader(BuildContext c, MaterialLocalizations ml) {
    final names = ml.narrowWeekdays;
    return Row(
      children: [
        for (final n in names)
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  n,
                  style: Theme.of(c).textTheme.labelSmall?.copyWith(
                        color: _gold,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _grid(BuildContext c, AppLocalizations l, PanchangMonthView view) {
    final today = DateUtils.dateOnly(DateTime.now());
    final cells = view.leadingBlanks + view.dayCount;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 0.82,
      ),
      itemCount: cells,
      itemBuilder: (c, i) {
        final day = i - view.leadingBlanks + 1;
        if (day < 1 || day > view.dayCount) return const SizedBox.shrink();
        return _dayCell(c, l, view.day(day), day,
            isToday: view.day(day)?.date == today,
            isSelected: day == selectedDay);
      },
    );
  }

  Widget _dayCell(
      BuildContext c, AppLocalizations l, PanchangDay? data, int day,
      {required bool isToday, required bool isSelected}) {
    final marked =
        data != null && (data.festivals.isNotEmpty || data.vrat.isNotEmpty);
    final fill = isSelected
        ? _accent
        : isToday
            ? _accent.withValues(alpha: 0.14)
            : null;
    final border = isSelected
        ? _accent
        : isToday
            ? _accent
            : Colors.transparent;
    final fg = isSelected
        ? Colors.white
        : isToday
            ? const Color(0xFF3E2415)
            : null;
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectDay(day),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: isSelected ? 2 : 1),
          ),
          child: Stack(
            children: [
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      '$day',
                      style: Theme.of(c).textTheme.titleMedium?.copyWith(
                            color: fg,
                            fontWeight:
                                isToday || isSelected ? FontWeight.w700 : null,
                          ),
                    ),
                  ),
                ),
              ),
              // Festival or vrat marker: the day matters even when the number
              // is small.
              if (marked)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.white : _gold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The selected day's detail, shown in place instead of pushing a page.
  Widget _inlineDetail(
      BuildContext c, AppLocalizations l, PanchangMonthView view) {
    final data = view.day(selectedDay ?? 1);
    if (data == null) return const SizedBox.shrink();
    final day = data.date;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (c, box) {
                final date = Text(
                  MaterialLocalizations.of(c).formatFullDate(day),
                  style: Theme.of(c).textTheme.titleMedium,
                );
                final button = TextButton(
                  onPressed: () => Navigator.push(
                    c,
                    MaterialPageRoute(
                        builder: (_) => DailyPanchang(initialDay: day)),
                  ),
                  child: Text(l.t('viewFullPanchang')),
                );
                // The localized button label is long enough to overflow beside
                // the date on a 320dp screen, so it drops to its own line rather
                // than being clipped.
                if (box.maxWidth < 300) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [date, button],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: date),
                    const SizedBox(width: 8),
                    button,
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            _festivalSection(c, l, data),
            const SizedBox(height: 12),
            _panchaGrid(c, l, data),
            const SizedBox(height: 12),
            _timings(c, l, data),
          ],
        ),
      ),
    );
  }

  /// Festival and vrat chips, with an honest empty state.
  Widget _festivalSection(BuildContext c, AppLocalizations l, PanchangDay p) {
    final chips = <String>[
      for (final f in p.festivals) _festivalName(l, p, f),
      for (final v in p.vrat) l.t(v),
    ];
    if (chips.isEmpty) {
      return Row(
        children: [
          const Icon(Icons.event_available_outlined, size: 18, color: _gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.t('noFestivalToday'),
              style: Theme.of(c).textTheme.bodySmall?.copyWith(color: _gold),
            ),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final t in chips)
          Chip(
            label: Text(t),
            backgroundColor: const Color(0xFFFFE8C9),
            labelStyle: const TextStyle(color: Color(0xFF3E2415), fontSize: 12),
          ),
      ],
    );
  }

  /// Tithi, nakshatra, yoga and karana as a 2x2 board.
  Widget _panchaGrid(BuildContext c, AppLocalizations l, PanchangDay p) {
    final h = l.isHindi;
    final tithi = h || p.tithiIndex == null
        ? p.tithi
        : PanchangDayEnglish.tithi(p.tithiIndex!);
    final paksha = h ? p.paksha : PanchangDayEnglish.paksha(p.tithiIndex ?? 1);
    final nakshatra = (h || p.nakshatraIndex == null
            ? p.nakshatra
            : PanchangNames.nakshatraEn[p.nakshatraIndex!]) ??
        '-';
    final yoga =
        h || p.yogaIndex == null ? p.yoga : PanchangNames.yogaEn[p.yogaIndex!];
    final karana = h || p.karanaIndex == null
        ? p.karana
        : PanchangNames.karanaNameEn(p.karanaIndex!);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.1,
      children: [
        _panchaTile(
            c, l.t('tithi'), '$tithi • $paksha', Icons.water_drop_outlined),
        _panchaTile(
            c,
            l.t('nakshatra'),
            p.nakshatraPada != null
                ? '$nakshatra /${p.nakshatraPada}'
                : nakshatra,
            Icons.nightlight_outlined),
        _panchaTile(c, l.t('yoga'), yoga ?? '-', Icons.self_improvement),
        _panchaTile(c, l.t('karana'), karana ?? '-', Icons.timelapse),
      ],
    );
  }

  Widget _panchaTile(
      BuildContext c, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.saffron.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: Theme.of(c)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: _gold)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Color(0xFF3E2415)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timings(BuildContext c, AppLocalizations l, PanchangDay p) {
    Widget row(String a, String? b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                  child: Text(a,
                      style: Theme.of(c)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: _gold))),
              Text(b ?? '-',
                  style: Theme.of(c)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.t('timings'), style: Theme.of(c).textTheme.labelLarge),
        const SizedBox(height: 6),
        row(l.t('sunrise'), p.sunrise),
        row(l.t('sunset'), p.sunset),
        row(l.t('moonrise'), p.moonrise),
        row(l.t('moonset'), p.moonset),
        row(l.t('rahuKaal'), p.rahuKaal),
        row(l.t('abhijitMuhurat'), p.abhijitMuhurat),
      ],
    );
  }

  String _festivalName(AppLocalizations l, PanchangDay p, String code) {
    if (code == 'sankranti' && p.sankrantiRashi != null) {
      final r = l.isHindi
          ? PanchangNames.rashi[p.sankrantiRashi!]
          : PanchangNames.rashiEn[p.sankrantiRashi!];
      return '$r ${l.t('sankranti')}';
    }
    return l.t(code);
  }

  Future<void> _pickCity(BuildContext c) async {
    final l = AppLocalizations.of(c);
    final state = InheritedAppState.of(c);
    final choice = await showModalBottomSheet<String>(
      context: c,
      builder: (bc) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.t('city'), style: Theme.of(bc).textTheme.titleMedium),
          ),
          for (final city in availableCities)
            ListTile(
              title: Text(city.name),
              subtitle: Text(city.state),
              trailing:
                  city.name == state.city ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(bc, city.name),
            ),
        ],
      ),
    );
    if (choice != null && choice != state.city) {
      await state.setCity(choice);
      if (!mounted) return;
      // The city decides every timing in the month, so it has to be rebuilt.
      setState(() {
        _view = null;
        _viewCity = null;
      });
      _load();
    }
  }
}

class DailyPanchang extends StatefulWidget {
  const DailyPanchang({super.key, required this.initialDay});
  final DateTime initialDay;
  @override
  State<DailyPanchang> createState() => _DP();
}

class _DP extends State<DailyPanchang> {
  late DateTime day = DateTime(
      widget.initialDay.year, widget.initialDay.month, widget.initialDay.day);
  PanchangDay? p;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(cityOf(context));
    });
  }

  String cityOf(BuildContext c) => InheritedAppState.of(c).city;

  void _load(String city) async {
    final result = await PanchangRepository().getDay(day, city);
    if (mounted) setState(() => p = result);
  }

  void _shift(int days) {
    setState(() {
      day = day.add(Duration(days: days));
      p = null;
    });
    _load(cityOf(context));
  }

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final md = MaterialLocalizations.of(c);
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${md.formatFullDate(day)} · ${p?.city ?? InheritedAppState.of(c).city}'),
        actions: [
          IconButton(
              tooltip: l.t('prevDay'),
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left)),
          IconButton(
              tooltip: l.t('today'),
              onPressed: () => _shift(0),
              icon: const Icon(Icons.today)),
          IconButton(
              tooltip: l.t('nextDay'),
              onPressed: () => _shift(1),
              icon: const Icon(Icons.chevron_right)),
        ],
      ),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sunCard(c, l, p!),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Color(0xFFB08040)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l.t('panchangDisclaimer'),
                            style: Theme.of(c).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF8A6A3A),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (p!.festivals.isNotEmpty)
                  _chipCard(c, l.t('festivalToday'), [
                    for (final f in p!.festivals) _festivalName(c, f),
                  ]),
                if (p!.vrat.isNotEmpty)
                  _chipCard(c, l.t('vrat'), [for (final v in p!.vrat) l.t(v)]),
                const SizedBox(height: 8),
                for (final row in _rows(c))
                  Card(
                    child: ListTile(
                      title: Text(
                        row.$1,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        row.$2 ?? '-',
                        style: const TextStyle(color: Color(0xFF5A3A1A)),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _festivalName(BuildContext c, String code) {
    final l = AppLocalizations.of(c);
    if (code == 'sankranti' && p?.sankrantiRashi != null) {
      final r = PanchangNames.rashi[p!.sankrantiRashi!];
      final rEn = PanchangNames.rashiEn[p!.sankrantiRashi!];
      return l.isHindi ? '$r ${l.t('sankranti')}' : '$rEn ${l.t('sankranti')}';
    }
    return l.t(code);
  }

  Widget _sunCard(BuildContext c, AppLocalizations l, PanchangDay p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _sunItem(c, Icons.wb_sunny, l.t('sunrise'),
                  p.sunrise ?? '--', const Color(0xFFE87822)),
            ),
            Container(width: 1, height: 40, color: const Color(0xFFF0E6D2)),
            Expanded(
              child: _sunItem(c, Icons.nightlight, l.t('sunset'),
                  p.sunset ?? '--', const Color(0xFF8A6A3A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sunItem(
      BuildContext c, IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(c).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3E2415),
              ),
        ),
        Text(
          label,
          style: Theme.of(c).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8A6A3A),
              ),
        ),
      ],
    );
  }

  Widget _chipCard(BuildContext c, String title, List<String> items) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(c).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in items)
                    Chip(
                      label: Text(item),
                      backgroundColor: const Color(0xFFFFE8C9),
                      labelStyle: const TextStyle(color: Color(0xFF3E2415)),
                    ),
                ],
              ),
            ],
          ),
        ),
      );

  List<(String, String?)> _rows(BuildContext c) {
    final l = AppLocalizations.of(c);
    final h = l.isHindi;
    final tithiNam = h || p!.tithiIndex == null
        ? p!.tithi
        : PanchangDayEnglish.tithi(p!.tithiIndex!);
    final pakshaNam =
        h ? p!.paksha : PanchangDayEnglish.paksha(p!.tithiIndex ?? 1);
    final nks = h || p!.nakshatraIndex == null
        ? p!.nakshatra
        : PanchangNames.nakshatraEn[p!.nakshatraIndex!];
    final yogaNam = h || p!.yogaIndex == null
        ? p!.yoga
        : PanchangNames.yogaEn[p!.yogaIndex!];
    final karanaNam = h || p!.karanaIndex == null
        ? p!.karana
        : PanchangNames.karanaNameEn(p!.karanaIndex!);
    final tithiEnd = p!.tithiEnd;
    return [
      (l.t('tithi'), tithiEnd != null ? '$tithiNam • $tithiEnd' : tithiNam),
      (l.t('paksha'), pakshaNam),
      (
        l.t('nakshatra'),
        p!.nakshatraPada != null ? '$nks /${p!.nakshatraPada}' : nks
      ),
      (l.t('yoga'), yogaNam),
      (l.t('karana'), karanaNam),
      (l.t('sunrise'), p!.sunrise),
      (l.t('sunset'), p!.sunset),
      (l.t('moonrise'), p!.moonrise),
      (l.t('moonset'), p!.moonset),
      (l.t('rahuKaal'), p!.rahuKaal),
      (l.t('yamaganda'), p!.yamaganda),
      (l.t('gulika'), p!.gulika),
      (l.t('abhijitMuhurat'), p!.abhijitMuhurat),
      if (p!.sankranti != null) (l.t('sankranti'), p!.sankranti),
    ];
  }
}
