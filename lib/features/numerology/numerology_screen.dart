import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../main.dart';
import 'numerology_service.dart';

class NumerologyScreen extends StatefulWidget {
  const NumerologyScreen({super.key});
  @override
  State<NumerologyScreen> createState() => _N();
}

class _N extends State<NumerologyScreen> {
  final svc = NumerologyService();

  /// The date the reading is requested for. Defaults to the real current date.
  late DateTime _day = _today();

  /// Set only by pressing the calculate button, so a result always belongs to a
  /// date the user can see.
  NumerologyInsight? _result;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A returning user with a saved date of birth sees their reading straight
    // away; the button below recomputes it for a different date.
    if (_result == null) {
      final dob = InheritedAppState.of(context).dob;
      // A stored date can be unusable (out of range, or in the future if the
      // device clock was wrong when it was saved). Show nothing rather than
      // crash, and let the calculate button explain the problem on demand.
      if (dob != null) {
        try {
          _result = svc.insight(dob, day: _day);
        } on ArgumentError {
          _result = null;
        }
      }
    }
  }

  Future<void> _pickDob() async {
    final app = InheritedAppState.of(context);
    final dob = app.dob;
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDate: dob ?? DateTime(2000),
    );
    if (d == null) return;
    await app.setDob(d);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: _today(),
      initialDate: _day,
    );
    if (d == null) return;
    if (!mounted) return;
    setState(() {
      _day = DateTime(d.year, d.month, d.day);
      // The previous reading belonged to the previous date.
      _result = null;
    });
  }

  /// Explicit calculation: validates the input, then derives every number from
  /// it. Nothing is shown that was not computed here.
  void _calculate() {
    final l = AppLocalizations.of(context);
    final app = InheritedAppState.of(context);
    final dob = app.dob;
    if (dob == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.t('setDob'))));
      return;
    }
    try {
      final result = svc.insight(dob, day: _day);
      setState(() => _result = result);
    } on ArgumentError catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message.toString())));
    }
  }

  @override
  Widget build(BuildContext c) {
    final app = InheritedAppState.of(c);
    final l = AppLocalizations.of(c);
    final dob = app.dob;
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: Text(l.t('numerology'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFB08040)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.t('notSci'),
                      style: Theme.of(c).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8A6A3A),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _pickDob,
            icon: const Icon(Icons.cake),
            label: Text(
              dob == null
                  ? l.t('setDob')
                  : '${l.t('dobPrefix')}${dob.day}/${dob.month}/${dob.year}',
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event, color: Color(0xFF8A6A3A)),
            title: Text(
                '${l.t('forDate')}: ${_day.day}/${_day.month}/${_day.year}'),
            onTap: _pickDay,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _calculate,
            icon: const Icon(Icons.calculate_outlined),
            label: Text(l.t('calculateNumerology')),
          ),
          const SizedBox(height: 16),
          if (result == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l.t('setDob'),
                textAlign: TextAlign.center,
                style: Theme.of(c)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: const Color(0xFFA08060)),
              ),
            )
          else ...[
            _resultCard(c, l.t('birthNumber'), '${result.birthNumber}'),
            _resultCard(c, l.t('lifePath'), '${result.lifePathNumber}'),
            _resultCard(c, l.t('todayNumber'), '${result.todayNumber}'),
            _resultCard(c, l.t('luckyNumber'), '${result.luckyNumber}'),
            _resultCard(c, l.t('luckyColour'), result.luckyColour,
                note: l.t('traditionalNote'), valueIsText: true),
            _resultCard(c, l.t('dailyGuidance'), result.dailyGuidance,
                note: l.t('traditionalNote'), valueIsText: true),
          ],
          if (dob != null) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () async {
                  await app.setDob(null);
                  if (!mounted) return;
                  setState(() => _result = null);
                },
                child: Text(l.t('deleteDob')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One result row.
  ///
  /// A short value such as a number sits in the trailing slot, where it can be
  /// read at a glance. A long value, such as a colour name or a sentence, is
  /// laid out as text in the body instead: a long trailing widget would claim
  /// the whole tile width and fail to lay out on a narrow screen.
  Widget _resultCard(
    BuildContext c,
    String title,
    String value, {
    String? note,
    bool valueIsText = false,
  }) =>
      Card(
        child: ListTile(
          leading: const Icon(Icons.numbers, color: Color(0xFFE87822)),
          title: Text(title),
          subtitle: !valueIsText
              ? (note == null
                  ? null
                  : Text(note,
                      style: const TextStyle(color: Color(0xFF8A6A3A))))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value),
                    if (note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(note,
                            style: const TextStyle(
                              color: Color(0xFF8A6A3A),
                              fontSize: 12,
                            )),
                      ),
                  ],
                ),
          trailing: valueIsText
              ? null
              : Text(
                  value,
                  style: Theme.of(c).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3E2415),
                      ),
                ),
        ),
      );
}
