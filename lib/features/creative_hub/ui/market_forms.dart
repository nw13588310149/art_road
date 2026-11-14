import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ui/ui.dart';
import '../data/creative_models.dart';
import '../state/market_controller.dart';

class MarketFormField {
  const MarketFormField(
    this.key,
    this.label, {
    this.initial = '',
    this.lines = 1,
    this.max = 500,
  });
  final String key, label, initial;
  final int lines, max;
}

Future<bool> showMarketForm(
  BuildContext context, {
  required String title,
  required String explanation,
  required List<MarketFormField> fields,
  required Future<MarketResult<dynamic>> Function(CreativeJson) save,
  String confirmLabel = '提交',
}) async =>
    await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MarketForm(
        title: title,
        explanation: explanation,
        fields: fields,
        save: save,
        confirmLabel: confirmLabel,
      ),
    ) ??
    false;

class _MarketForm extends StatefulWidget {
  const _MarketForm({
    required this.title,
    required this.explanation,
    required this.fields,
    required this.save,
    required this.confirmLabel,
  });
  final String title, explanation, confirmLabel;
  final List<MarketFormField> fields;
  final Future<MarketResult<dynamic>> Function(CreativeJson) save;
  @override
  State<_MarketForm> createState() => _MarketFormState();
}

class _MarketFormState extends State<_MarketForm> {
  late final _inputs = {
    for (final f in widget.fields)
      f.key: TextEditingController(text: f.initial),
  };
  bool _busy = false;
  String _error = '';
  @override
  void dispose() {
    for (final c in _inputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_inputs.values.any((c) => c.text.trim().isEmpty)) {
      setState(() => _error = '请填写完整后提交');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final result = await widget.save({
      for (final e in _inputs.entries) e.key: e.value.text.trim(),
    });
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = result.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AppDialog(
      title: widget.title,
      message: widget.explanation,
      width: 520,
      actions: [
        AppButton(
          label: '取消',
          variant: AppButtonVariant.secondary,
          onTap: _busy ? null : () => Navigator.pop(context, false),
        ),
        AppButton(
          label: widget.confirmLabel,
          loading: _busy,
          onTap: _busy ? null : _save,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          for (final f in widget.fields)
            AppInputField(
              controller: _inputs[f.key],
              label: f.label,
              hint: f.label,
              multiline: f.lines > 1,
              minLines: f.lines,
              maxLines: f.lines,
              maxLength: f.max,
            ),
          if (_error.isNotEmpty)
            AppNotice(message: _error, tone: AppTone.danger),
        ],
      ),
    ),
  );
}

Future<bool> editMarketAddress(
  BuildContext context,
  WidgetRef ref, [
  MarketAddress? address,
]) => showMarketForm(
  context,
  title: address == null ? '新增收货地址' : '编辑收货地址',
  explanation: '请填写可接收作品的联系人和完整地址。已创建订单中的地址不会随此处更改。',
  confirmLabel: '保存地址',
  fields: [
    MarketFormField('name', '收货人', initial: address?.name ?? '', max: 30),
    MarketFormField('phone', '联系电话', initial: address?.phone ?? '', max: 11),
    MarketFormField(
      'detail',
      '省市区及详细地址',
      initial: address?.detail ?? '',
      lines: 3,
      max: 200,
    ),
  ],
  save: (body) => ref.read(commerceProvider.notifier).saveAddress({
    ...body,
    if (address != null) 'id': address.id,
    'default': address?.isDefault ?? true,
  }),
);

class MarketCheckout extends ConsumerStatefulWidget {
  const MarketCheckout({required this.listing, super.key});
  final MarketListing listing;
  @override
  ConsumerState<MarketCheckout> createState() => _MarketCheckoutState();
}

class _MarketCheckoutState extends ConsumerState<MarketCheckout> {
  String? _addressId;
  bool _accepted = false;
  String _error = '';
  Future<void> _submit(MarketAddress? address) async {
    if (!_accepted) {
      setState(() => _error = '请阅读并确认交易说明');
      return;
    }
    if (widget.listing.kind == MarketKind.physical && address == null) {
      setState(() => _error = '请先添加并选择收货地址');
      return;
    }
    final result = await ref
        .read(commerceProvider.notifier)
        .checkout(widget.listing, address: address);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context, result.value);
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commerceProvider);
    final w = widget.listing;
    final address =
        state.addresses.where((a) => a.id == _addressId).firstOrNull ??
        state.addresses.where((a) => a.isDefault).firstOrNull ??
        state.addresses.firstOrNull;
    return PopScope(
      canPop: !state.busy,
      child: AppDrawer(
        title: '确认订单',
        subtitle: '演示交易 · 不收取真实款项',
        width: 560,
        onClose: state.busy ? () {} : () => Navigator.pop(context),
        actions: [
          AppButton(
            label: '创建订单 · ${marketMoney(w.totalCents)}',
            loading: state.busy,
            onTap: state.busy ? null : () => _submit(address),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Row(
              children: [
                AppImage(
                  src: w.cover,
                  width: 80,
                  height: 96,
                  fit: BoxFit.cover,
                  borderRadius: AppRadius.br8,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      Text(w.title, style: AppText.title16),
                      Text(
                        '${w.author} · ${w.kind.label}',
                        style: AppText.body13,
                      ),
                      Text(w.priceLabel, style: AppText.number(size: 20)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: AppColors.line),
            if (w.kind == MarketKind.physical) ...[
              Text('收货地址', style: AppText.title16),
              for (final a in state.addresses)
                AppCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () => setState(() => _addressId = a.id),
                  child: Row(
                    children: [
                      Icon(
                        a.id == address?.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: a.id == address?.id
                            ? AppColors.brand
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${a.name} · ${a.phone}',
                              style: AppText.body14Strong,
                            ),
                            Text(a.detail, style: AppText.body13),
                          ],
                        ),
                      ),
                      AppIconButton(
                        icon: Icons.edit_outlined,
                        semanticLabel: '编辑${a.name}的地址',
                        filled: false,
                        onTap: () => editMarketAddress(context, ref, a),
                      ),
                    ],
                  ),
                ),
              AppButton(
                label: '新增收货地址',
                variant: AppButtonVariant.secondary,
                icon: Icons.add,
                onTap: () => editMarketAddress(context, ref),
              ),
              Text(
                '${w.specification}\n付款后 ${w.dispatchDays} 天内发货；运费 ${marketMoney(w.shippingCents)}。',
                style: AppText.body14,
              ),
              Text('实物购买不包含著作权或商业使用权。收到作品后请核对状态，再确认收货。', style: AppText.body13),
            ] else ...[
              Text(w.license.label, style: AppText.title16),
              Text(w.terms, style: AppText.body14),
              Text(
                '付款后交付 ${w.deliveryCount} 份数字文件；授权非独占。发生交付或权属问题，可从订单申请售后。',
                style: AppText.body13,
              ),
            ],
            const Divider(color: AppColors.line),
            marketLine('作品金额', w.priceLabel),
            if (w.kind == MarketKind.physical)
              marketLine('运费', marketMoney(w.shippingCents)),
            marketLine('合计', marketMoney(w.totalCents)),
            Text(
              '订单创建后保留 30 分钟。支付前可取消；超时将释放实物库存。价格、授权条款和收货地址将保存在本次订单中。',
              style: AppText.caption12,
            ),
            AppCheckbox(
              label: '我已阅读并同意以上交易说明',
              value: _accepted,
              onChanged: state.busy
                  ? null
                  : (v) => setState(() {
                      _accepted = v;
                      _error = '';
                    }),
            ),
            if (_error.isNotEmpty)
              AppNotice(message: _error, tone: AppTone.danger),
          ],
        ),
      ),
    );
  }
}

