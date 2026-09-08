import 'package:dio/dio.dart';
import 'package:fl_clash/features/xboard/xboard_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
