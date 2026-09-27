import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/app_state.dart';
import '../../core/services/feedback_service.dart';
import '../../core/services/notification_service.dart';
import '../../main.dart';
import '../numerology/numerology_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});
  @override
  State<MoreScreen> createState() => _More();
}

class _More extends State<MoreScreen> {
  Future<void> _setReminder(bool enabled) async {
    final app = InheritedAppState.of(context);
    final l = AppLocalizations.of(context);
    if (enabled) {
      final ok = await NotificationService.instance.requestPermission();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('permissionDenied'))),
        );
        return;
      }
      await NotificationService.instance.scheduleDailyJapReminder(
        hour: app.japReminderHour,
        minute: app.japReminderMinute,
        title: 'JapMitra',
        body: l.t('notifBody'),
      );
    } else {
      await NotificationService.instance.cancelDailyJapReminder();
    }
    await app.setJapReminder(
      enabled: enabled,
      hour: app.japReminderHour,
      minute: app.japReminderMinute,
    );
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext c) {
    final app = InheritedAppState.of(c);
    final l = AppLocalizations.of(c);
    return Scaffold(
      appBar: AppBar(title: Text(l.t('more'))),
      body: ListView(
        children: [
          _sectionHeader(c, l.t('jap')),
          ListTile(
            leading: const Icon(Icons.numbers),
            title: Text(l.t('numerology')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                c, MaterialPageRoute(builder: (_) => const NumerologyScreen())),
          ),
          ListTile(
            title: Text(l.t('goal')),
            trailing: DropdownButton<int>(
              value: app.dailyGoal,
              items: [108, 216, 540, 1008]
                  .map((e) => DropdownMenuItem(
                      value: e, child: Text(e == 540 ? '5 Mala' : '$e')))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                await app.setGoal(v);
                if (!mounted) return;
                setState(() {});
              },
            ),
          ),
          _sectionHeader(c, l.t('reminder')),
          SwitchListTile(
            value: app.japReminderEnabled,
            onChanged: _setReminder,
            title: Text(l.t('reminder')),
            subtitle: Text(
              '${app.japReminderHour.toString().padLeft(2, '0')}:${app.japReminderMinute.toString().padLeft(2, '0')}',
            ),
          ),
          ListTile(
            title: Text(l.t('reminderTime')),
            leading: const Icon(Icons.schedule),
            enabled: app.japReminderEnabled,
            onTap: () async {
              final picked = await showTimePicker(
                context: c,
                initialTime: TimeOfDay(
                    hour: app.japReminderHour, minute: app.japReminderMinute),
              );
              if (picked == null) return;
              await app.setJapReminder(
                enabled: app.japReminderEnabled,
                hour: picked.hour,
                minute: picked.minute,
              );
              if (app.japReminderEnabled) {
                await NotificationService.instance.scheduleDailyJapReminder(
                  hour: picked.hour,
                  minute: picked.minute,
                  title: 'JapMitra',
                  body: l.t('notifBody'),
                );
              }
              if (!mounted) return;
              setState(() {});
            },
          ),
          SwitchListTile(
            value: app.reminderVibration,
            onChanged: (v) async {
              await app.setReminderVibration(v);
              if (!mounted) return;
              setState(() {});
            },
            title: Text(l.t('reminderVibration')),
          ),
          SwitchListTile(
            value: app.reminderSound,
            onChanged: (v) async {
              await app.setReminderSound(v);
              if (!mounted) return;
              setState(() {});
            },
            title: Text(l.t('reminderSound')),
          ),
          _sectionHeader(c, l.t('vibration')),
          _radioOption(
            c,
            l,
            title: l.t('vibrationOff'),
            value: FeedbackModes.vibOff,
            groupValue: app.vibrationMode,
            onChanged: (v) async {
              await app.setVibrationMode(v!);
              if (!mounted) return;
              setState(() {});
            },
          ),
          _radioOption(
            c,
            l,
            title: l.t('vibrationEvery'),
            value: FeedbackModes.vibEvery,
            groupValue: app.vibrationMode,
            onChanged: (v) async {
              await app.setVibrationMode(v!);
              if (!mounted) return;
              setState(() {});
            },
          ),
          _radioOption(
            c,
            l,
            title: l.t('vibrationEvery10'),
            value: FeedbackModes.vibEvery10,
            groupValue: app.vibrationMode,
            onChanged: (v) async {
              await app.setVibrationMode(v!);
              if (!mounted) return;
              setState(() {});
            },
          ),
          _radioOption(
            c,
            l,
            title: l.t('vibrationMala'),
            value: FeedbackModes.vibMala,
            groupValue: app.vibrationMode,
            onChanged: (v) async {
              await app.setVibrationMode(v!);
              if (!mounted) return;
              setState(() {});
            },
          ),
          _sectionHeader(c, l.t('sound')),
          _radioOption(
            c,
            l,
            title: l.t('soundOff'),
            value: FeedbackModes.soundOff,
            groupValue: app.soundMode,
            onChanged: (v) async {
              await app.setSoundMode(v!);
              if (!mounted) return;
              setState(() {});
            },
          ),
          _radioOption(
            c,
            l,
            title: l.t('bell'),
            value: FeedbackModes.soundBell,
            groupValue: app.soundMode,
            onChanged: (v) async {
              await app.setSoundMode(v!);
              if (!mounted) return;
              setState(() {});
            },
          ),
          _radioOption(
            c,
            l,
            title: l.t('softBell'),
            value: FeedbackModes.soundSoftBell,
            groupValue: app.soundMode,
            onChanged: (v) async {
              await app.setSoundMode(v!);
              if (!mounted) return;
              setState(() {});
            },
          ),
          _sectionHeader(c, l.t('language')),
          ListTile(
            title: Text(l.t('language')),
            trailing: DropdownButton<String>(
              value: app.languageCode,
              items: const [
                DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await app.setLang(v);
                if (!c.mounted) return;
                JapMitraApp.of(c).refresh();
              },
            ),
          ),
          ListTile(
            title: Text(l.t('city')),
            subtitle: Text(app.city),
            leading: const Icon(Icons.location_city),
            onTap: () async {
              final ctrl = TextEditingController(text: app.city);
              final v = await showDialog<String>(
                context: c,
                builder: (dc) => AlertDialog(
                  title: Text(l.t('city')),
                  content: TextField(controller: ctrl),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dc),
                        child: Text(l.t('cancel'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(dc, ctrl.text),
                        child: Text(l.t('ok'))),
                  ],
                ),
              );
              if (v != null && v.isNotEmpty) {
                await app.setCity(v);
                if (!mounted) return;
                setState(() {});
              }
            },
          ),
          _sectionHeader(c, l.t('mantraFontSize')),
          for (var i = 0; i < kMantraFontSizes.length; i++)
            _mantraSizeOption(c, l, index: i),
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
            child: Text(
              l.t('mantraFontSizeNote'),
              style: Theme.of(c)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xFF8A6A3A)),
            ),
          ),
          _sectionHeader(c, l.t('theme')),
          _radioOption(
            c,
            l,
            title: l.t('themeLight'),
            value: 'light',
            groupValue: app.themeMode,
            onChanged: (v) async {
              await app.setThemeMode(v!);
              if (!mounted) return;
              setState(() {});
              if (mounted) JapMitraApp.of(context).refresh();
            },
          ),
          _radioOption(
            c,
            l,
            title: l.t('themeDark'),
            value: 'dark',
            groupValue: app.themeMode,
            onChanged: (v) async {
              await app.setThemeMode(v!);
              if (!mounted) return;
              setState(() {});
              if (mounted) JapMitraApp.of(context).refresh();
            },
          ),
          _radioOption(
            c,
            l,
            title: l.t('themeSystem'),
            value: 'system',
            groupValue: app.themeMode,
            onChanged: (v) async {
              await app.setThemeMode(v!);
              if (!mounted) return;
              setState(() {});
              if (mounted) JapMitraApp.of(context).refresh();
            },
          ),
          _sectionHeader(c, l.t('about')),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l.t('about')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAbout(c),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l.t('privacy')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showPrivacy(c),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l.t('terms')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTerms(c),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: Text(l.t('contactFeedback')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _contactFeedback(c),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext c, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(c).textTheme.labelSmall?.copyWith(
                color: const Color(0xFFB08040),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
        ),
      );

  /// One mantra size preset, previewed with the user's own mantra so the effect
  /// of each choice is visible before leaving the screen.
  ///
  /// Selecting a preset writes only the visual size. Tap counting, progress and
  /// the stored count are not involved.
  Widget _mantraSizeOption(
    BuildContext c,
    AppLocalizations l, {
    required int index,
  }) {
    final app = InheritedAppState.of(c);
    final selected = app.mantraFontSizeIndex == index;
    return ListTile(
      leading: const Icon(Icons.format_size),
      title: Text(_mantraSizeLabel(l, index)),
      subtitle: Text(
        app.selectedMantra,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: kMantraFontSizes[index], height: 1.2),
      ),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? const Color(0xFFE87822) : Theme.of(c).disabledColor,
      ),
      selected: selected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () => _setMantraFontSize(index),
    );
  }

  Future<void> _setMantraFontSize(int? index) async {
    if (index == null) return;
    final app = InheritedAppState.of(context);
    await app.setMantraFontSizeIndex(index);
    if (!mounted) return;
    setState(() {});
  }

  String _mantraSizeLabel(AppLocalizations l, int index) {
    switch (index) {
      case 0:
        return l.t('sizeSmall');
      case 1:
        return l.t('sizeMedium');
      case 2:
        return l.t('sizeLarge');
      default:
        return l.t('sizeExtraLarge');
    }
  }

  Widget _radioOption(
    BuildContext c,
    AppLocalizations l, {
    required String title,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) =>
      ListTile(
        leading: Radio<String>(
          value: value,
          groupValue: groupValue,
          onChanged: onChanged,
        ),
        title: Text(title),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: () => onChanged(value),
      );

  void _showAbout(BuildContext c) {
    final l = AppLocalizations.of(c);
    showAboutDialog(
      context: c,
      applicationName: 'JapMitra',
      applicationVersion: '1.0.0',
      applicationIcon: const SizedBox(
        width: 56,
        height: 56,
        child: Image(image: AssetImage('assets/branding/japmitra_logo.png')),
      ),
      children: [
        Text(l.t('tag')),
        const SizedBox(height: 8),
        Text(l.t('made')),
        const SizedBox(height: 8),
        Text(l.t('aboutDesc')),
      ],
    );
  }

  void _showPrivacy(BuildContext c) {
    final l = AppLocalizations.of(c);
    Navigator.push(
        c,
        MaterialPageRoute(
            builder: (_) =>
                _InfoPage(title: l.t('privacy'), body: l.t('privacyBody'))));
  }

  void _showTerms(BuildContext c) {
    final l = AppLocalizations.of(c);
    Navigator.push(
        c,
        MaterialPageRoute(
            builder: (_) =>
                _InfoPage(title: l.t('terms'), body: l.t('termsBody'))));
  }

  void _contactFeedback(BuildContext c) {
    final l = AppLocalizations.of(c);
    Navigator.push(
      c,
      MaterialPageRoute(
        builder: (_) => _InfoPage(
          title: l.t('contactFeedback'),
          body: l.t('contactFeedbackBody'),
        ),
      ),
    );
  }
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(body, style: Theme.of(c).textTheme.bodyLarge),
              ),
            ),
          ],
        ),
      );
}
