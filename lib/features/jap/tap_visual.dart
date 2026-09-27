import 'package:flutter/material.dart';

/// A lightweight, self-animating golden glow shown at the exact tap location on
/// the Jap screen, carrying the current mantra text as it floats up and fades.
///
/// This widget is a **pure overlay**: it renders only inside the square box its
/// parent positions it in (see `kTapGlowExtent`). It never returns a
/// [Positioned] itself, never participates in normal layout, and never receives
/// pointer events. That is what keeps a burst of tap animations from becoming
/// the cause of an overflow or a lost tap.
///
/// The mantra text is drawn through a [FittedBox] inside a fixed-size box, so a
/// long Devanagari mantra, its transliteration, or a very large system text scale
/// all shrink to fit instead of spilling outside the effect.
class GoldenTapGlow extends StatefulWidget {
  const GoldenTapGlow({super.key, required this.mantra, required this.onDone});

  /// The mantra currently being chanted, shown inside the glow.
  final String mantra;

  /// Invoked once the animation has finished, so the parent can drop the glow.
  final VoidCallback onDone;

  @override
  State<GoldenTapGlow> createState() => _GoldenTapGlowState();
}

class _GoldenTapGlowState extends State<GoldenTapGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward().whenCompleteOrCancel(widget.onDone);

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20),
    TweenSequenceItem(
        tween:
            Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 80),
  ]).animate(_controller);

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30),
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 70),
  ]).animate(_controller);

  late final Animation<double> _ripple =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  /// How far the mantra rises while it fades. A fraction of the box, so the
  /// text can never travel outside the effect's own bounds.
  late final Animation<double> _rise = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Every animated size is a fraction of the box this widget was given, so
    // the ripple can never spill past the positioned bounds.
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Opacity(
            opacity: _opacity.value * 0.9,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Expanding ripple ring.
                  Container(
                    width: 34 + _ripple.value * 86,
                    height: 34 + _ripple.value * 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF0B64A).withValues(alpha: 0.75),
                        width: 2,
                      ),
                    ),
                  ),
                  // Soft golden glow.
                  Container(
                    width: 34 + _ripple.value * 18,
                    height: 34 + _ripple.value * 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        const Color(0xFFFFD98A).withValues(alpha: 0.85),
                        const Color(0xFFF0B64A).withValues(alpha: 0.0),
                      ]),
                    ),
                  ),
                  // The mantra, rising and fading, scaled down instead of
                  // clipped when it does not fit the fixed text box.
                  Transform.translate(
                    offset: Offset(0, -14 * _rise.value),
                    child: Transform.scale(
                      scale: _scale.value,
                      child: SizedBox(
                        width: 108,
                        height: 68,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.mantra,
                            key: const Key('jap_tap_feedback'),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: const Color(0xFF6B4A1F)
                                  .withValues(alpha: _opacity.value),
                              shadows: const [
                                Shadow(color: Color(0xFFF7CD7D), blurRadius: 8)
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
