import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:fl_clash/pages/error.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust_api/rust_api.dart';

import 'application.dart';
import 'common/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(diagnostics.record(details.exception, details.stack));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(diagnostics.record(error, stack));
    return true;
  };
  try {
    if (system.isDesktop) {
      await RustLib.init();
    }
    final version = await system.init();
    await diagnostics.record(
      'startup platform=${Platform.operatingSystem} version=$version',
    );
    final container = await globalState.init(version);
    HttpOverrides.global = FlClashHttpOverrides();
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const Application(),
      ),
    );
  } catch (e, s) {
    await diagnostics.record(e, s);
    runApp(
      MaterialApp(
        home: InitErrorScreen(error: e, stack: s),
      ),
    );
  }
}
