import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'astrologer_model.dart';

/// Signature of the injectable launcher, matching `launchUrl`'s essentials.
typedef UrlLauncher = Future<bool> Function(Uri uri, {LaunchMode mode});

Future<bool> _platformLauncher(Uri uri,
        {LaunchMode mode = LaunchMode.platformDefault}) =>
    launchUrl(uri, mode: mode);

/// Outcome of a contact action, so the UI can react without inspecting
/// platform errors directly.
enum ContactResult { launched, noApp, failed }

/// Opens the phone dialler and WhatsApp for a consultant.
///
/// Deliberately thin: the app does not process payments, does not fake a
/// booking confirmation, and only hands a well-known intent to the platform.
class ConsultationService {
  const ConsultationService({UrlLauncher? launcher}) : _launcher = launcher;

  /// Null means "use the platform launcher".
  final UrlLauncher? _launcher;

  /// Open the dialler pre-filled with the consultant's number.
  Future<ContactResult> call(AstrologerProfile profile) =>
      _open(Uri(scheme: 'tel', path: profile.phoneDigits));

  /// Open WhatsApp on a chat with the consultant's number.
  Future<ContactResult> whatsapp(AstrologerProfile profile) =>
      _open(Uri.https('wa.me', '/${profile.phoneDigits}'));

  Future<ContactResult> _open(Uri uri) async {
    try {
      final ok = await (_launcher ?? _platformLauncher)(uri,
          mode: LaunchMode.externalApplication);
      return ok ? ContactResult.launched : ContactResult.noApp;
    } catch (e) {
      debugPrint('ConsultationService: could not open $uri ($e)');
      return ContactResult.failed;
    }
  }
}
