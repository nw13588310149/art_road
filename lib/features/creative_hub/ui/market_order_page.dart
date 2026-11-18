import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../data/creative_models.dart';
import '../data/market_delivery_service.dart';
import '../data/market_repository.dart';
import '../state/market_controller.dart';
import 'creative_widgets.dart';
import 'creative_pdf_reader.dart';
import 'market_forms.dart';

class MarketOrderPage extends ConsumerWidget {
  const MarketOrderPage({
    required this.orderId,
    required this.onBack,
    super.key,
  });
  final String orderId;
  final VoidCallback onBack;
  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    MarketOrder order,
    String action,
    String title,
    String message, {
    bool danger = false,
  }) async {
    if (!await showAppConfirm(
          context: context,
          title: title,
          message: message,
          confirmLabel: title,
          danger: danger,
        ) ||
        !context.mounted) {
      return;
    }
    final result = await ref
        .read(commerceProvider.notifier)
        .orderAction(order.id, action);
    if (context.mounted) {
      if (result.success) {
        AppToast.showSuccess(context, '订单已更新');
      } else {
        AppToast.showError(context, result.error);
      }
    }
  }

  Future<void> _form(
    BuildContext context,
    WidgetRef ref,
    MarketOrder o,
    String action,
    String title,
    String explanation,
    List<MarketFormField> fields, {
    CreativeJson extra = const {},
  }) async {
    await showMarketForm(
      context,
      title: title,
      explanation: explanation,
      fields: fields,
      save: (body) =>
          ref.read(commerceProvider.notifier).orderAction(o.id, action, {
            ...body,
            ...extra,
            if (action == 'review')
              'rating': int.tryParse('${body['rating']}') ?? 0,
          }),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(commerceProvider);
    final o = state.orders.where((o) => o.id == orderId).firstOrNull;
    if (o == null) {
      return AppErrorState(
        title: '未找到订单',
        description: '请刷新订单列表后重试。',
        onRetry: onBack,
      );
    }
    final w = o.listing;
    final seller = o.seller && !o.buyer;
    final buttons = <Widget>[
      if (o.buyer && o.status == MarketOrderStatus.pendingPayment) ...[
        AppButton(
          label: '模拟支付 ${marketMoney(o.totalCents)}',
          onTap: state.busy
              ? null
              : () => _confirm(
                  context,
                  ref,
                  o,
                  'pay',
                  '确认模拟支付',
                  '本次不会扣除真实款项。${w.kind == MarketKind.digital ? '完成后可查看数字交付文件和许可凭证。' : '完成后等待卖家发货。'}',
                ),
        ),
        AppButton(
          label: '取消订单',
          variant: AppButtonVariant.secondary,
          onTap: state.busy
              ? null
              : () => _confirm(
                  context,
                  ref,
                  o,
                  'cancel',
                  '取消订单',
                  '取消后将释放预留库存，之后可重新下单。',
                  danger: true,
                ),
        ),
      ],
      if (o.canDeliver)
        AppButton(
          label: '查看交付文件',
          icon: Icons.download_outlined,
          onTap: () => showAppDrawer(
            context: context,
            builder: (_) => MarketDeliveryDrawer(orderId: o.id),
          ),
        ),
      if (o.buyer && o.status == MarketOrderStatus.shipped)
        AppButton(
          label: '确认收货',
          onTap: state.busy
              ? null
              : () => _confirm(
                  context,
                  ref,
                  o,
                  'receive',
                  '确认收货',
                  '请确认已收到作品，并核对数量和外观。确认后订单完成，仍可申请售后。',
                ),
        ),
      if (seller && o.status == MarketOrderStatus.awaitingShipment)
        AppButton(
          label: '填写发货信息',
          onTap: state.busy
              ? null
              : () => _form(
                  context,
                  ref,
                  o,
                  'ship',
                  '作品发货',
                  '请核对下方订单地址，填写真实寄件信息。演示订单不会生成物流任务。',
                  const [
                    MarketFormField('carrier', '快递公司', max: 30),
                    MarketFormField('tracking', '物流单号', max: 40),
                  ],
                ),
        ),
      if (o.canRefund)
        AppButton(
          label: '申请售后',
          variant: AppButtonVariant.secondary,
          onTap: state.busy
              ? null
              : () => _form(
                  context,
                  ref,
                  o,
                  'refund',
                  '申请售后',
                  '说明交付、作品状态或权属问题。卖家会处理申请，已发货实物可能需要寄回。',
                  const [MarketFormField('reason', '问题说明（至少 5 字）', lines: 4)],
                ),
        ),
      if (o.canReview)
        AppButton(
          label: '评价作品',
          variant: AppButtonVariant.secondary,
          onTap: state.busy
              ? null
              : () => _form(
                  context,
                  ref,
                  o,
                  'review',
                  '评价作品',
                  '评价将展示在作品详情中，请根据本次体验填写。',
                  const [
                    MarketFormField(
                      'rating',
                      '评分（1—5 整数）',
                      initial: '5',
                      max: 1,
                    ),
                    MarketFormField('content', '评价内容（至少 5 字）', lines: 3),
                  ],
                ),
        ),
      if (o.canDispute)
        AppButton(
          label: '申请平台介入',
          variant: AppButtonVariant.secondary,
          onTap: state.busy
              ? null
              : () => _form(
                  context,
                  ref,
                  o,
                  'dispute',
                  '申请平台介入',
                  '平台将结合订单和双方说明处理。已提交的申请无需重复提交。',
                  const [MarketFormField('reason', '补充说明（至少 5 字）', lines: 4)],
                ),
        ),
      if (seller && o.status == MarketOrderStatus.refundRequested) ...[
        AppButton(
          label: '同意售后',
          onTap: state.busy
              ? null
              : () => _form(
                  context,
                  ref,
                  o,
                  'refund-decision',
                  '同意售后',
                  w.kind == MarketKind.physical &&
                          o.afterSale['previousStatus'] != 'awaiting_shipment'
                      ? '填写可接收退货的完整地址，签收退货后完成模拟退款。'
                      : '同意后将完成模拟退款，数字文件访问权限随之结束。',
                  [
                    const MarketFormField('note', '处理说明（至少 5 字）', lines: 3),
                    if (w.kind == MarketKind.physical &&
                        o.afterSale['previousStatus'] != 'awaiting_shipment')
                      const MarketFormField(
                        'returnAddress',
                        '退货地址、联系人和电话',
                        lines: 3,
                        max: 300,
                      ),
                  ],
                  extra: {'approve': true},
                ),
        ),
        AppButton(
          label: '拒绝申请',
          variant: AppButtonVariant.secondary,
          onTap: state.busy
              ? null
              : () => _form(
                  context,
                  ref,
                  o,
                  'refund-decision',
                  '拒绝售后申请',
                  '请说明依据，买家可继续申请平台介入。',
                  const [MarketFormField('note', '拒绝原因（至少 5 字）', lines: 4)],
                  extra: {'approve': false},
                ),
        ),
      ],
      if (o.buyer && o.status == MarketOrderStatus.returnRequired)
        AppButton(
          label: '填写退货物流',
          onTap: state.busy
              ? null
              : () => _form(
                  context,
                  ref,
                  o,
                  'return',
                  '寄回作品',
                  '请按售后记录中的地址寄回并保留凭证。',
                  const [
                    MarketFormField('carrier', '快递公司', max: 30),
                    MarketFormField('tracking', '退货单号', max: 40),
                  ],
                ),
        ),
      if (seller && o.status == MarketOrderStatus.returnShipped)
        AppButton(
          label: '确认退货并退款',
          onTap: state.busy
              ? null
              : () => _confirm(
                  context,
                  ref,
                  o,
                  'return-received',
                  '确认退货并退款',
                  '请确认已收到退回作品。完成后将模拟退款，作品下架待您检查后重新发布。',
                  danger: true,
                ),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          CreativeHeading(
            title: '订单详情',
            subtitle: '${seller ? '卖出' : '买入'} · $orderId',
            onBack: onBack,
            actions: [
              AppIconButton(
                icon: Icons.refresh,
                semanticLabel: '刷新订单',
                onTap: state.busy
                    ? null
                    : ref.read(commerceProvider.notifier).load,
              ),
            ],
          ),
          if (state.error.isNotEmpty)
            AppNotice(message: state.error, tone: AppTone.warning),
          Expanded(
            child: ListView(
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 16,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(o.status.label, style: AppText.title24),
                          ),
                          const AppTag(label: '演示交易'),
                        ],
                      ),
                      Text(_guidance(o, seller), style: AppText.body14),
                      if (buttons.isNotEmpty)
                        Wrap(spacing: 12, runSpacing: 12, children: buttons),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 20,
                  children: [
                    Expanded(
                      flex: 6,
                      child: AppCard(
                        title: '本次交易的作品',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 16,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppImage(
                                  src: w.cover,
                                  width: 100,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  borderRadius: AppRadius.br8,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 8,
                                    children: [
                                      Text(w.title, style: AppText.title20),
                                      Text(
                                        '${w.author} · ${w.subject}',
                                        style: AppText.body13,
                                      ),
                                      AppTag(label: w.kind.label),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              w.kind == MarketKind.digital
                                  ? '${w.license.label}\n${w.terms}'
                                  : '${w.specification}\n实物购买不包含著作权转让。',
                              style: AppText.body14,
                            ),
                            marketLine('作品金额', w.priceLabel),
                            if (w.kind == MarketKind.physical)
                              marketLine('运费', marketMoney(o.shippingCents)),
                            marketLine('订单合计', marketMoney(o.totalCents)),
                            Text(
                              '下单时的作品、价格和条款已保留，后续发布内容的修改不影响此订单。',
                              style: AppText.caption12,
                            ),
                            if (o.address != null) ...[
                              const Divider(color: AppColors.line),
                              Text('收货信息', style: AppText.title16),
                              Text(
                                '${o.address!.name} · ${o.address!.phone}\n${o.address!.detail}',
                                style: AppText.body14,
                              ),
                            ],
                            if (o.shipment.isNotEmpty)
                              Text(
                                '发货物流：${o.shipment['carrier']} · ${o.shipment['tracking']}',
                                style: AppText.body14,
                              ),
                            if (o.review.isNotEmpty) ...[
                              const Divider(color: AppColors.line),
                              Text(
                                '我的评价 · ${o.review['rating']} / 5',
                                style: AppText.title16,
                              ),
                              Text(
                                '${o.review['content']}',
                                style: AppText.body14,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 20,
                        children: [
                          if (o.dispute.isNotEmpty)
                            AppCard(
                              title: o.dispute['status'] == 'open'
                                  ? '平台处理中'
                                  : '平台处理结果',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 10,
                                children: [
                                  Text(
                                    o.dispute['status'] == 'open'
                                        ? '已收到介入申请，处理结果将在本订单中展示。'
                                        : '${o.dispute['upheld'] == true ? '支持申请' : '不支持申请'} · ${o.dispute['operator']}',
                                    style: AppText.body14Strong,
                                  ),
                                  if (o.dispute['note'] != null)
                                    Text(
                                      '${o.dispute['note']}',
                                      style: AppText.body14,
                                    ),
                                  Text(
                                    '${o.dispute['time']}',
                                    style: AppText.caption12,
                                  ),
                                ],
                              ),
                            ),
                          if (o.afterSale.isNotEmpty)
                            AppCard(
                              title: '售后记录',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 10,
                                children: [
                                  Text(
                                    '${o.afterSale['reason'] ?? ''}',
                                    style: AppText.body14,
                                  ),
                                  if (creativeText(
                                    o.afterSale['decisionNote'],
                                  ).isNotEmpty)
                                    Text(
                                      '卖家说明：${o.afterSale['decisionNote']}',
                                      style: AppText.body13,
                                    ),
                                  if (creativeText(
                                    o.afterSale['returnAddress'],
                                  ).isNotEmpty)
                                    Text(
                                      '寄回地址：${o.afterSale['returnAddress']}',
                                      style: AppText.body14Strong,
                                    ),
                                  if (creativeText(
                                    o.afterSale['tracking'],
                                  ).isNotEmpty)
                                    Text(
                                      '退货物流：${o.afterSale['carrier']} · ${o.afterSale['tracking']}',
                                      style: AppText.body13,
                                    ),
                                ],
                              ),
                            ),
                          AppCard(
                            title: '订单进展',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final e in o.events.reversed)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      spacing: 6,
                                      children: [
                                        Text(
                                          '${e['label']}',
                                          style: AppText.body14Strong,
                                        ),
                                        Text(
                                          '${e['time']} · ${e['actor']}',
                                          style: AppText.caption12,
                                        ),
                                        if (creativeText(e['note']).isNotEmpty)
                                          Text(
                                            '${e['note']}',
                                            style: AppText.body13,
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _guidance(MarketOrder o, bool seller) => switch (o.status) {
    MarketOrderStatus.pendingPayment =>
      '等待买家付款，保留至 ${o.expiresAt}。逾期自动关闭并释放库存。',
    MarketOrderStatus.awaitingShipment =>
      seller ? '买家已完成模拟支付，请核对收货地址并在约定时间内发货。' : '已完成模拟支付，等待卖家发货。',
    MarketOrderStatus.shipped => '作品已寄出，请按物流单号查询运输进展。收到并核对后由买家确认收货。',
    MarketOrderStatus.completed =>
      o.listing.kind == MarketKind.digital
          ? '数字文件与许可凭证已交付。请按订单中的授权范围使用。'
          : '买家已确认收货，本次交易完成。',
    MarketOrderStatus.refundRequested => '售后申请已提交，等待卖家处理。',
    MarketOrderStatus.returnRequired => '卖家已同意退货，请按售后地址寄回作品。',
    MarketOrderStatus.returnShipped => '作品已寄回，等待卖家签收并完成模拟退款。',
    MarketOrderStatus.refunded =>
      o.listing.kind == MarketKind.digital
          ? '模拟退款已完成，未发生真实资金转移。数字授权访问已结束。'
          : '模拟退款已完成，未发生真实资金转移。本次实物交易已结束。',
    MarketOrderStatus.cancelled ||
    MarketOrderStatus.expired => '订单已关闭，预留库存已释放。',
    _ => '请刷新查看订单进展。',
  };
}

class MarketDeliveryDrawer extends ConsumerStatefulWidget {
  const MarketDeliveryDrawer({required this.orderId, super.key});
  final String orderId;
  @override
  ConsumerState<MarketDeliveryDrawer> createState() =>
      _MarketDeliveryDrawerState();
}

class _MarketDeliveryDrawerState extends ConsumerState<MarketDeliveryDrawer> {
  bool _busy = false;
  String _error = '';
  Future<void> _save([int? index]) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final result = await MarketDeliveryService(
        ref.read(marketRepositoryProvider),
      ).save(widget.orderId, fileIndex: index);
      if (mounted) AppToast.showSuccess(context, result);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e'.replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(marketDeliveryProvider(widget.orderId));
    return AppDrawer(
      title: '数字文件与许可凭证',
      width: 560,
      child: data.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppErrorState(
          title: '暂时无法获取交付',
          description: '$e'.replaceFirst('Bad state: ', ''),
          onRetry: () => ref.invalidate(marketDeliveryProvider(widget.orderId)),
        ),
        data: (d) {
          final files = creativeRows(d['files']);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Text('${d['title']}', style: AppText.title20),
              Text('${d['licenseNumber']}', style: AppText.caption12),
              Text('${d['terms']}', style: AppText.body14),
              AppButton(
                label: '保存许可凭证',
                variant: AppButtonVariant.secondary,
                onTap: _busy ? null : _save,
              ),
              for (var i = 0; i < files.length; i++)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      Text(
                        '文件 ${i + 1} · ${files[i]['kind'] == 'pdf' ? 'PDF' : '图片'}',
                        style: AppText.title16,
                      ),
                      if (files[i]['kind'] != 'pdf')
                        AppImage(
                          src: creativeText(files[i]['url']),
                          height: 180,
                          fit: BoxFit.contain,
                        ),
                      Wrap(
                        spacing: 12,
                        children: [
                          AppButton(
                            label: '预览文件 ${i + 1}',
                            variant: AppButtonVariant.secondary,
                            onTap: () => files[i]['kind'] == 'pdf'
                                ? Navigator.of(context).push(
                                    PageRouteBuilder<void>(
                                      transitionDuration: Duration.zero,
                                      reverseTransitionDuration: Duration.zero,
                                      pageBuilder: (_, _, _) => Scaffold(
                                        appBar: AppBar(
                                          title: Text(
                                            '${d['title']} · ${i + 1}',
                                          ),
                                        ),
                                        body: CreativePdfReader(
                                          url: creativeText(files[i]['url']),
                                        ),
                                      ),
                                    ),
                                  )
                                : showImageGallery(
                                    context,
                                    images: [creativeText(files[i]['url'])],
                                    titles: ['${d['title']} · ${i + 1}'],
                                  ),
                          ),
                          AppButton(
                            label: '保存文件 ${i + 1}',
                            loading: _busy,
                            onTap: _busy ? null : () => _save(i),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (_error.isNotEmpty)
                AppNotice(message: _error, tone: AppTone.danger),
            ],
          );
        },
      ),
    );
  }
}
