import 'package:fl_clash/features/xboard/app_update.dart';
import 'package:fl_clash/features/xboard/xboard_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  XboardConfig config({
    String androidVersion = '0.8.97',
    String download = 'https://downloads.example.com/xiaohuojian.apk',
  }) {
    return XboardConfig.fromJson({
      'domain': ['https://panel.example.com'],
      'version': {'android': androidVersion},
      'download': download,
      'notes': '修复连接问题',
    });
  }

  test('accepts a newer Android update from XBoard', () {
    final update = getAndroidAppUpdate(
      config: config(),
      currentVersion: '0.8.96',
    );

    expect(update, isNotNull);
    expect(update!.version, '0.8.97');
    expect(update.downloadUrl.scheme, 'https');
  });

  test('does not offer the current or an older version', () {
    expect(
      getAndroidAppUpdate(config: config(), currentVersion: '0.8.97'),
      isNull,
    );
    expect(
      getAndroidAppUpdate(
        config: config(androidVersion: '0.8.95'),
        currentVersion: '0.8.96',
      ),
      isNull,
    );
  });

  test('rejects non-HTTPS or malformed update metadata', () {
    expect(
      getAndroidAppUpdate(
        config: config(download: 'http://downloads.example.com/app.apk'),
        currentVersion: '0.8.96',
      ),
      isNull,
    );
    expect(
      getAndroidAppUpdate(
        config: config(androidVersion: 'next'),
        currentVersion: '0.8.96',
      ),
      isNull,
    );
  });
}
