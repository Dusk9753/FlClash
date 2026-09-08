import 'dart:convert';

import 'package:fl_clash/features/auth/auth_providers.dart';
import 'package:fl_clash/features/xboard/xboard_client.dart';
import 'package:fl_clash/features/xboard/xboard_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'clears the persisted session after a session-expired API error',
    () async {
      const auth = XboardAuthData(
        token: 'token',
        authData: 'auth',
        isAdmin: false,
      );
      SharedPreferences.setMockInitialValues({
        'xboard_auth': jsonEncode(auth.toJson()),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.future);
      final handled = await container
          .read(authNotifierProvider.notifier)
          .handleApiError(
            const XboardApiException('登录已失效，请重新登录', isSessionExpired: true),
          );

      expect(handled, isTrue);
      expect(container.read(authNotifierProvider).value, isNull);
      expect(
        SharedPreferences.getInstance().then(
          (prefs) => prefs.containsKey('xboard_auth'),
        ),
        completion(isFalse),
      );
    },
  );

  test('keeps the session for recoverable API errors', () async {
    const auth = XboardAuthData(
      token: 'token',
      authData: 'auth',
      isAdmin: false,
    );
    SharedPreferences.setMockInitialValues({
      'xboard_auth': jsonEncode(auth.toJson()),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authNotifierProvider.future);
    final handled = await container
        .read(authNotifierProvider.notifier)
        .handleApiError(const XboardApiException('网络异常，请稍后重试'));

    expect(handled, isFalse);
    final currentAuth = container.read(authNotifierProvider).value;
    expect(currentAuth?.token, auth.token);
    expect(currentAuth?.authData, auth.authData);
    expect(currentAuth?.isAdmin, auth.isAdmin);
  });
}
