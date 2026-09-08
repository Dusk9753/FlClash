import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/diagnostics.dart';

import 'xboard_models.dart';

const String kXboardConfigUrl = 'https://new.1q2b.com/oss/huosuconfig.json';

String _decodeConfigRaw(String raw) {
  final normalized = raw.trim().replaceAll(RegExp(r'\s'), '');
  try {
    return utf8.decode(base64Decode(normalized));
  } on FormatException {
    return utf8.decode(base64Decode(base64.normalize(normalized)));
  }
}

Future<XboardConfig> fetchXboardConfig({Dio? dio}) async {
  try {
    final client = dio ?? Dio();
    final response = await client.get<String>(
      kXboardConfigUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw Exception('XBoard config is empty');
    }
    final decoded = _decodeConfigRaw(data);
    final config = XboardConfig.fromJson(
      jsonDecode(decoded) as Map<String, dynamic>,
    );
    if (config.domains.isEmpty) {
      throw const FormatException('XBoard config has no domains');
    }
    return config;
  } catch (error) {
    final details = switch (error) {
      DioException(:final type, :final response) =>
        'type=$type status=${response?.statusCode ?? 'none'}',
      _ => 'type=${error.runtimeType}',
    };
    try {
      await diagnostics.record('xboard config fetch failed $details');
    } catch (_) {
      // Diagnostics must never change configuration loading.
    }
    rethrow;
  }
}
