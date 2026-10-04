import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Extensible deity artwork registry.
///
/// Each entry declares two things only, so adding a deity never requires
/// touching a widget:
///
/// * `asset` – the path of the approved artwork, if one is bundled.
/// * `tint` – the accent colour used by the neutral fallback and the artwork
///   wash, so each deity still reads as its own when no artwork exists.
///
/// The registry deliberately ships with asset paths that may not be present
/// yet. [DeityBackground] asks [Image.asset] for the path and, on failure,
/// renders the neutral fallback instead. That means approved artwork can be
/// dropped into `assets/images/deities/` later and is picked up automatically,
/// with no code change, while a missing file can never break the screen.
class DeityArtwork {
  static const Map<String, DeityArtworkEntry> _entries = {
    'shiva': DeityArtworkEntry(
      asset: 'assets/images/deities/shiva.png',
      tint: Color(0xFF4A6FA5),
    ),
    'ram': DeityArtworkEntry(
      asset: 'assets/images/deities/ram.png',
      tint: Color(0xFFD9772B),
    ),
    'krishna': DeityArtworkEntry(
      asset: 'assets/images/deities/krishna.png',
      tint: Color(0xFF2E7D8F),
    ),
    'ganesha': DeityArtworkEntry(
      asset: 'assets/images/deities/ganesha.png',
      tint: Color(0xFFB4752A),
    ),
    'hanuman': DeityArtworkEntry(
      asset: 'assets/images/deities/hanuman.png',
      tint: Color(0xFFB33A3A),
    ),
    'durga': DeityArtworkEntry(
      asset: 'assets/images/deities/durga.png',
      tint: Color(0xFF9C3F7C),
    ),
    'surya': DeityArtworkEntry(
      asset: 'assets/images/deities/surya.png',
      tint: Color(0xFFC08A1E),
    ),
  };

  /// Runtime registrations, so approved artwork can be added later without
  /// touching the screen implementation.
  static final Map<String, String> _registered = {};

  DeityArtwork._();

  /// Register approved artwork for [deityKey] at runtime.
  static void register(String deityKey, String assetPath) {
    _registered[deityKey] = assetPath;
  }

  /// Every deity key the registry knows about.
  static Iterable<String> get keys => _entries.keys;

  /// Asset path for this deity's approved artwork, or null (use fallback).
  static String? assetFor(String deityKey) =>
      _registered[deityKey] ?? _entries[deityKey]?.asset;

  /// Accent colour for this deity, used by the fallback and the artwork wash.
  static Color tintFor(String deityKey) =>
      _entries[deityKey]?.tint ?? const Color(0xFFB08040);
}

/// One registry row: an optional artwork asset plus a fallback accent.
class DeityArtworkEntry {
  const DeityArtworkEntry({required this.asset, required this.tint});
  final String asset;
  final Color tint;
}

/// Very subtle, deity-specific artwork background for the Jap screen.
///
/// Priority order:
///  1. Approved artwork from the registry, if the asset exists on disk.
///  2. A neutral, geometric yantra drawn in the deity's tint.
///
/// The fallback is intentionally *not* a word and *not* a likeness: without an
/// approved image a drawn mandala is honest and devotional, whereas an invented
/// portrait of a deity would not be. Everything here is non-interactive and
/// bounded by the viewport, so it can never intercept a tap or overflow.
class DeityBackground extends StatelessWidget {
  const DeityBackground({
    super.key,
    required this.deityKey,
    required this.child,
    this.photo,
  });

  final String deityKey;
  final Widget child;

  /// Optional path of a deity photo the user chose for this mantra.
  ///
  /// When it resolves, it replaces the bundled artwork for this mantra only. A
  /// path that has gone missing falls back to the normal registry order rather
  /// than leaving a hole in the layout.
  final String? photo;

  /// Fraction of the screen height that belongs to the deity artwork alone.
  ///
  /// The artwork owns this band outright and nothing else is laid out inside it,
  /// so the deity stays the primary focal point and no counter, bead or progress
  /// bar can ever be drawn across the face or body.
  ///
  /// Layout code that has to stay clear of the artwork must read this same
  /// figure rather than repeating the number.
  static const double kArtworkBandFraction = 0.34;

