import 'dart:io';

import 'package:fl_clash/common/diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('can clear persisted diagnostics', () async {
    final directory = await Directory.systemTemp.createTemp(
      'diagnostics-clear-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final logger = Diagnostics(directoryProvider: () async => directory);

    await logger.record('request failed');
    await logger.clear();

    expect(await logger.read(), isEmpty);
  });
}
