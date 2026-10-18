import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Keeps each user's selfie as a JPEG in the app's private storage on this
/// device. Nothing is uploaded.
abstract class SelfieStore {
  Future<Uint8List?> load(String email);
  Future<void> save(String email, Uint8List jpeg);
  Future<void> delete(String email);
}

class LocalSelfieStore implements SelfieStore {
  Future<File> _file(String email) async {
    final dir = await getApplicationDocumentsDirectory();
    final name = email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return File('${dir.path}/selfies/$name.jpg');
  }

  @override
  Future<Uint8List?> load(String email) async {
    final file = await _file(email);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> save(String email, Uint8List jpeg) async {
    final file = await _file(email);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(jpeg, flush: true);
  }

  @override
  Future<void> delete(String email) async {
    final file = await _file(email);
    if (await file.exists()) await file.delete();
  }
}

/// In-memory store for tests.
class MemorySelfieStore implements SelfieStore {
  final _photos = <String, Uint8List>{};

  @override
  Future<Uint8List?> load(String email) async => _photos[email.toLowerCase()];

  @override
  Future<void> save(String email, Uint8List jpeg) async =>
      _photos[email.toLowerCase()] = jpeg;

  @override
  Future<void> delete(String email) async =>
      _photos.remove(email.toLowerCase());
}
