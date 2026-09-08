import 'dart:io';

import 'package:fl_clash/common/diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagnostic log redacts secrets before persisting', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fl-clash-diagnostics',
    );
    addTearDown(() => directory.delete(recursive: true));
    final diagnostics = Diagnostics(directoryProvider: () async => directory);

    await diagnostics.record(
      'failure token=abc Authorization: Bearer secret https://api.example/path?key=value',
    );

    final content = await diagnostics.read();
    expect(content, contains('[REDACTED]'));
    expect(content, isNot(contains('abc')));
    expect(content, isNot(contains('secret')));
    expect(content, isNot(contains('key=value')));
  });

  test('diagnostic log keeps bounded recent entries', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fl-clash-diagnostics',
    );
    addTearDown(() => directory.delete(recursive: true));
    final diagnostics = Diagnostics(directoryProvider: () async => directory);

    await diagnostics.record('x' * 300000);

    expect(
      (await diagnostics.read()).length,
      lessThanOrEqualTo(Diagnostics.maxBytes),
    );
  });
}
