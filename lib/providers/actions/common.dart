part of '../action.dart';

@Riverpod(keepAlive: true)
class CommonAction extends _$CommonAction {
  @override
  void build() {}

  void toggleRunning() {
    final running = !ref.read(isStartProvider);
    ref
        .read(setupActionProvider.notifier)
        .setRunning(running, initialize: running && !ref.read(initProvider));
  }

  void updateSpeedStatistics() {
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(showTrayTitle: !state.showTrayTitle));
  }

  void updateMode() {
    ref.read(patchClashConfigProvider.notifier).update((state) {
      final index = Mode.values.indexWhere((item) => item == state.mode);
      if (index == -1) return state;
      final nextIndex = index + 1 > Mode.values.length - 1 ? 0 : index + 1;
      return state.copyWith(mode: Mode.values[nextIndex]);
    });
  }

  Future<void> updateTraffic() async {
    final onlyStatisticsProxy = ref.read(
      appSettingProvider.select((state) => state.onlyStatisticsProxy),
    );
    try {
      final traffic = await coreController.getTraffic(onlyStatisticsProxy);
      ref.read(trafficsProvider.notifier).addTraffic(traffic);
      ref.read(totalTrafficProvider.notifier).value = await coreController
          .getTotalTraffic(onlyStatisticsProxy);
    } catch (error) {
      commonPrint.log(
        'updateTraffic error: $error',
        logLevel: coreFailureLogLevel(error),
      );
    }
  }

  Future<void> autoCheckUpdate() async {
    if (!system.isAndroid || !ref.read(appSettingProvider).autoCheckUpdate) {
      return;
    }
    await checkXboardUpdate();
  }

  Future<void> checkXboardUpdate({bool isUser = false}) async {
    if (!system.isAndroid) return;
    try {
      final config = await ref.read(xboardConfigProvider.future);
      final update = getAndroidAppUpdate(
        config: config,
        currentVersion: globalState.packageInfo.version,
      );
      if (update == null) {
        if (isUser) {
          await globalState.showMessage(
            title: '检查更新',
            message: const TextSpan(text: '当前已是最新版本'),
          );
        }
        return;
      }
      final shouldUpdate = await globalState.showMessage(
        title: '发现新版本',
        message: TextSpan(text: '版本 ${update.version}\n\n${update.notes}'),
        confirmText: '立即更新',
        cancelText: '稍后更新',
      );
      if (shouldUpdate != true) return;
      final apk = await XboardAppUpdateDownloader().download(update);
      final launched = await app?.installApk(apk.path) ?? false;
      if (!launched) {
        await globalState.showMessage(
          title: '无法安装更新',
          message: const TextSpan(text: '请允许安装未知来源应用后重试'),
        );
      }
    } catch (_) {
      if (isUser) {
        await globalState.showMessage(
          title: '检查更新',
          message: const TextSpan(text: '检查更新失败，请稍后重试'),
        );
      }
    }
  }

  Future<void> checkUpdateResultHandle({
    Map<String, dynamic>? data,
    bool isUser = false,
  }) async {
    if (data != null) {
      final tagName = data['tag_name'];
      final body = data['body'];
      final submits = utils.parseReleaseBody(body);
      final context = globalState.navigatorKey.currentContext!;
      final textTheme = context.textTheme;
      final res = await globalState.showMessage(
        title: currentAppLocalizations.discoverNewVersion,
        message: TextSpan(
          text: '$tagName \n',
          style: textTheme.headlineSmall,
          children: [
            TextSpan(text: '\n', style: textTheme.bodyMedium),
            for (final submit in submits)
              TextSpan(text: '- $submit \n', style: textTheme.bodyMedium),
          ],
        ),
        confirmText: currentAppLocalizations.goDownload,
        cancelText: isUser ? null : currentAppLocalizations.noLongerRemind,
      );
      if (res == true) {
        launchUrl(Uri.parse('https://github.com/$repository/releases/latest'));
      } else if (!isUser && res == false) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(autoCheckUpdate: false));
      }
    } else if (isUser) {
      globalState.showMessage(
        title: currentAppLocalizations.checkUpdate,
        message: TextSpan(text: currentAppLocalizations.checkUpdateError),
      );
    }
  }
}
