import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:japmitra/data/local/deity_photo_store.dart';
import 'package:japmitra/data/local/jap_store.dart';
import 'package:japmitra/features/jap/jap_logic.dart';
import 'package:path/path.dart' as p;

/// A stand-in for the app documents directory, so the tests never touch the real
/// device filesystem.
Directory _docs() {
  final d = Directory.systemTemp.createTempSync('japmitra_photo_test');
  addTearDown(() {
    if (d.existsSync()) d.deleteSync(recursive: true);
  });
  return d;
}

File _pickerTempFile(Directory docs, String name) {
  final f = File('${docs.path}${Platform.pathSeparator}picker_cache$name');
  f.writeAsStringSync('fake image bytes');
  return f;
}

/// Every file currently in the store's own directory, to prove a swap left
/// exactly one copy behind.
List<File> _storedPhotos(Directory docs) => Directory(
      p.join(docs.path, DeityPhotoStore.folderName),
    ).listSync().whereType<File>().toList();

void main() {
  group('DeityPhotoStore', () {
    test('copies a picked photo into app-private storage', () async {
      final docs = _docs();
      final store = DeityPhotoStore(documentsDirectory: () async => docs);
      final picked = _pickerTempFile(docs, '.jpg');

      final stored =
          await store.importPicked(picked.path, mantra: 'ॐ नमः शिवाय');

      expect(stored, isNot(picked.path));
      expect(File(stored).existsSync(), isTrue);
      expect(stored, startsWith(docs.path));
      expect(
        Directory(p.join(docs.path, DeityPhotoStore.folderName)).existsSync(),
        isTrue,
      );
      // The picked file itself is left alone; only a copy is taken.
      expect(picked.existsSync(), isTrue);
    });

    test('two mantras never share one stored file', () async {
      final docs = _docs();
      final store = DeityPhotoStore(documentsDirectory: () async => docs);
      final a = await store.importPicked(_pickerTempFile(docs, 'a.jpg').path,
          mantra: 'मेरा अपना मंत्र');
      final b = await store.importPicked(_pickerTempFile(docs, 'b.jpg').path,
          mantra: 'दूसरा मंत्र');
      expect(a, isNot(b));
    });

    test('the stored path survives a restart, so it still resolves', () async {
      final docs = _docs();
      final stored = await DeityPhotoStore(documentsDirectory: () async => docs)
          .importPicked(_pickerTempFile(docs, '.png').path, mantra: 'ॐ');

      // A brand new instance, as after an app relaunch.
      final afterRestart =
          DeityPhotoStore(documentsDirectory: () async => docs);
      expect(await afterRestart.exists(stored), isTrue);
    });

    test('exists() reports a photo that has been removed', () async {
      final docs = _docs();
      final store = DeityPhotoStore(documentsDirectory: () async => docs);
      final stored = await store
          .importPicked(_pickerTempFile(docs, '.jpg').path, mantra: 'ॐ');
      await File(stored).delete();

      // The UI uses this to fall back to the bundled deity artwork.
      expect(await store.exists(stored), isFalse);
      expect(await store.exists(null), isFalse);
      expect(await store.exists('  '), isFalse);
    });

    test('discard removes the app copy', () async {
      final docs = _docs();
      final store = DeityPhotoStore(documentsDirectory: () async => docs);
      final stored = await store
          .importPicked(_pickerTempFile(docs, '.jpg').path, mantra: 'ॐ');

      await store.discard(stored);
      expect(File(stored).existsSync(), isFalse);
      // Discarding again, or with nothing, must not throw.
      await store.discard(stored);
      await store.discard(null);
    });

    test('discard never deletes a photo outside its own directory', () async {
      final docs = _docs();
      final outsideDir =
          Directory.systemTemp.createTempSync('japmitra_outside_test');
      addTearDown(() {
        if (outsideDir.existsSync()) outsideDir.deleteSync(recursive: true);
      });
      // A path in the user's gallery rather than app storage: a stale or
      // hand-edited database row must not be able to delete it.
      final outside =
          File('${outsideDir.path}${Platform.pathSeparator}gallery.jpg')
            ..writeAsStringSync('precious');

      final store = DeityPhotoStore(documentsDirectory: () async => docs);
      await store.discard(outside.path);

      expect(outside.existsSync(), isTrue);
    });

    test('refuses a source that has gone missing', () async {
      final docs = _docs();
      final store = DeityPhotoStore(documentsDirectory: () async => docs);
      expect(
        () => store.importPicked(
            '${docs.path}${Platform.pathSeparator}gone.jpg',
            mantra: 'ॐ'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('refuses an unsupported format rather than storing it', () async {
      final docs = _docs();
      final store = DeityPhotoStore(documentsDirectory: () async => docs);
      expect(
        () =>
            store.importPicked(_pickerTempFile(docs, '.txt').path, mantra: 'ॐ'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('the file name is stable for the same mantra', () async {
      final docs = _docs();
      final store = DeityPhotoStore(documentsDirectory: () async => docs);

      final first = await store.importPicked(
          _pickerTempFile(docs, 'one.jpg').path,
          mantra: 'स्थिर मंत्र');
      // A fresh store, as if the app had been restarted: the same mantra must
      // still land on the same path, or every relaunch would orphan a file.
      final afterRestart =
          DeityPhotoStore(documentsDirectory: () async => docs);
      final second = await afterRestart.importPicked(
          _pickerTempFile(docs, 'two.jpg').path,
          mantra: 'स्थिर मंत्र');

      expect(second, first);
    });

    test('whitespace around the mantra does not change the file name',
        () async {
      final docs = _docs();
      final store = DeityPhotoStore(documentsDirectory: () async => docs);
      final trimmed = await store
          .importPicked(_pickerTempFile(docs, 'a.jpg').path, mantra: 'मंत्र');
      final padded = await store.importPicked(
          _pickerTempFile(docs, 'b.jpg').path,
          mantra: '  मंत्र  ');
      expect(padded, trimmed);
    });

    test('replacing with the same format overwrites in place', () async {
      final docs = _docs();
      final store = DeityPhotoStore(documentsDirectory: () async => docs);
      final first = await store.importPicked(
          _pickerTempFile(docs, 'a.jpg').path,
          mantra: 'बदलने वाला मंत्र');
      File(first).writeAsStringSync('the original bytes');

      final replaced = await store.importPicked(
          _pickerTempFile(docs, 'b.jpg').path,
          mantra: 'बदलने वाला मंत्र',
          replacing: first);

      expect(replaced, first);
      expect(File(replaced).readAsStringSync(), 'fake image bytes');
      // Exactly one file in the store: no leftover copy.
      expect(_storedPhotos(docs).length, 1);
    });

    test('replacing with a different format retires the old file', () async {
      final docs = _docs();
      final store = DeityPhotoStore(documentsDirectory: () async => docs);
      final png = await store.importPicked(_pickerTempFile(docs, 'a.png').path,
          mantra: 'बदलने वाला मंत्र');

      // The new photo has a different extension, so the two cannot share a name.
      final jpg = await store.importPicked(_pickerTempFile(docs, 'b.jpg').path,
          mantra: 'बदलने वाला मंत्र', replacing: png);

      expect(jpg, isNot(png));
      expect(File(jpg).existsSync(), isTrue);
      expect(File(png).existsSync(), isFalse);
      expect(_storedPhotos(docs).length, 1);
    });

    test('a failed import keeps the photo it was replacing', () async {
      final docs = _docs();
      final store = DeityPhotoStore(documentsDirectory: () async => docs);
      final stored = await store.importPicked(
          _pickerTempFile(docs, 'a.jpg').path,
          mantra: 'सुरक्षित मंत्र');

      // The new pick is gone by the time we save; the mantra must keep the photo
      // it already had rather than losing it to a failed swap.
      await expectLater(
        store.importPicked(
          p.join(docs.path, 'vanished.png'),
          mantra: 'सुरक्षित मंत्र',
          replacing: stored,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(File(stored).existsSync(), isTrue);
    });

    test('replacing never deletes a gallery file outside the store', () async {
      final docs = _docs();
      final outsideDir =
          Directory.systemTemp.createTempSync('japmitra_replace_test');
      addTearDown(() {
        if (outsideDir.existsSync()) outsideDir.deleteSync(recursive: true);
      });
      final outside = File(p.join(outsideDir.path, 'gallery.jpg'))
        ..writeAsStringSync('precious');

      final store = DeityPhotoStore(documentsDirectory: () async => docs);
      await store.importPicked(_pickerTempFile(docs, 'a.png').path,
          mantra: 'मंत्र', replacing: outside.path);

      expect(outside.existsSync(), isTrue);
    });
  });

  group('custom mantra metadata', () {
    test('label prefers the user name and falls back to the text', () {
      expect(
        const CustomMantra(text: 'ॐ नमः शिवाय', name: 'महामृत्युंजय').label,
        'महामृत्युंजय',
      );
      expect(const CustomMantra(text: 'ॐ नमः शिवाय').label, 'ॐ नमः शिवाय');
      // A whitespace-only name is not a name.
      expect(const CustomMantra(text: 'ॐ', name: '   ').label, 'ॐ');
    });

    test('hasPhoto ignores blank paths', () {
      expect(const CustomMantra(text: 'ॐ', photo: '/x/y.jpg').hasPhoto, isTrue);
      expect(const CustomMantra(text: 'ॐ').hasPhoto, isFalse);
      expect(const CustomMantra(text: 'ॐ', photo: '  ').hasPhoto, isFalse);
    });

    test('a custom mantra keeps the chosen name and photo in its info', () {
      final info = mantraInfoFor('स्वयंभू मंत्र',
          isCustom: true, displayName: 'महामृत्युंजय', photo: '/x/y.jpg');

      expect(info.isCustom, isTrue);
      expect(info.label, 'महामृत्युंजय');
      expect(info.photo, '/x/y.jpg');
      // Identity stays the text, so every stored count still matches.
      expect(info.name, 'स्वयंभू मंत्र');
      expect(info.completionMessage, contains('महामृत्युंजय'));
    });

    test('a built-in mantra wins even if custom metadata is passed', () {
      // A user can save a mantra whose text matches a built-in one; the built-in
      // deity artwork must not be replaced by their custom photo.
      final builtIn = defaultMantras.first[1];
      final info = mantraInfoFor(builtIn,
          isCustom: true, displayName: 'मेरा नाम', photo: '/x/y.jpg');
      expect(info.isCustom, isFalse);
      expect(info.label, builtIn);
      expect(info.photo, isNull);
    });

    test('a custom mantra with no name shows its text', () {
      final info = mantraInfoFor('ॐ', isCustom: true);
      expect(info.label, 'ॐ');
      expect(info.photo, isNull);
    });

    test('built-in mantras are unaffected by custom metadata', () {
      final info = mantraInfoFor(defaultMantras.first[1]);
      expect(info.isCustom, isFalse);
      expect(info.label, defaultMantras.first[1]);
      expect(info.photo, isNull);
      expect(info.deityKey, isNotEmpty);
    });
  });
}
