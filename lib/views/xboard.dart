import 'dart:async';

import 'package:fl_clash/features/auth/auth_providers.dart';
import 'package:fl_clash/features/xboard/xboard_models.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const _periodLabels = <String, String>{
  'month_price': '月付',
  'quarter_price': '季付',
  'half_year_price': '半年付',
  'year_price': '年付',
  'two_year_price': '两年付',
  'three_year_price': '三年付',
  'onetime_price': '一次性',
  'reset_price': '重置流量',
};

final _announcementsProvider = FutureProvider<List<XboardAnnouncement>>((
  ref,
) async {
  final auth = await ref.watch(authNotifierProvider.future);
  if (auth == null) return const [];
  final client = await ref.watch(xboardClientProvider.future);
  return client.getAnnouncements(auth);
});

final _plansProvider = FutureProvider<List<XboardPlan>>((ref) async {
  final auth = await ref.watch(authNotifierProvider.future);
  if (auth == null) return const [];
  final client = await ref.watch(xboardClientProvider.future);
  return client.getPlans(auth);
});

class XboardAnnouncementsView extends ConsumerWidget {
  const XboardAnnouncementsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_announcementsProvider);
    return CommonScaffold(
      title: '公告',
      actions: [
        IconButton(
          tooltip: '刷新公告',
          onPressed: () => ref.invalidate(_announcementsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) => items.isEmpty
            ? const Center(child: Text('暂无公告'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      title: Text(item.title),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(item.content),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class XboardStoreView extends ConsumerWidget {
  const XboardStoreView({super.key});

  Future<void> _buy(
    BuildContext context,
    WidgetRef ref,
    XboardPlan plan,
    String priceKey,
  ) async {
    final auth = await ref.read(authNotifierProvider.future);
    if (auth == null) return;
    try {
      final client = await ref.read(xboardClientProvider.future);
      final tradeNo = await client.createOrder(
        auth,
        planId: plan.id,
        period: plan.orderPeriodFor(priceKey),
      );
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _PaymentSheet(tradeNo: tradeNo),
      );
    } catch (error) {
      if (context.mounted) _showMessage(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_plansProvider);
    return CommonScaffold(
      title: '商店',
      actions: [
        IconButton(
          tooltip: '刷新套餐',
          onPressed: () => ref.invalidate(_plansProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (plans) => plans.isEmpty
            ? const Center(child: Text('暂无可购买套餐'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (plan.content.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(plan.content),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final entry in plan.prices.entries)
                                FilledButton.tonal(
                                  onPressed: plan.sell
                                      ? () =>
                                            _buy(context, ref, plan, entry.key)
                                      : null,
                                  child: Text(
                                    '${_periodLabels[entry.key] ?? entry.key} ${(entry.value / 100).toStringAsFixed(2)} 元',
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.tradeNo});

  final String tradeNo;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  Timer? _poller;
  bool _loading = true;
  bool _checkingOut = false;
  String? _error;
  List<XboardPaymentMethod> _methods = const [];
  XboardCheckoutResult? _checkout;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _loadMethods() async {
    try {
      final auth = await ref.read(authNotifierProvider.future);
      if (auth == null) throw Exception('登录已失效');
      final client = await ref.read(xboardClientProvider.future);
      final methods = await client.getPaymentMethods(auth);
      if (mounted) setState(() => _methods = methods);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkoutOrder(XboardPaymentMethod method) async {
    setState(() => _checkingOut = true);
    try {
      final auth = await ref.read(authNotifierProvider.future);
      if (auth == null) throw Exception('登录已失效');
      final client = await ref.read(xboardClientProvider.future);
      final result = await client.checkoutOrder(
        auth,
        tradeNo: widget.tradeNo,
        method: method.id,
      );
      if (!mounted) return;
      setState(() => _checkout = result);
      if (result.type == -1) {
        await _completePurchase();
        return;
      }
      if (result.type == 1 && result.data is String) {
        final launched = await launchUrl(
          Uri.parse(result.data as String),
          mode: LaunchMode.externalApplication,
        );
        if (!launched && mounted) _showMessage(context, '无法打开支付页面');
      }
      if (result.type == 0 || result.type == 1) _startPolling();
      if (result.type != -1 && result.type != 0 && result.type != 1) {
        throw Exception('支付方式返回了不支持的结果');
      }
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 3), (_) => _checkOrder());
  }

  Future<void> _checkOrder() async {
    try {
      final auth = await ref.read(authNotifierProvider.future);
      if (auth == null) return;
      final client = await ref.read(xboardClientProvider.future);
      if (await client.checkOrder(auth, widget.tradeNo) == 1) {
        await _completePurchase();
      }
    } catch (_) {
      // A transient poll failure must not close an in-progress payment.
    }
  }

  Future<void> _completePurchase() async {
    _poller?.cancel();
    await ref.read(authNotifierProvider.notifier).syncSubscribe();
    if (!mounted) return;
    Navigator.of(context).pop();
    _showMessage(context, '支付成功，订阅已同步');
  }

  Future<void> _cancel() async {
    try {
      final auth = await ref.read(authNotifierProvider.future);
      if (auth == null) return;
      final client = await ref.read(xboardClientProvider.future);
      await client.cancelOrder(auth, widget.tradeNo);
      _poller?.cancel();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showMessage(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkout = _checkout;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('支付订单', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null) Text(_error!),
            if (!_loading && _methods.isEmpty && checkout == null)
              const Text('当前没有可用支付方式'),
            if (checkout == null && !_loading)
              for (final method in _methods)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(method.name),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !_checkingOut,
                  onTap: () => _checkoutOrder(method),
                ),
            if (_checkingOut) const Center(child: CircularProgressIndicator()),
            if (checkout?.type == 0 && checkout?.data is String) ...[
              const SizedBox(height: 12),
              Center(
                child: QrImageView(data: checkout!.data as String, size: 220),
              ),
              const SizedBox(height: 8),
              const Text('请使用支付应用扫描二维码完成支付', textAlign: TextAlign.center),
            ],
            if (checkout?.type == 1) ...[
              const SizedBox(height: 12),
              const Text('支付页面已在系统浏览器打开，完成支付后本页会自动更新。'),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _cancel,
              icon: const Icon(Icons.close),
              label: const Text('取消订单'),
            ),
          ],
        ),
      ),
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
