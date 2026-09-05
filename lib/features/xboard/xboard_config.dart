import 'dart:convert';

import 'package:dio/dio.dart';

import 'xboard_models.dart';

const String kXboardConfigUrl = 'http://new.1q2b.com/oss/huosuconfig.json';

String _decodeConfigRaw(String raw) {
  final normalized = raw.trim().replaceAll(RegExp(r'\s'), '');
  try {
    return utf8.decode(base64Decode(normalized));
  } on FormatException {
    return utf8.decode(base64Decode(base64.normalize(normalized)));
  }
}

Future<XboardConfig> fetchXboardConfig({Dio? dio}) async {
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
  return XboardConfig.fromJson(jsonDecode(decoded) as Map<String, dynamic>);
}
