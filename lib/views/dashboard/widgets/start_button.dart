import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _widthAnimationDuration = Duration(milliseconds: 200);
const _buttonHeight = 56.0;

TextStyle? _runTimeTextStyle(BuildContext context) {
  return context.textTheme.titleMedium?.toSoftBold.copyWith(
    color: context.colorScheme.onPrimaryContainer,
  );
}

TextStyle? _hundredsTextStyle(BuildContext context) {
  return context.textTheme.titleMedium?.toSoftBold.copyWith(
    color: context.colorScheme.primary,
    fontWeight: FontWeight.w600,
  );
}

class RunTimeText extends StatelessWidget {
  final int? timeStamp;

  const RunTimeText({super.key, required this.timeStamp});

  @override
  Widget build(BuildContext context) {
    final text = utils.getTimeText(timeStamp);
    final style = _runTimeTextStyle(context);
    final textWidget = text.length < 9
        ? Text(text, maxLines: 1, overflow: TextOverflow.visible, style: style)
        : Text.rich(
            TextSpan(
              text: text.substring(0, 1),
              style: _hundredsTextStyle(context),
              children: [TextSpan(text: text.substring(1), style: style)],
            ),
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: style,
          );
    return textWidget;
  }
}

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key});

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _animation;
  double? _suspendedTextWidth;

  @override
  void initState() {
    super.initState();
    final isStart = ref.read(isStartProvider);
    _controller = AnimationController(
      vsync: this,
      value: isStart ? 1 : 0,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOutBack,
    );
    ref.listenManual(isStartProvider, (prev, next) {
      updateController(next);
    }, fireImmediately: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _suspendedTextWidth = null;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  bool _isConnecting = false;

  Future<void> handleSwitchStart() async {
    if (_isConnecting) return;
    if (ref.read(isStartProvider)) {
      ref.read(commonActionProvider.notifier).toggleRunning();
      return;
    }
    setState(() => _isConnecting = true);
    try {
      final connected = await ref
          .read(proxiesActionProvider.notifier)
          .autoConnect();
      if (mounted && connected) {
        ref.read(commonActionProvider.notifier).toggleRunning();
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void updateController(bool isStart) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final controller = _controller;
      if (controller == null) {
        return;
      }
      if (isStart) {
        controller.forward();
        return;
      }
      controller.reverse();
    });
  }

  double _getSuspendedTextWidth(BuildContext context, String suspendedText) {
    return _suspendedTextWidth ??=
        globalState.measure
            .computeTextSize(
              Text(suspendedText, style: context.textTheme.titleMedium),
            )
            .width +
        24;
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    if (!hasProfile) {
      return Container();
    }
    final isStart = ref.watch(isStartProvider);
    final suspend = ref.watch(suspendProvider);
    final theme = Theme.of(context);
    final appLocalizations = context.appLocalizations;
    final textWidth = suspend
        ? _getSuspendedTextWidth(context, appLocalizations.suspended)
        : _getSuspendedTextWidth(context, '连接');
    return RepaintBoundary(
      child: Theme(
        data: theme.copyWith(
          floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
            sizeConstraints: const BoxConstraints(
              minWidth: 56,
              maxWidth: 220,
              minHeight: _buttonHeight,
              maxHeight: _buttonHeight,
            ),
          ),
        ),
        child: FloatingActionButton(
          clipBehavior: Clip.antiAlias,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          heroTag: null,
          onPressed: _isConnecting ? null : handleSwitchStart,
          child: _isConnecting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (_, child) {
                        return Container(
                          height: _buttonHeight,
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16 - 8 * _animation.value,
                          ),
                          alignment: Alignment.centerLeft,
                          child: child,
                        );
                      },
                      child: AnimatedIcon(
                        icon: AnimatedIcons.play_pause,
                        progress: _animation,
                      ),
                    ),
                    SizeTransition(
                      axis: Axis.horizontal,
                      alignment: Alignment.centerLeft,
                      sizeFactor: _animation,
                      child: AnimatedContainer(
                        width: textWidth,
                        duration: _widthAnimationDuration,
                        curve: Curves.easeOut,
                        child: suspend
                            ? Text(
                                appLocalizations.suspended,
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: context
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                              )
                            : Text(
                                isStart ? '停止' : '连接',
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                style: _runTimeTextStyle(context),
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
