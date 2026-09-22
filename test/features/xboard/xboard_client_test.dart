import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/features/xboard/xboard_client.dart';
import 'package:fl_clash/features/xboard/xboard_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _TicketAdapter implements HttpClientAdapter {
  RequestOptions? request;
  Map<String, dynamic>? body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    body = options.data as Map<String, dynamic>?;
    return ResponseBody.fromString(
      '{"data": {}}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  test('submits a ticket through the XBoard ticket endpoint', () async {
    final adapter = _TicketAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final client = XboardClient(
      baseUrls: const ['https://example.test/api/v1'],
      dio: dio,
    );

    await client.submitTicket(
      const XboardAuthData(token: 'token', authData: 'auth', isAdmin: false),
      subject: '节点不可用',
      message: '全部节点测速失败',
    );

    expect(
      adapter.request?.path,
      'https://example.test/api/v1/user/ticket/save',
    );
    expect(adapter.request?.method, 'POST');
    expect(adapter.request?.headers['Authorization'], 'auth');
    expect(adapter.body, {
      'subject': '节点不可用',
      'message': '全部节点测速失败',
      'level': 1,
    });
  });

  test('maps payment method num, including string values', () {
    final method = XboardPaymentMethod.fromJson({
      'num': '2',
      'title': '支付宝',
      'handling_fee_fixed': '0',
      'handling_fee_percent': '0.5',
    });

    expect(method.id, 2);
    expect(method.name, '支付宝');
    expect(method.percentFee, 0.5);
  });

  test('maps unauthorized responses to a session-expired error', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/user/getSubscribe'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/user/getSubscribe'),
        statusCode: 401,
        data: {'message': 'internal authentication detail'},
      ),
      type: DioExceptionType.badResponse,
    );

    final exception = XboardApiException.fromError(error);

    expect(exception.isSessionExpired, isTrue);
    expect(exception.message, '登录已失效，请重新登录');
  });

  test('maps failed login credentials to a Chinese error', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/passport/auth/login'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/passport/auth/login'),
        statusCode: 401,
      ),
      type: DioExceptionType.badResponse,
    );

    final exception = XboardApiException.fromError(error);

    expect(exception.isSessionExpired, isFalse);
    expect(exception.message, '账号或密码错误');
  });

  test('maps a bad login request to a Chinese error', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/passport/auth/login'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/passport/auth/login'),
        statusCode: 400,
      ),
      type: DioExceptionType.badResponse,
    );

    expect(XboardApiException.fromError(error).message, '账号或密码错误');
  });

  test('does not expose remote failure bodies to the user', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/user/order/save'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/user/order/save'),
        statusCode: 500,
        data: {'message': 'sensitive upstream failure detail'},
      ),
      type: DioExceptionType.badResponse,
    );

    final exception = XboardApiException.fromError(error);

    expect(exception.isSessionExpired, isFalse);
    expect(exception.message, '服务暂时不可用，请稍后重试');
  });
}