Widget marketLine(String label, String value) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(width: 100, child: Text(label, style: AppText.body13)),
    Expanded(
      child: Text(value, style: AppText.body14Strong, textAlign: TextAlign.end),
    ),
  ],
);

class MarketAddressBook extends ConsumerWidget {
  const MarketAddressBook({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(commerceProvider);
    return AppDrawer(
      title: '收货地址',
      subtitle: '地址修改不会影响已有订单',
      width: 560,
      actions: [
        AppButton(
          label: '新增收货地址',
          icon: Icons.add,
          onTap: state.busy ? null : () => editMarketAddress(context, ref),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          if (state.addresses.isEmpty)
            const AppEmptyState(
              title: '还没有收货地址',
              description: '购买实物作品前，可在这里保存常用地址。',
            ),
          for (final a in state.addresses)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Text('${a.name} · ${a.phone}', style: AppText.title16),
                  Text(a.detail, style: AppText.body14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (a.isDefault)
                        const AppTag(label: '默认地址')
                      else
                        AppButton(
                          label: '设为默认',
                          size: AppButtonSize.sm,
                          variant: AppButtonVariant.secondary,
                          onTap: state.busy
                              ? null
                              : () async {
                                  final result = await ref
                                      .read(commerceProvider.notifier)
                                      .saveAddress({
                                        'id': a.id,
                                        'name': a.name,
                                        'phone': a.phone,
                                        'detail': a.detail,
                                        'default': true,
                                      });
                                  if (context.mounted && !result.success) {
                                    AppToast.showError(context, result.error);
                                  }
                                },
                        ),
                      AppButton(
                        label: '编辑地址',
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.secondary,
                        onTap: state.busy
                            ? null
                            : () => editMarketAddress(context, ref, a),
                      ),
                      AppButton(
                        label: '删除地址',
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.secondary,
                        onTap: state.busy
                            ? null
                            : () async {
                                if (!await showAppConfirm(
                                      context: context,
                                      title: '删除收货地址',
                                      message: '删除后需重新填写，已有订单中的收货信息会保留。',
                                      danger: true,
                                      confirmLabel: '删除地址',
                                    ) ||
                                    !context.mounted) {
                                  return;
                                }
                                final result = await ref
                                    .read(commerceProvider.notifier)
                                    .removeAddress(a.id);
                                if (context.mounted && !result.success) {
                                  AppToast.showError(context, result.error);
                                }
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
