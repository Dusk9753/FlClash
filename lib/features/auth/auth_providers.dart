import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/xboard/xboard_client.dart';
import 'package:fl_clash/features/xboard/xboard_config.dart';
import 'package:fl_clash/features/xboard/xboard_models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final xboardConfigProvider = FutureProvider<XboardConfig>((ref) {
  return fetchXboardConfig();
});

final xboardClientProvider = FutureProvider<XboardClient>((ref) async {
  final config = await ref.watch(xboardConfigProvider.future);
  return XboardClient(baseUrls: config.baseUrls);
});

final xboardPlatformHealthProvider = FutureProvider<bool>((ref) async {
  final client = await ref.watch(xboardClientProvider.future);
  await client.checkPlatformHealth().timeout(const Duration(seconds: 10));
  return true;
});

class AuthNotifier extends AsyncNotifier<XboardAuthData?> {
  static const String _prefsKey = 'xboard_auth';

  @override
  Future<XboardAuthData?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return XboardAuthData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<XboardAuthData> login(String email, String password) async {
    final client = await ref.read(xboardClientProvider.future);
    final auth = await client.login(email, password);
    await _save(auth);
    state = AsyncData(auth);
    return auth;
  }

  Future<XboardAuthData> register(String email, String password) async {
    final client = await ref.read(xboardClientProvider.future);
    final auth = await client.register(email, password);
    await _save(auth);
    state = AsyncData(auth);
    return auth;
  }

  /// Signs the current account out.
  ///
  /// When [clearData] is true the locally downloaded subscription profile is
  /// removed as well, so no account configuration is left on the device.
  Future<void> logout({bool clearData = false}) async {
    if (clearData) {
      try {
        await ref.read(profilesActionProvider.notifier).clearSystemProfiles();
      } catch (error) {
        commonPrint.log(
          'Failed to clear system profiles: $error',
          logLevel: LogLevel.warning,
        );
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    state = const AsyncData(null);
  }

  Future<void> syncSubscribe() async {
    final auth = state.value;
    if (auth == null) {
      return;
    }
    try {
      final client = await ref.read(xboardClientProvider.future);
      final subscribe = await client.getSubscribe(auth);
      if (subscribe.subscribeUrl.isEmpty) {
        return;
      }
      await ref
          .read(profilesActionProvider.notifier)
          .syncSystemProfile(subscribe.subscribeUrl);
    } catch (error) {
      await handleApiError(error);
      rethrow;
    }
  }

  Future<bool> handleApiError(Object error) async {
    if (error is! XboardApiException || !error.isSessionExpired) {
      return false;
    }
    await logout();
    return true;
  }

  Future<void> _save(XboardAuthData auth) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(auth.toJson()));
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, XboardAuthData?>(AuthNotifier.new);
