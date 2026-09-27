/// One sign's content, as published by a verified source.
class RashiContent {
  const RashiContent({
    required this.signKey,
    this.general,
    this.career,
    this.finance,
    this.relationships,
    this.health,
    this.luckyNumber,
    this.luckyColour,
    this.dailyGuidance,
    this.isVerified = false,
  });

  final String signKey;
  final String? general;
  final String? career;
  final String? finance;
  final String? relationships;
  final String? health;
  final String? luckyNumber;
  final String? luckyColour;
  final String? dailyGuidance;

  /// Only verified content may be shown as today's prediction. Anything else
  /// stays [isVerified] false and is never presented as a reading.
  final bool isVerified;

  /// True when there is nothing verified to show, so the UI can present the
  /// honest "not available" state instead of empty fields.
  bool get hasContent => isVerified;
}

/// Loads a sign's content for today.
///
/// The bundled sample file is development data only, so the repository refuses to
/// hand it back as a reading: a caller that asks for today's content receives a
/// content-less result unless a verified provider is configured.
class RashifalRepository {
  const RashifalRepository();

  /// Today's content for [signKey].
  ///
  /// Returns an empty, unverified [RashiContent] while no verified source is
  /// available. It never returns invented or sample predictions.
  Future<RashiContent> getToday(String signKey) async =>
      RashiContent(signKey: signKey);
}
