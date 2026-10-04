import 'dart:convert';
import 'dart:io';

/// Fetches the generated Rashifal payload for a day.
///
/// This is the only place that knows where the data lives, so the source can be
/// swapped (a different branch, a CDN, a private host) without touching the
/// repository or any screen.
///
/// It only ever returns the raw file text. Deciding whether that text is a
/// usable day belongs to [DailyRashifal.tryParse], and deciding what to do when
/// it is not belongs to the repository.
abstract class RashifalRemoteSource {
  /// Fetches the file for [dateKey], or `null` when it cannot be had.
  Future<String?> fetchDay(String dateKey);
}

/// [RashifalRemoteSource] that reads the published files over HTTP.
///
/// Uses `dart:io`'s HttpClient directly: the app already depends on Flutter, and
/// adding a package for a single GET would be a dependency the feature does not
/// need.
///
/// Two endpoints are tried in order and only when both fail is `null` returned:
///
/// 1. the primary `raw.githubusercontent.com` host;
/// 2. the `github.com/.../raw/refs/heads/...` form, which serves the identical
///    bytes and is kept as a fallback for when the primary host is unreachable or
///    returns a non-200.
class HttpRashifalRemoteSource implements RashifalRemoteSource {
  const HttpRashifalRemoteSource({
    this.baseUrl = kDefaultRashifalRemoteBaseUrl,
    this.timeout = const Duration(seconds: 8),
    this.budget = const Duration(seconds: 20),
    this.fetchOverride,
  });

  /// Where generated day files are published.
  ///
  /// The workflow writes `data/rashifal/YYYY-MM-DD.json` into the repository, so
  /// the raw content URL of that path is where the app looks. It is a public
  /// read-only location and needs no key, which keeps this zero-cost.
  static const String kDefaultRashifalRemoteBaseUrl =
      'https://raw.githubusercontent.com/vinayakamsolutions/JapMitra/main/data/rashifal/';

  /// Fallback host serving the same files, used when the primary fails.
  ///
  /// `github.com/<owner>/<repo>/raw/refs/heads/<branch>/<path>` is GitHub's
  /// canonical raw content form and returns the same bytes as
  /// `raw.githubusercontent.com`, so it is a drop-in fallback for the same path.
  static const String kFallbackRashifalRemoteBaseUrl =
      'https://github.com/vinayakamsolutions/JapMitra/raw/refs/heads/main/data/rashifal/';

  /// Base URL holding `YYYY-MM-DD.json` files.
  final String baseUrl;

  /// How long to wait for headers and for the body.
  final Duration timeout;

  /// Total wall-clock budget for the whole primary-then-fallback attempt.
  ///
  /// The per-stage [timeout] alone is not a bound: connecting, opening the
  /// response and draining the body each get one, and the fallback URL gets its
  /// own set, so a black-holed network could keep the screen waiting far longer
  /// than a person will tolerate. This budget caps the sum of every stage across
  /// both URLs. It never slows a fast failure, and it never shortens a healthy
  /// request: it only limits how long a hopeless one can last.
  final Duration budget;

  /// Test seam: when set, used instead of real HTTP. Lets tests drive the
  /// fallback chain without a network. Production leaves this `null`.
  final Future<String?> Function(Uri uri)? fetchOverride;

  @override
  Future<String?> fetchDay(String dateKey) async {
    final clock = Stopwatch()..start();
    for (final base in <String>[baseUrl, kFallbackRashifalRemoteBaseUrl]) {
      final uri = Uri.parse('$base$dateKey.json');

      // The seam is deliberately outside the budget: tests must stay
      // deterministic instead of depending on a stopwatch.
      if (fetchOverride != null) {
        final result = await fetchOverride!(uri);
        if (result != null) return result;
        continue;
      }

      if (_remaining(clock, budget) <= Duration.zero) return null;
      final result = await _fetchUrl(uri, clock);
      if (result != null) return result;
    }
    return null;
  }

  /// Time left in the overall budget, never negative.
  Duration _remaining(Stopwatch clock, Duration total) {
    final left = total - clock.elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Fetches one URL, returning `null` on any non-200, transport error, or
  /// exhausted budget.
  Future<String?> _fetchUrl(Uri uri, Stopwatch clock) async {
    Duration step() {
      final left = _remaining(clock, budget);
      return left < timeout ? left : timeout;
    }

    final client = HttpClient()..connectionTimeout = step();
    try {
      final request = await client.getUrl(uri).timeout(step());
      final response = await request.close().timeout(step());
      if (response.statusCode != HttpStatus.ok) return null;
      return await response.transform(utf8.decoder).join().timeout(step());
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
