import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/app_localizations.dart';
import 'core/services/app_state.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.load();
  await NotificationService.instance.init();
  runApp(JapMitraApp(appState: appState));
}

class JapMitraApp extends StatefulWidget {
  const JapMitraApp({super.key, required this.appState});
  final AppState appState;
  static JapMitraAppState of(BuildContext c) =>
      c.findAncestorStateOfType<JapMitraAppState>()!;
  @override
  State<JapMitraApp> createState() => JapMitraAppState();
}

class JapMitraAppState extends State<JapMitraApp> {
  @override
  void initState() {
    super.initState();
    // Every [AppState] mutation bumps a revision counter. Listening to it here
    // rebuilds the inherited scope, so a setting changed on one screen (for
    // example the mantra font size) is reflected everywhere at once instead of
    // waiting for the screen that changed it to be revisited.
    widget.appState.revision.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    widget.appState.revision.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  void refresh() => setState(() {});
  @override
  Widget build(BuildContext context) => InheritedAppState(
        state: widget.appState,
        child: MaterialApp(
          title: 'JapMitra',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: AppTheme.mode(widget.appState.themeMode),
          locale: Locale(widget.appState.languageCode),
          supportedLocales: const [Locale('hi'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        ),
      );
}

class InheritedAppState extends InheritedWidget {
  InheritedAppState({
    super.key,
    required this.state,
    required super.child,
  }) : _revision = state.revision.value;
  final AppState state;

  /// The revision this widget was built with.
  ///
  /// Reading the revision from both the old and the new widget would compare the
  /// same [AppState] instance with itself, which is always equal and so would
  /// never notify a dependent. The value is captured when the widget is built,
  /// so a rebuild after a change does notify.
  final int _revision;

  static AppState of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<InheritedAppState>()!.state;
  @override
  bool updateShouldNotify(covariant InheritedAppState old) =>
      _revision != old._revision;
}
