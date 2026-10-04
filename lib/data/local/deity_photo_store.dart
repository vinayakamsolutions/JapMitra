import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps a user's chosen deity photo in app-private storage.
///
/// The picker hands back a file in a cache directory that the platform is free to
/// clear at any time, so the chosen photo is copied into the app's own
/// documents directory instead. Only the resulting path is stored with the
/// mantra, which is what makes the association survive an app restart.
///
/// Deletion is deliberately conservative: a path is only ever removed when it
/// lives inside this store's own directory, so a stale or hand-edited database
/// row can never delete a photo the user still has in their gallery.
class DeityPhotoStore {
  DeityPhotoStore({Future<Directory> Function()? documentsDirectory})
      : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  /// Subdirectory of the documents directory that holds imported photos.
  static const String folderName = 'deity_photos';

  /// Extensions accepted for a deity photo.
  ///
  /// The picker can hand back anything on disk, so the list is explicit rather
  /// than trusting the source extension blindly.
  static const List<String> allowedExtensions = <String>[
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
    '.heif',
  ];

  /// Copies a picked photo into app-private storage and returns its new path.
  ///
  /// Throws a [FileSystemException] when the source is missing or is not an
  /// image, so the caller can refuse to save a mantra with a broken photo rather
  /// than writing a path that will never resolve.
  ///
  /// Pass the mantra's current [replacing] path when swapping a photo. If the new
  /// image has a different extension the two files cannot share a name, so the
  /// old copy is removed once the new one is safely written; without this the
  /// replaced photo would sit on disk unreferenced forever.
  Future<String> importPicked(String sourcePath,
      {required String mantra, String? replacing}) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Picked photo no longer exists', sourcePath);
    }
    final ext = p.extension(sourcePath).toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      throw FileSystemException('Unsupported photo format', sourcePath);
    }

    final dir = await _photoDirectory();
    // Keyed by the mantra identity so replacing a photo overwrites the previous
    // copy instead of leaving orphans behind, and so two mantras can never
    // share one file.
    final dest = File(p.join(dir.path, '${_keyFor(mantra)}$ext'));
    await source.copy(dest.path);
    if (replacing != null && replacing != dest.path) {
      await discard(replacing);
    }
    return dest.path;
  }

  /// The file name stem used for [mantra], without an extension.
  ///
  /// A SHA-256 prefix rather than [Object.hashCode] or [String.hashCode]:
  /// neither is guaranteed to be stable across Dart versions or platforms, and
  /// an unstable key would write a second copy under a new name on a later app
  /// version, orphaning the first. A digest is fixed by its spec, so the same
  /// mantra always maps to the same file for the life of the install.
  static String _keyFor(String mantra) {
    final digest = sha256.convert(utf8.encode(mantra.trim()));
    return digest.toString().substring(0, 16);
  }

  /// Removes a photo previously written by [importPicked].
  ///
  /// Safe to call with null, with a path this store never wrote, or with a file
  /// that is already gone.
  Future<void> discard(String? storedPath) async {
    if (storedPath == null || storedPath.trim().isEmpty) return;
    final file = File(storedPath);
    if (!await file.exists()) return;

    final dir = await _photoDirectory();
    // Never delete outside our own directory: the user's original photo in
    // their gallery must survive a mantra being deleted.
    if (!p.isWithin(dir.path, file.path)) return;
    try {
      await file.delete();
    } on FileSystemException {
      // A photo we cannot remove is not worth failing a delete over; the row is
      // gone either way and the file is simply never referenced again.
    }
  }

  /// Whether a stored path still resolves to a readable file.
  ///
  /// The UI uses this to fall back to the neutral deity artwork instead of
  /// rendering a broken image.
  Future<bool> exists(String? storedPath) async {
    if (storedPath == null || storedPath.trim().isEmpty) return false;
    return File(storedPath).exists();
  }

  Future<Directory> _photoDirectory() async {
    final base = await _documentsDirectory();
    final dir = Directory(p.join(base.path, folderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
