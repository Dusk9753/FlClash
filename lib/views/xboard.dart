import 'dart:async';

import 'package:fl_clash/features/auth/auth_providers.dart';
import 'package:fl_clash/features/xboard/xboard_client.dart';
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
        error: (_, _) => _XboardErrorState(
          message: '公告加载失败',
          onRetry: () => ref.invalidate(_announcementsProvider),
        ),
        data: (items) => items.isEmpty
            ? const _XboardEmptyState(
                icon: Icons.campaign_outlined,
                message: '暂无公告',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _AnnouncementTile(item: items[index], featured: index == 0),
              ),
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.item, required this.featured});

  final XboardAnnouncement item;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = item.createdAt;
    final metadata = date == null
        ? '服务公告'
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: featured,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        leading: Icon(
          featured
              ? Icons.notifications_active_outlined
              : Icons.campaign_outlined,
          color: featured ? theme.colorScheme.primary : null,
        ),
        title: Text(
          item.title.isEmpty ? '未命名公告' : item.title,
          style: featured
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )
              : null,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(metadata),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              item.content.isEmpty ? '暂无详细内容' : item.content,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
          ),
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                children: item.tags
                    .map((tag) => Chip(label: Text(tag)))
                    .toList(),
              ),
            ),
          ],
        ],
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
    } catch (_) {
      if (context.mounted) _showMessage(context, '订单创建失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_plansProvider);
    return CommonScaffold(
      title: '套餐',
      actions: [
        IconButton(
          tooltip: '刷新套餐',
          onPressed: () => ref.invalidate(_plansProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _XboardErrorState(
          message: '套餐加载失败',
          onRetry: () => ref.invalidate(_plansProvider),
        ),
        data: (plans) => plans.isEmpty
            ? const _XboardEmptyState(
                icon: Icons.storefront_outlined,
                message: '暂无可购买套餐',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: plans.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _PlanCard(
                  plan: plans[index],
                  onBuy: (key) => _buy(context, ref, plans[index], key),
                ),
              ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onBuy});

  final XboardPlan plan;
  final ValueChanged<String> onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prices = plan.prices.entries.toList();
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        leading: const Icon(Icons.inventory_2_outlined),
        title: Text(
          plan.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(plan.sell ? '点击查看套餐详情' : '暂停售卖'),
        children: [
          if (plan.content.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(plan.content, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(height: 10),
          ],
          if (prices.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('该套餐暂未配置价格'),
            )
          else
            ...prices.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: plan.sell ? () => onBuy(entry.key) : null,
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: Text(
                      '${_periodLabels[entry.key] ?? entry.key}  ${(entry.value / 100).toStringAsFixed(2)} 元',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _XboardEmptyState extends StatelessWidget {
  const _XboardEmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text(message),
      ],
    ),
  );
}

class _XboardErrorState extends StatelessWidget {
  const _XboardErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 42,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 12),
        Text(message),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('重新加载'),
        ),
      ],
    ),
  );
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

class XboardSupportView extends StatefulWidget {
  const XboardSupportView({super.key});

  @override
  State<XboardSupportView> createState() => _XboardSupportViewState();
}

class _XboardSupportViewState extends State<XboardSupportView> {
  static final _supportUrl = Uri.parse('https://chat.1q2b.com/support');

  bool _opening = false;
  String? _error;

  Future<void> _openSupport() async {
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final opened = await launchUrl(
        _supportUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw const XboardApiException('无法打开在线客服');
    } catch (error) {
      if (mounted) setState(() => _error = _supportMessage(error));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  String _supportMessage(Object error) {
    return '客服暂时不可用，请稍后重试';
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '客服',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.support_agent_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text('在线客服', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_error ?? '获取使用帮助或订单支持', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _opening ? null : _openSupport,
                icon: _opening
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chat_outlined),
                label: Text(_opening ? '正在打开' : '联系在线客服'),
              ),
              if (_error != null)
                TextButton(onPressed: _openSupport, child: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
