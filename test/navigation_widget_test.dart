import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:japmitra/core/localization/app_localizations.dart';
import 'package:japmitra/core/services/app_state.dart';
import 'package:japmitra/features/home/shell.dart';
import 'package:japmitra/main.dart';

void main() {
  testWidgets('bottom navigation renders', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final prefs = await SharedPreferences.getInstance();
    final appState = AppState();
    appState.prefs = prefs;

    await tester.pumpWidget(
      InheritedAppState(
        state: appState,
        child: const MaterialApp(
          locale: Locale('hi'),
          supportedLocales: [
            Locale('hi'),
            Locale('en'),
          ],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Shell(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
