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

  String _extractMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      if (data is Map &&
          data['error'] is Map &&
          (data['error'] as Map)['message'] != null) {
        return (data['error'] as Map)['message'].toString();
      }
      if (error.message != null && error.message!.isNotEmpty) {
        return error.message!;
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
    bool unwrapData = true,
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
          if (unwrapData && body['data'] != null) {
            return body['data'];
          }
          return body;
        }
        if (body is Map) {
          final map = Map<String, dynamic>.from(body);
          if (unwrapData && map['data'] != null) {
            return map['data'];
          }
          return map;
        }
        return body;
      } catch (e) {
        lastError = e;
      }
    }
    throw XboardApiException(_extractMessage(lastError ?? Exception()));
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

  Future<XboardAnnouncementPage> getAnnouncementPage(
    XboardAuthData auth, {
    int current = 1,
  }) async {
    final data = await _request(
      '/user/notice/fetch',
      authData: auth.authData,
      queryParameters: {'current': current},
      unwrapData: false,
    );
    if (data is! Map) throw const XboardApiException('公告响应格式错误');
    try {
      return XboardAnnouncementPage.fromJson(Map<String, dynamic>.from(data));
    } on FormatException {
      throw const XboardApiException('公告响应格式错误');
    }
  }

  Future<List<XboardAnnouncement>> getAnnouncements(XboardAuthData auth) async {
    final page = await getAnnouncementPage(auth);
    return page.items;
  }

  Future<List<XboardPlan>> getPlans(XboardAuthData auth) async {
    final data = await _request('/user/plan/fetch', authData: auth.authData);
    if (data is! List) throw const XboardApiException('套餐响应格式错误');
    return data
        .map(
          (item) => XboardPlan.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<XboardPaymentMethod>> getPaymentMethods(
    XboardAuthData auth,
  ) async {
    final data = await _request(
      '/user/order/getPaymentMethod',
      authData: auth.authData,
    );
    if (data is! List) throw const XboardApiException('支付方式响应格式错误');
    return data
        .whereType<Map>()
        .map(
          (item) =>
              XboardPaymentMethod.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<XboardCheckoutResult> checkoutOrder(
    XboardAuthData auth, {
    required String tradeNo,
    required int method,
  }) async {
    final data = await _request(
      '/user/order/checkout',
      method: 'POST',
      authData: auth.authData,
      data: {'trade_no': tradeNo, 'method': method},
      unwrapData: false,
    );
    if (data is! Map) throw const XboardApiException('支付响应格式错误');
    return XboardCheckoutResult.fromJson(Map<String, dynamic>.from(data));
  }

  Future<int> checkOrder(XboardAuthData auth, String tradeNo) async {
    final data = await _request(
      '/user/order/check',
      authData: auth.authData,
      queryParameters: {'trade_no': tradeNo},
    );
    if (data is! num) throw const XboardApiException('订单状态响应格式错误');
    return data.toInt();
  }

  Future<void> cancelOrder(XboardAuthData auth, String tradeNo) async {
    await _request(
      '/user/order/cancel',
      method: 'POST',
      authData: auth.authData,
      data: {'trade_no': tradeNo},
    );
  }

  Future<String> createOrder(
    XboardAuthData auth, {
    required int planId,
    required String period,
  }) async {
    final data = await _request(
      '/user/order/save',
      method: 'POST',
      authData: auth.authData,
      data: {'plan_id': planId, 'period': period},
    );
    if (data is! String) throw const XboardApiException('订单响应格式错误');
    return data;
  }
}
