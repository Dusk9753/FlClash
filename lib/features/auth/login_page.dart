import 'package:fl_clash/common/diagnostics.dart';
import 'package:fl_clash/features/auth/auth_providers.dart';
import 'package:fl_clash/features/xboard/xboard_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegister = false;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('请输入邮箱和密码');
      return;
    }
    if (password.length < 8) {
      _showMessage('密码至少 8 位');
      return;
    }
    setState(() => _submitting = true);
    try {
      final notifier = ref.read(authNotifierProvider.notifier);
      if (_isRegister) {
        await notifier.register(email, password);
      } else {
        await notifier.login(email, password);
      }
    } on XboardApiException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('网络异常，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDiagnostics() async {
    var log = await diagnostics.read();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> refresh() async {
              final nextLog = await diagnostics.read();
              if (context.mounted) setDialogState(() => log = nextLog);
            }

            Future<void> clear() async {
              await diagnostics.clear();
              if (context.mounted) setDialogState(() => log = '');
            }

            return AlertDialog(
              title: const Text('调试日志'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: SelectableText(
                    log.isEmpty ? '暂无诊断日志' : log,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: clear, child: const Text('清空')),
                TextButton(onPressed: refresh, child: const Text('刷新')),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = ref.watch(xboardConfigProvider).value;
    final platformHealth = ref.watch(xboardPlatformHealthProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BrandIcon(logoUrl: config?.logo, color: colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    '小火箭加速',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PlatformStatus(
                    platformHealth: platformHealth,
                    onRefresh: () {
                      ref.invalidate(xboardConfigProvider);
                      ref.invalidate(xboardPlatformHealthProvider);
                    },
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isRegister ? '注册并登录' : '登录'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _isRegister = !_isRegister),
                    child: Text(_isRegister ? '已有账号？去登录' : '没有账号？去注册'),
                  ),
                  TextButton.icon(
                    onPressed: _openDiagnostics,
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('调试日志'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformStatus extends StatelessWidget {
  const _PlatformStatus({
    required this.platformHealth,
    required this.onRefresh,
  });

  final AsyncValue<bool> platformHealth;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (Color color, String label, IconData icon) = switch (platformHealth) {
      AsyncData() => (Colors.green, '已连接', Icons.circle),
      AsyncError() => (colorScheme.error, '平台维护中', Icons.error_outline),
      _ => (colorScheme.outline, '正在连接平台', Icons.sync),
    };
    return Center(
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          onTap: onRefresh,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(minHeight: 30),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandIcon extends StatelessWidget {
  const _BrandIcon({required this.logoUrl, required this.color});

  final String? logoUrl;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim() ?? '';
    if (url.isEmpty) {
      return Icon(Icons.rocket_launch, size: 64, color: color);
    }
    return Image.network(
      url,
      width: 64,
      height: 64,
      errorBuilder: (_, _, _) =>
          Icon(Icons.rocket_launch, size: 64, color: color),
    );
  }
}
