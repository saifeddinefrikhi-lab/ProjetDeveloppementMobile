import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class LocalImageStore {
  const LocalImageStore();

  Future<File> persist(String temporaryPath) async {
    final documents = await getApplicationDocumentsDirectory();
    final scansDirectory = Directory(p.join(documents.path, 'scan_images'));
    if (!await scansDirectory.exists()) {
      await scansDirectory.create(recursive: true);
    }

    final extension = p.extension(temporaryPath).isEmpty
        ? '.jpg'
        : p.extension(temporaryPath).toLowerCase();
    final filename =
        '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}$extension';
    return File(temporaryPath).copy(p.join(scansDirectory.path, filename));
  }

  Future<void> deleteIfExists(File image) async {
    if (await image.exists()) await image.delete();
  }
}

const localImageStore = LocalImageStore();
