import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../main.dart';
import 'cities.dart';
import 'panchang_model.dart';

class PanchangScreen extends StatefulWidget {
  const PanchangScreen({super.key});
  @override
  State<PanchangScreen> createState() => _P();
}

class _P extends State<PanchangScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final today = DateTime.now();
    final ml = MaterialLocalizations.of(c);
    return Scaffold(
      appBar: AppBar(
        title: Text('${l.t('panchang')} • ${InheritedAppState.of(c).city}'),
        actions: [
          IconButton(
            tooltip: l.t('city'),
            icon: const Icon(Icons.location_city),
            onPressed: () => _pickCity(c),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(
                    () => month = DateTime(month.year, month.month - 1)),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(ml.formatMonthYear(month),
                  style: Theme.of(c).textTheme.titleLarge),
              IconButton(
                onPressed: () => setState(
                    () => month = DateTime(month.year, month.month + 1)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemCount: days,
            itemBuilder: (c, i) {
              final d = DateTime(month.year, month.month, i + 1);
              final isToday = d.year == today.year &&
                  d.month == today.month &&
                  d.day == today.day;
              return Card(
                color: isToday ? const Color(0xFFE87822) : null,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(
                          builder: (_) => DailyPanchang(initialDay: d))),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: Theme.of(c)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: isToday ? Colors.white : null),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l.t('panchangDisclaimer')),
            ),
          ),
        ],
      ),
    );
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
      if (mounted) setState(() {});
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
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(l.t('panchangDisclaimer')),
                  ),
                ),
                if (p!.festivals.isNotEmpty)
                  _chipCard(c, l.t('festivalToday'), [
                    for (final f in p!.festivals) _festivalName(c, f),
                  ]),
                if (p!.vrat.isNotEmpty)
                  _chipCard(c, l.t('vrat'), [for (final v in p!.vrat) l.t(v)]),
                for (final row in _rows(c))
                  Card(
                      child: ListTile(
                          title: Text(row.$1), subtitle: Text(row.$2 ?? '-'))),
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
        p!.nakshatraPada != null ? '$nks /$p!.nakshatraPada' : nks
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
