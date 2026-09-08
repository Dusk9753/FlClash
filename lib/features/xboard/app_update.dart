import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'xboard_models.dart';

class XboardAppUpdate {
  const XboardAppUpdate({
    required this.version,
    required this.downloadUrl,
    required this.notes,
  });

  final String version;
  final Uri downloadUrl;
  final String notes;
}

XboardAppUpdate? getAndroidAppUpdate({
  required XboardConfig config,
  required String currentVersion,
}) {
  final version = config.versions['android']?.trim() ?? '';
  final downloadUrl = Uri.tryParse(config.download.trim());
  if (!_isValidVersion(version) ||
      downloadUrl == null ||
      downloadUrl.scheme != 'https' ||
      downloadUrl.host.isEmpty ||
      _compareVersions(version, currentVersion) <= 0) {
    return null;
  }
  return XboardAppUpdate(
    version: version,
    downloadUrl: downloadUrl,
    notes: config.notes.trim(),
  );
}

bool _isValidVersion(String version) =>
    RegExp(r'^v?\d+(?:\.\d+){0,3}(?:\+\d+)?$').hasMatch(version);

int _compareVersions(String left, String right) {
  List<int> parts(String value) => value
      .replaceFirst(RegExp('^v'), '')
      .split(RegExp(r'[.+]'))
      .map((part) => int.tryParse(part) ?? 0)
      .toList();

  final leftParts = parts(left);
  final rightParts = parts(right);
  final length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;
  for (var index = 0; index < length; index++) {
    final comparison = (index < leftParts.length ? leftParts[index] : 0)
        .compareTo(index < rightParts.length ? rightParts[index] : 0);
    if (comparison != 0) return comparison;
  }
  return 0;
}

class XboardAppUpdateDownloader {
  XboardAppUpdateDownloader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<File> download(XboardAppUpdate update) async {
    final directory = await getApplicationCacheDirectory();
    final target = File(join(directory.path, 'xiaohuojian-update.apk'));
    await target.delete().catchError((_) => target);
    await _dio.download(
      update.downloadUrl.toString(),
      target.path,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: false,
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    if (!await target.exists() || await target.length() == 0) {
      throw const FileSystemException('更新包下载失败');
    }
    return target;
  }
}
