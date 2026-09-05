import 'package:dio/dio.dart';

import 'xboard_models.dart';

class XboardApiException implements Exception {
  const XboardApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class XboardClient {
  XboardClient({required List<String> baseUrls, Dio? dio})
    : _baseUrls = baseUrls.isNotEmpty ? baseUrls : const [''],
      _dio = dio ?? Dio();

  final List<String> _baseUrls;
  final Dio _dio;

  String? _extractMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      if (error.message != null && error.message!.isNotEmpty) {
        return error.message;
      }
    }
    return error.toString();
  }

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? data,
    String? authData,
  }) async {
    Object? lastError;
    for (final baseUrl in _baseUrls) {
      try {
        final response = await _dio.request<dynamic>(
          '$baseUrl$path',
          queryParameters: queryParameters,
          data: data,
          options: Options(
            method: method,
            headers: <String, dynamic>{
              if (authData != null) ...{'Authorization': authData},
            },
          ),
        );
        final body = response.data;
        if (body is Map<String, dynamic>) {
          if (body['data'] != null) {
            return body['data'];
          }
          return body;
        }
        if (body is Map) {
          final map = Map<String, dynamic>.from(body);
          if (map['data'] != null) {
            return map['data'];
          }
          return map;
        }
        return body;
      } catch (e) {
        lastError = e;
      }
    }
    throw XboardApiException(
      _extractMessage(lastError ?? Exception()) ?? '请求失败',
    );
  }

  Future<XboardAuthData> login(String email, String password) async {
    final data = await _request(
      '/passport/auth/login',
      method: 'POST',
      data: <String, dynamic>{'email': email, 'password': password},
    );
    if (data is! Map) {
      throw const XboardApiException('登录响应格式错误');
    }
    return XboardAuthData.fromJson(Map<String, dynamic>.from(data));
  }

  Future<XboardAuthData> register(
    String email,
    String password, {
    String? inviteCode,
  }) async {
    final data = await _request(
      '/passport/auth/register',
      method: 'POST',
      data: <String, dynamic>{
        'email': email,
        'password': password,
        if (inviteCode != null && inviteCode.isNotEmpty)
          'invite_code': inviteCode,
      },
    );
    if (data is! Map) {
      throw const XboardApiException('注册响应格式错误');
    }
    return XboardAuthData.fromJson(Map<String, dynamic>.from(data));
  }

  Future<XboardSubscribeInfo> getSubscribe(XboardAuthData auth) async {
    final data = await _request('/user/getSubscribe', authData: auth.authData);
    if (data is! Map) {
      throw const XboardApiException('订阅响应格式错误');
    }
    return XboardSubscribeInfo.fromJson(Map<String, dynamic>.from(data));
  }
}
