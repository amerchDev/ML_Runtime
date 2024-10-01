import 'dart:io';
import 'package:archive/archive_io.dart';

enum ArchiveType { zip, tar, tgz, txz }

Future<Directory> extractArchive(
    ArchiveType type, InputStream is_, Directory tmpDir) async {
  Archive archive;
  switch (type) {
    case ArchiveType.zip:
      archive = ZipDecoder().decodeBuffer(is_);
    case ArchiveType.tar:
      archive = TarDecoder().decodeBuffer(is_);
    case ArchiveType.tgz:
      archive = TarDecoder().decodeBytes(GZipDecoder().decodeBuffer(is_));
    case ArchiveType.txz:
      archive = TarDecoder().decodeBytes(XZDecoder().decodeBuffer(is_));
  }
  // Assume that archive contains a single folder in the root. Use this folder name as the archive name.
  var archiveName = archive.first.name.replaceAll("/", "");
  await extractArchiveToDiskAsync(archive, tmpDir.path, asyncWrite: true);
  return Directory("${tmpDir.path}/$archiveName");
}
