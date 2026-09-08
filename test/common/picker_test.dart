import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_clash/common/picker.dart';
import 'package:test/test.dart';

base class TestPlatformFile extends PlatformFile {
  TestPlatformFile({required this.name, required String path})
    : uri = Uri.file(path);

  @override
  final String name;

  @override
  final Uri uri;

  @override
  XFile get xFile => XFile(path!);

  @override
  int? lengthSync() => null;

  @override
  Future<int> length() => xFile.length();

  @override
  Future<Uint8List> readAsBytes() => xFile.readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() => xFile.openRead();
}

void main() {
  group('PlatformFileExt.readBytes', () {
    test('loads bytes from the picked file path', () async {
      final directory = await Directory.systemTemp.createTemp(
        'fl_clash_picker_test_',
      );
      addTearDown(() => directory.delete(recursive: true));

      final file = File('${directory.path}/profile.yaml');
      await file.writeAsString('mixed-port: 7890');

      final platformFile = TestPlatformFile(
        name: 'profile.yaml',
        path: file.path,
      );

      final bytes = await platformFile.readBytes();

      expect(String.fromCharCodes(bytes), 'mixed-port: 7890');
    });
  });
}
