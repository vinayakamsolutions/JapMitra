/// Immutable profile of a Jyotishi available for consultation.
///
/// Every field here is product data owned by this file, so the UI never mixes
/// presentation with content and nothing about a person is invented at the
/// widget level.
class AstrologerProfile {
  const AstrologerProfile({
    required this.id,
    required this.name,
    required this.title,
    required this.experience,
    required this.specialities,
    required this.languageNames,
    required this.city,
    required this.phone,
    required this.consultationMinutes,
    required this.fee,
    required this.availableDaysLabel,
    required this.availableHours,
    required this.bio,
    this.photoAsset,
  });

  final String id;
  final String name;
  final String title;
  final String experience;

  /// Speciality labels in the profile's own English form; the UI localizes the
  /// surrounding chrome, not the subject's credentials.
  final List<String> specialities;

  /// Language names in the profile's own English form.
  final List<String> languageNames;

  final String city;
  final String phone;
  final int consultationMinutes;
  final int fee;
  final String availableDaysLabel;
  final String availableHours;
  final String bio;

  /// The approved photograph bundled for this consultant, if there is one.
  ///
  /// Only set to a real, approved photograph. A null value means the UI shows
  /// [monogram] instead of any likeness.
  final String? photoAsset;

  /// Digits only, for `tel:` and `wa.me` links.
  String get phoneDigits => phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// Short, non-deceptive availability line for the Home card.
  String get availabilityLine => '$availableDaysLabel • $availableHours';

  /// Monogram used wherever no approved photograph of the person exists.
  /// Initials only: an invented likeness is worse than no likeness.
  String get monogram {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return _initials(parts.first, 2);
    return '${_initials(parts.first, 1)}${_initials(parts.last, 1)}';
  }
}

/// First [n] characters of a name, upper-cased. Safe for Devanagari and Latin.
String _initials(String part, int n) =>
    part.length <= n ? part.toUpperCase() : part.substring(0, n).toUpperCase();

/// The one consultant currently published in the app.
const AstrologerProfile featuredAstrologer = AstrologerProfile(
  id: 'abhijeet-srivastava',
  name: 'Abhijeet Srivastava',
  title: 'Acharya',
  experience: '21+ Years Experience',
  specialities: <String>[
    'Kundli',
    'Vedic Astrology',
    'Numerology',
    'Palmistry',
    'Tantra-Mantra Specialist',
  ],
  languageNames: <String>['Hindi', 'English'],
  city: 'Lucknow',

  /// Stored exactly as published: the digits, not a re-grouped rendering of
  /// them, so a display change can never alter the number that gets dialled.
  phone: '+9170735312',
  consultationMinutes: 5,
  fee: 501,
  availableDaysLabel: '7 Days a Week',
  availableHours: '10:00 AM – 6:00 PM',
  bio:
      'Vedic astrologer offering Kundli, palmistry and numerology guidance over a direct, private conversation.',

  /// The approved photograph, bundled under `assets/images/` (declared in
  /// pubspec.yaml). The UI falls back to the monogram if it cannot be loaded.
  photoAsset: 'assets/images/astrologer/abhijeet_srivastava.jpg',
);

/// Published profiles, newest first.
const List<AstrologerProfile> astrologers = <AstrologerProfile>[
  featuredAstrologer
];