  @override
  Widget build(BuildContext context) {
    final photoPath = photo?.trim();
    final hasPhoto = photoPath != null && photoPath.isNotEmpty;
    final asset = DeityArtwork.assetFor(deityKey);
    final tint = DeityArtwork.tintFor(deityKey);
    return LayoutBuilder(
      builder: (context, box) {
        final band = box.maxHeight * kArtworkBandFraction;
        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF8ED), Color(0xFFFFFDF4)],
                ),
              ),
            ),
            // Ambient wash behind the artwork, so the band reads as the focal
            // point rather than as an arbitrary picture floating in the layout.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: band,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.35),
                      radius: 0.95,
                      colors: <Color>[
                        AppTheme.gold.withValues(alpha: 0.16),
                        AppTheme.gold.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // The artwork itself, contained inside the band and centred, so it
            // is never cropped and never reaches the content below.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: band,
              child: IgnorePointer(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    box.maxWidth * 0.05,
                    band * 0.04,
                    box.maxWidth * 0.05,
                    band * 0.06,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: hasPhoto
                        ? Image.file(
                            File(photoPath),
                            fit: BoxFit.contain,
                            // A photo deleted from app storage must degrade to
                            // the registry artwork, never to an error.
                            errorBuilder: (context, error, stack) =>
                                _artworkOrFallback(asset, tint),
                          )
                        : _artworkOrFallback(asset, tint),
                  ),
                ),
              ),
            ),
            // The child still receives the whole screen: the tap surface must
            // stay full-bleed so a tap anywhere counts, artwork band included.
            child,
          ],
        );
      },
    );
  }
}

/// Registry artwork when one is bundled, otherwise the neutral yantra.
///
/// A registered path whose file is not bundled yet degrades to the fallback
/// rather than to an error, so approved artwork can be added later without a
/// code change.
Widget _artworkOrFallback(String? asset, Color tint) => asset == null
    ? _DeityFallback(tint: tint)
    : Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => _DeityFallback(tint: tint),
      );

/// Neutral geometric fallback: a concentric yantra in the deity's tint.
///
/// Purely decorative geometry, drawn once per tint change.
class _DeityFallback extends StatelessWidget {
  const _DeityFallback({required this.tint});
  final Color tint;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _YantraPainter(tint),
        size: Size.infinite,
        isComplex: false,
        willChange: false,
      );
}

class _YantraPainter extends CustomPainter {
  _YantraPainter(this.tint);
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    if (radius <= 0) return;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.012
      ..color = tint.withValues(alpha: 0.30);
    final soft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.006
      ..color = tint.withValues(alpha: 0.18);

    // Outer rings.
    canvas.drawCircle(center, radius * 0.96, ring);
    canvas.drawCircle(center, radius * 0.86, soft);
    canvas.drawCircle(center, radius * 0.52, ring);

    // Petal ring: a closed loop of mirrored arcs around the centre.
    final petal = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.008
      ..color = tint.withValues(alpha: 0.22);
    const petals = 12;
    final inner = radius * 0.54;
    final outer = radius * 0.84;
    final path = Path();
    for (var i = 0; i < petals; i++) {
      final a = (i * 2 * math.pi) / petals;
      final mid = a + math.pi / petals;
      final start = Offset(
        center.dx + inner * math.cos(a),
        center.dy + inner * math.sin(a),
      );
      final via = Offset(
        center.dx + outer * math.cos(mid),
        center.dy + outer * math.sin(mid),
      );
      final end = Offset(
        center.dx + inner * math.cos(a + 2 * math.pi / petals),
        center.dy + inner * math.sin(a + 2 * math.pi / petals),
      );
      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      }
      path.quadraticBezierTo(via.dx, via.dy, end.dx, end.dy);
    }
    path.close();
    canvas.drawPath(path, petal);

    // Central bindu.
    canvas.drawCircle(
      center,
      radius * 0.16,
      Paint()..color = tint.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      center,
      radius * 0.06,
      Paint()..color = tint.withValues(alpha: 0.24),
    );
  }

  @override
  bool shouldRepaint(covariant _YantraPainter old) => old.tint != tint;
}
