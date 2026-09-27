import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../main.dart';
import 'rashifal_model.dart';

/// The twelve zodiac signs, in the traditional order.
///
/// [key] is the stable identifier used for storage, [1] the Devanagari name and
/// [2] the Latin name. Sign names are proper nouns and are shown in both
/// scripts, exactly as they are written, in Hindi and English alike.
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

class RashifalScreen extends StatelessWidget {
  const RashifalScreen({super.key});

  @override
  Widget build(BuildContext c) {
    final app = InheritedAppState.of(c);
    final l = AppLocalizations.of(c);
    final selected = signForKey(app.rashiSign);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('rashifal'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Honest scope notice: what this screen can and cannot tell the user.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFB08040)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.t('rashifalUnavailableNote'),
                      style: Theme.of(c)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: const Color(0xFF8A6A3A)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _mySignCard(c, l, selected),
          const SizedBox(height: 8),
          for (final s in signs)
            _signTile(c, l, s,
                selected: selected != null && s[0] == selected[0]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// The currently chosen sign, or a prompt to choose one.
  Widget _mySignCard(
          BuildContext c, AppLocalizations l, List<String>? selected) =>
      Card(
        color: const Color(0xFFFFF6E6),
        child: ListTile(
          leading: const Icon(Icons.star_outline, color: Color(0xFFB08040)),
          title: Text(l.t('myRashi')),
          subtitle: Text(
            selected == null
                ? l.t('rashiNotSetNote')
                : '${selected[1]} / ${selected[2]}',
            style: TextStyle(
              fontWeight:
                  selected == null ? FontWeight.normal : FontWeight.w600,
            ),
          ),
          trailing: selected == null
              ? null
              : IconButton(
                  tooltip: l.t('clearMySign'),
                  icon: const Icon(Icons.close),
                  onPressed: () => InheritedAppState.of(c).setRashiSign(null),
                ),
        ),
      );

  Widget _signTile(
    BuildContext c,
    AppLocalizations l,
    List<String> s, {
    required bool selected,
  }) =>
      Card(
        color: selected ? const Color(0xFFFFF1DA) : null,
        child: ListTile(
          leading: Text(s[3], style: const TextStyle(fontSize: 28)),
          title: Text(
            '${s[1]} / ${s[2]}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(l.t('guidanceOnly')),
          trailing: selected
              ? const Icon(Icons.check_circle, color: Color(0xFFE87822))
              : const Icon(Icons.chevron_right),
          onTap: () => _open(c, s),
        ),
      );

  /// Remembers the sign, then shows its detail page.
  Future<void> _open(BuildContext c, List<String> s) async {
    // Storing first means the tile is highlighted the moment the user comes
    // back, on any screen, in either language.
    await InheritedAppState.of(c).setRashiSign(s[0]);
    if (!c.mounted) return;
    await Navigator.push(
      c,
      MaterialPageRoute(builder: (_) => RashiDetail(sign: s)),
    );
  }
}

class RashiDetail extends StatelessWidget {
  const RashiDetail({super.key, required this.sign});
  final List<String> sign;

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final isMine = InheritedAppState.of(c).rashiSign == sign[0];
    return Scaffold(
      appBar: AppBar(title: Text('${sign[1]} / ${sign[2]}')),
      body: FutureBuilder<RashiContent>(
        future: const RashifalRepository().getToday(sign[0]),
        builder: (c, snap) {
          final r = snap.data ?? RashiContent(signKey: sign[0]);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(c, l, isMine),
              const SizedBox(height: 12),
              if (r.hasContent)
                ..._verifiedRows(c, l, r)
              else
                _unavailable(c, l),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext c, AppLocalizations l, bool isMine) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(sign[3], style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${sign[1]} / ${sign[2]}',
                      style: Theme.of(c).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.t('guidanceOnly'),
                      style: Theme.of(c).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFA08060),
                          ),
                    ),
                    if (isMine) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 16, color: Color(0xFFE87822)),
                          const SizedBox(width: 4),
                          Text(
                            l.t('myRashi'),
                            style: const TextStyle(
                              color: Color(0xFFE87822),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  /// Shown when a verified reading is available for today.
  List<Widget> _verifiedRows(
      BuildContext c, AppLocalizations l, RashiContent r) {
    final rows = <String, String?>{
      l.t('general'): r.general,
      l.t('career'): r.career,
      l.t('finance'): r.finance,
      l.t('relationships'): r.relationships,
      l.t('health'): r.health,
      l.t('luckyNumber'): r.luckyNumber,
      l.t('luckyColour'): r.luckyColour,
      l.t('dailyGuidance'): r.dailyGuidance,
    }..removeWhere((_, v) => v == null);
    return [
      for (final e in rows.entries)
        Card(
          child: ListTile(title: Text(e.key), subtitle: Text(e.value!)),
        ),
    ];
  }

  /// Shown when no verified reading exists: a clear, honest explanation rather
  /// than empty fields dressed up as a prediction.
  Widget _unavailable(BuildContext c, AppLocalizations l) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 40, color: Color(0xFFB08040)),
              const SizedBox(height: 12),
              Text(
                l.t('unavailable'),
                style: Theme.of(c).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l.t('rashifalUnavailableNote'),
                textAlign: TextAlign.center,
                style: Theme.of(c)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: const Color(0xFF8A6A3A)),
              ),
              const SizedBox(height: 12),
              Text(
                l.t('guidanceOnly'),
                textAlign: TextAlign.center,
                style: Theme.of(c).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFA08060),
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
      );
}
