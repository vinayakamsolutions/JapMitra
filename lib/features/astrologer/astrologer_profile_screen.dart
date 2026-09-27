import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import 'astrologer_model.dart';
import 'consultation_service.dart';

/// Registry for approved photographs of a consultant.
///
/// Ships with the approved photograph of the published consultant. If that
/// asset is ever missing, or a consultant has no approved photograph, the UI
/// falls back to a typographic monogram rather than an invented likeness.
class AstrologerArtwork {
  static final Map<String, String> _assets = <String, String>{
    if (featuredAstrologer.photoAsset != null)
      featuredAstrologer.id: featuredAstrologer.photoAsset!,
  };

  AstrologerArtwork._();

  static void register(String astrologerId, String assetPath) =>
      _assets[astrologerId] = assetPath;

  static String? assetFor(String astrologerId) => _assets[astrologerId];
}

/// Consultation profile for a Jyotishi: credentials, availability and the two
/// actions the app can honestly perform (call and WhatsApp).
class AstrologerProfileScreen extends StatelessWidget {
  const AstrologerProfileScreen({
    super.key,
    this.profile = featuredAstrologer,
    this.service = const ConsultationService(),
  });

  final AstrologerProfile profile;
  final ConsultationService service;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.t('astroTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _header(context, theme),
          const SizedBox(height: 16),
          Text(
            profile.bio,
            key: const Key('astro_bio'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5A3A1A),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _section(
            context,
            title: l.t('astroSpecialities'),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in profile.specialities)
                  Chip(
                    label: Text(s),
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7A5A2A),
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFFFBF1DE),
                    side: const BorderSide(color: Color(0xFFEAD9B8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _detailRow(
            context,
            icon: Icons.translate,
            label: l.t('astroLanguages'),
            value: profile.languageNames.join(', '),
          ),
          _detailRow(
            context,
            icon: Icons.schedule,
            label: l.t('astroAvailability'),
            value: profile.availabilityLine,
          ),
          _detailRow(
            context,
            icon: Icons.place_outlined,
            label: l.t('astroBasedIn'),
            value: profile.city,
          ),
          const SizedBox(height: 16),
          _feeCard(context, theme, l),
          const SizedBox(height: 16),
        ],
      ),
      // The two things a visitor came here to do stay reachable without
      // scrolling, however short the screen is.
      bottomNavigationBar: _actionBar(context, l),
    );
  }

  Widget _header(BuildContext context, ThemeData theme) => Column(
        children: [
          _avatar(context),
          const SizedBox(height: 12),
          Text(
            profile.name,
            key: const Key('astro_name'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5A3A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${profile.title} • ${profile.city}',
            key: const Key('astro_title'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall
                ?.copyWith(color: const Color(0xFF8A6A3A)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF1DA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEAD9B8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium_outlined,
                    size: 16, color: Color(0xFFD8A94A)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    profile.experience,
                    key: const Key('astro_experience'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7A5A2A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  /// Approved photo when one is bundled, otherwise a monogram disc.
  ///
  /// A photo that fails to load falls back to the monogram, so a missing or
  /// unreadable asset can never leave the profile without any identification.
  Widget _avatar(BuildContext context) {
    final l = AppLocalizations.of(context);
    final asset = AstrologerArtwork.assetFor(profile.id);
    final monogram = Text(
      profile.monogram,
      key: const Key('astro_monogram'),
      style: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 1,
      ),
    );
    final disc = Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3C97A), Color(0xFFE87822)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE87822).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: asset == null
          ? monogram
          : ClipOval(
              child: Image.asset(
                asset,
                key: const Key('astro_photo'),
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                semanticLabel: l.t('astroPhotoLabel'),
                errorBuilder: (context, error, stack) => monogram,
              ),
            ),
    );
    return Semantics(
      label: asset == null ? profile.name : l.t('astroPhotoLabel'),
      image: true,
      child: disc,
    );
  }

  Widget _section(BuildContext context,
          {required String title, required Widget child}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFB08040),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      );

  Widget _detailRow(BuildContext context,
          {required IconData icon,
          required String label,
          required String value}) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: const Color(0xFFD8A94A)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: const Color(0xFFA98050)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF3E2415),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _feeCard(BuildContext context, ThemeData theme, AppLocalizations l) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAD9B8)),
        ),
        child: Row(
          children: [
            const Icon(Icons.payments_outlined, color: Color(0xFFE87822)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.t('astroFee'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: const Color(0xFF7A5A2A)),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '₹${profile.fee}',
                    key: const Key('astro_fee'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE87822),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• ${profile.consultationMinutes} ${l.t('astroMinutes')}',
                    key: const Key('astro_duration'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFF8A6A3A)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _actionBar(BuildContext context, AppLocalizations l) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEAD9B8))),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.t('astroNoBooking'),
            key: const Key('astro_no_booking'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: const Color(0xFFA98050)),
          ),
          const SizedBox(height: 8),
          _actions(context, l),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, AppLocalizations l) => Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const Key('astro_call_button'),
              onPressed: () => _contact(context, l, call: true),
              icon: const Icon(Icons.call, size: 20),
              label: Text(l.t('astroCall')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: const Color(0xFFE87822),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('astro_whatsapp_button'),
              onPressed: () => _contact(context, l, call: false),
              icon: const Icon(Icons.chat, size: 20, color: Color(0xFF1F7A4D)),
              label: Text(
                l.t('astroWhatsapp'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                side: const BorderSide(color: Color(0xFF1F7A4D)),
                foregroundColor: const Color(0xFF1F7A4D),
              ),
            ),
          ),
        ],
      );

  Future<void> _contact(BuildContext context, AppLocalizations l,
      {required bool call}) async {
    final result =
        call ? await service.call(profile) : await service.whatsapp(profile);
    if (!context.mounted || result == ContactResult.launched) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content:
            Text(call ? l.t('astroCallFailed') : l.t('astroWhatsappFailed')),
      ),
    );
  }
}
