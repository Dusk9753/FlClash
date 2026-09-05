import 'package:fl_clash/features/auth/auth_providers.dart';
import 'package:fl_clash/features/auth/login_page.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/features/xboard/xboard_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _syncing = false;

  void _maybeSyncSubscribe() {
    final auth = ref.read(authNotifierProvider).value;
    if (auth == null || _syncing) {
      return;
    }
    _syncing = true;
    ref
        .read(authNotifierProvider.notifier)
        .syncSubscribe()
        .catchError((Object _) {})
        .whenComplete(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<XboardAuthData?>>(authNotifierProvider, (
      previous,
      next,
    ) {
      if (next.value != null && previous?.value == null) {
        _maybeSyncSubscribe();
      }
    });
    final authAsync = ref.watch(authNotifierProvider);
    return authAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const LoginPage(),
      data: (auth) => auth == null ? const LoginPage() : const HomePage(),
    );
  }
}
