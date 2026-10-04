import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:japmitra/core/localization/app_localizations.dart';
import 'package:japmitra/core/services/app_state.dart';
import 'package:japmitra/features/astrologer/astrologer_model.dart';
import 'package:japmitra/features/astrologer/astrologer_profile_screen.dart';
import 'package:japmitra/features/astrologer/consultation_service.dart';
import 'package:japmitra/features/home/home_screen.dart';
import 'package:japmitra/main.dart';

/// Records the URIs the screen tries to open, so the tests assert the exact
/// intent instead of touching a real dialler.
class RecordingLauncher {
  final List<Uri> opened = [];
  bool result = true;
  Object? throwInstead;

  Future<bool> call(Uri uri,
      {LaunchMode mode = LaunchMode.platformDefault}) async {
    opened.add(uri);
    if (throwInstead != null) throw throwInstead!;
    return result;
  }
}

Widget _app(Widget child, AppState state,
        {Locale locale = const Locale('hi')}) =>
    InheritedAppState(
      state: state,
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('hi'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );

Future<AppState> _state({String language = 'hi'}) async {
  SharedPreferences.setMockInitialValues({'lang': language});
  final prefs = await SharedPreferences.getInstance();
  final st = AppState();
  st.prefs = prefs;
  st.languageCode = language;
  return st;
}

/// The profile and Home bodies are scrollable lists, so anything below the fold
/// has to be reached before it can be asserted on.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 220);
  await tester.pumpAndSettle();
}

