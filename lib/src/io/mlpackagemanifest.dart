import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:mlruntime/src/io/archive.dart';
import 'package:path_provider/path_provider.dart';

final class MLPackageManifest {
  final Directory tmpDir;
  final Directory baseDir;
  final Map<String, dynamic> manifest_;
  const MLPackageManifest._(this.tmpDir, this.baseDir, this.manifest_);

  static Future<MLPackageManifest?> loadFromBundle(
      AssetBundle bundle, String key) async {
    var tmpDir = await getTemporaryDirectory();
    var baseDir = await bundle.load(key).then((ByteData data) async {
      final ifs = InputStream(data);
      final ArchiveType type;
      if (key.endsWith(".zip")) {
        type = ArchiveType.zip;
      } else if (key.endsWith(".tar")) {
        type = ArchiveType.tar;
      } else if (key.endsWith(".tar.gz") || key.endsWith(".tgz")) {
        type = ArchiveType.tgz;
      } else if (key.endsWith(".tar.xz") || key.endsWith(".txz")) {
        type = ArchiveType.txz;
      } else {
        throw UnimplementedError();
      }
      final baseDir = await extractArchive(type, ifs, tmpDir);
      assert(await baseDir.exists());
      return baseDir;
    });

    final manifestFile_ = File("${baseDir.path}/Manifest.json");
    final manifest_ = jsonDecode(await manifestFile_.readAsString());
    return MLPackageManifest._(tmpDir, baseDir, manifest_);
  }

  void dispose() {
    baseDir.delete(recursive: true);
  }

  String get rootModelIdentifier {
    return manifest_["rootModelIdentifier"]!;
  }

  Map<String, Map<String, String>> get itemInfoEntries {
    final itemInfoEntries =
        manifest_["itemInfoEntries"]! as Map<String, dynamic>;
    return itemInfoEntries.map((String key, dynamic value) {
      return MapEntry(
          key,
          (value as Map<String, dynamic>).map((String key, dynamic value) {
            return MapEntry(key, value as String);
          }));
    });
  }

  Map<String, String> get modelManifest {
    var modelManifest = itemInfoEntries[rootModelIdentifier]!;
    if (modelManifest.containsKey("path")) {
      modelManifest["path"] = "${baseDir.path}/Data/${modelManifest["path"]}";
    }
    return modelManifest;
  }

  File get model {
    final path = modelManifest["path"]!;
    return File(path);
  }
}