void main() {
  group('Astrologer profile data', () {
    test('carries only the published details', () {
      const a = featuredAstrologer;
      expect(a.name, 'Abhijeet Srivastava');
      expect(a.title, 'Acharya');
      expect(a.experience, '21+ Years Experience');
      expect(a.specialities, contains('Kundli'));
      expect(a.specialities, contains('Vedic Astrology'));
      expect(a.specialities, contains('Numerology'));
      expect(a.specialities, contains('Palmistry'));
      expect(a.specialities, contains('Tantra-Mantra Specialist'));
      expect(a.languageNames, ['Hindi', 'English']);
      expect(a.city, 'Lucknow');
      expect(a.consultationMinutes, 5);
      expect(a.fee, 501);
      expect(a.availableDaysLabel, '7 Days a Week');
      expect(a.availableHours, '10:00 AM – 6:00 PM');
    });

    test('exposes a dialable number with no formatting', () {
      expect(featuredAstrologer.phoneDigits, '9170735312');
    });

    test('uses the approved photograph, with a monogram as the fallback', () {
      // The published consultant has an approved, bundled photograph. The file
      // is a JPEG, so it must keep a .jpg extension: Flutter silently drops a
      // binary asset whose content does not match its extension.
      expect(featuredAstrologer.photoAsset,
          'assets/images/astrologer/abhijeet_srivastava.jpg');
      expect(AstrologerArtwork.assetFor(featuredAstrologer.id),
          featuredAstrologer.photoAsset);
      // The monogram is still the fallback for a consultant with no approved
      // photograph: initials, never an invented likeness.
      expect(featuredAstrologer.monogram, 'AS');
    });

    test('the bundled photograph really is a decodable image', () {
      // Guards the extension/content mismatch above, which would otherwise only
      // show up as a missing image at runtime.
      final bytes = File('assets/images/astrologer/abhijeet_srivastava.jpg')
          .readAsBytesSync();
      expect(bytes.length, greaterThan(1024));
      // JPEG start-of-image marker.
      expect(bytes[0], 0xFF);
      expect(bytes[1], 0xD8);
    });

    test('registers a photograph only for a consultant that declares one', () {
      AstrologerArtwork.register(
          'nobody', 'assets/images/astrologer/nobody.png');
      expect(AstrologerArtwork.assetFor('nobody'),
          'assets/images/astrologer/nobody.png');
      expect(AstrologerArtwork.assetFor('someone-else'), isNull);
    });
  });

  group('Consultation intents', () {
    test('call opens the dialler for the number', () async {
      final launcher = RecordingLauncher();
      final result = await ConsultationService(launcher: launcher.call)
          .call(featuredAstrologer);

      expect(result, ContactResult.launched);
      expect(launcher.opened.single.toString(), 'tel:9170735312');
    });

    test('whatsapp opens wa.me for the number', () async {
      final launcher = RecordingLauncher();
      final result = await ConsultationService(launcher: launcher.call)
          .whatsapp(featuredAstrologer);

      expect(result, ContactResult.launched);
      expect(launcher.opened.single.toString(), 'https://wa.me/9170735312');
    });

    test('reports when no app can handle the intent', () async {
      final launcher = RecordingLauncher()..result = false;
      expect(
          await ConsultationService(launcher: launcher.call)
              .call(featuredAstrologer),
          ContactResult.noApp);
    });

    test('never throws out of the service', () async {
      final launcher = RecordingLauncher()..throwInstead = StateError('boom');
      expect(
          await ConsultationService(launcher: launcher.call)
              .call(featuredAstrologer),
          ContactResult.failed);
    });
  });

  group('Astrologer profile screen', () {
    testWidgets('shows the consultant, availability and fee', (tester) async {
      final state = await _state();
      await tester.pumpWidget(_app(const AstrologerProfileScreen(), state));
      await tester.pumpAndSettle();

      expect(find.text('Abhijeet Srivastava'), findsOneWidget);
      expect(find.text('21+ Years Experience'), findsOneWidget);
      expect(find.textContaining('Acharya'), findsOneWidget);
      expect(find.text('Kundli'), findsOneWidget);
      expect(find.text('Tantra-Mantra Specialist'), findsOneWidget);
      // The approved photograph is bundled, so the profile shows it rather than
      // falling back to the monogram.
      expect(find.byKey(const Key('astro_photo')), findsOneWidget);
      expect(find.byKey(const Key('astro_monogram')), findsNothing);

      await _scrollTo(tester, find.text('Hindi, English'));
      expect(find.text('7 Days a Week • 10:00 AM – 6:00 PM'), findsOneWidget);
      expect(find.text('Lucknow'), findsOneWidget);

      await _scrollTo(tester, find.byKey(const Key('astro_fee')));
      expect(find.text('₹501'), findsOneWidget);
      expect(find.text('• 5 मिनट'), findsOneWidget);
    });

    testWidgets('keeps the call actions on screen without scrolling',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = await _state();
      await tester.pumpWidget(_app(const AstrologerProfileScreen(), state));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('astro_call_button')), findsOneWidget);
      expect(find.byKey(const Key('astro_whatsapp_button')), findsOneWidget);
      expect(find.byKey(const Key('astro_no_booking')), findsOneWidget);
    });

    testWidgets('states plainly that no payment happens in the app',
        (tester) async {
      final state = await _state();
      await tester.pumpWidget(_app(const AstrologerProfileScreen(), state));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('astro_no_booking')), findsOneWidget);
      expect(find.textContaining('भुगतान'), findsOneWidget);
    });

    testWidgets('call button opens the dialler', (tester) async {
      final launcher = RecordingLauncher();
      final state = await _state();
      await tester.pumpWidget(_app(
        AstrologerProfileScreen(
            service: ConsultationService(launcher: launcher.call)),
        state,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('astro_call_button')));
      await tester.pumpAndSettle();

      expect(launcher.opened.single.toString(), 'tel:9170735312');
    });

    testWidgets('whatsapp button opens wa.me', (tester) async {
      final launcher = RecordingLauncher();
      final state = await _state();
      await tester.pumpWidget(_app(
        AstrologerProfileScreen(
            service: ConsultationService(launcher: launcher.call)),
        state,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('astro_whatsapp_button')));
      await tester.pumpAndSettle();

      expect(launcher.opened.single.toString(), 'https://wa.me/9170735312');
    });

    testWidgets('tells the user when the intent cannot be opened',
        (tester) async {
      final launcher = RecordingLauncher()..result = false;
      final state = await _state();
      await tester.pumpWidget(_app(
        AstrologerProfileScreen(
            service: ConsultationService(launcher: launcher.call)),
        state,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('astro_call_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('मैन्युअली'), findsOneWidget);
    });

    testWidgets('renders in English too', (tester) async {
      final state = await _state(language: 'en');
      await tester.pumpWidget(_app(const AstrologerProfileScreen(), state,
          locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Consult an Acharya'), findsOneWidget);
      expect(find.text('Specialities'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.textContaining('No payment or booking'), findsOneWidget);

      await _scrollTo(tester, find.text('Available'));
      expect(find.text('7 Days a Week • 10:00 AM – 6:00 PM'), findsOneWidget);
    });

    testWidgets(
        'lays out without overflow on a small screen at a large text scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError =
          (d) => errors.add(d.exceptionAsString().split('\n').first);

      try {
        final state = await _state();
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: _app(const AstrologerProfileScreen(), state),
        ));
        await tester.pumpAndSettle();

        // Walk the whole list, so the bottom is built under this text scale too.
        for (var i = 0; i < 6; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -300));
          await tester.pumpAndSettle();
        }
      } finally {
        FlutterError.onError = previous;
      }

      expect(errors, isEmpty);
    });
  });

  group('Home integration', () {
    testWidgets('Home renders the premium feature grid with navigation',
        (tester) async {
      final state = await _state();
      await tester.pumpWidget(_app(const HomeScreen(), state));
      await tester.pumpAndSettle();

      expect(find.text('Jap'), findsOneWidget);
      expect(find.text('Panchang'), findsOneWidget);
      expect(find.text('Rashifal'), findsOneWidget);
      expect(find.text('Numerology'), findsOneWidget);

      await tester.tap(find.text('Numerology'));
      await tester.pumpAndSettle();

      expect(find.text('Numerology'), findsWidgets);
    });

    testWidgets('Home does not become a bottom navigation tab', (tester) async {
      final state = await _state();
      await tester.pumpWidget(_app(const HomeScreen(), state));
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });
}
