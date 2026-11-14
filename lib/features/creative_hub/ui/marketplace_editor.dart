import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ui/ui.dart';
import '../../courseware/ui/courseware_file_picker.dart';
import '../data/creative_models.dart';
import '../state/creative_controllers.dart';
import '../state/market_controller.dart';
import 'creative_widgets.dart';

class MarketplaceEditor extends ConsumerStatefulWidget {
  const MarketplaceEditor({required this.onClose, this.initial, super.key});
  final VoidCallback onClose;
  final MarketListing? initial;
  @override
  ConsumerState<MarketplaceEditor> createState() => _MarketplaceEditorState();
}

class _MarketplaceEditorState extends ConsumerState<MarketplaceEditor> {
  final _title = TextEditingController(),
      _description = TextEditingController(),
      _price = TextEditingController(text: '18.00'),
      _shipping = TextEditingController(text: '12.00'),
      _stock = TextEditingController(text: '1'),
      _dispatch = TextEditingController(text: '3'),
      _specification = TextEditingController(),
      _rightsNote = TextEditingController();
  String _subject = '素描',
      _imageId = '',
      _artworkId = '',
      _cover = '',
      _error = '';
  MarketKind _kind = MarketKind.showcase;
  MarketLicense _license = MarketLicense.study;
  final _deliveryIds = <String>{};
  bool _rights = false,
      _dirty = false,
      _uploading = false,
      _deliverOriginal = false;
  List<TextEditingController> get _fields => [
    _title,
    _description,
    _price,
    _shipping,
    _stock,
    _dispatch,
    _specification,
    _rightsNote,
  ];
  @override
  void initState() {
    super.initState();
    final row = widget.initial;
    if (row != null) {
      _title.text = row.title;
      _description.text = row.description;
      _price.text = (row.priceCents / 100).toStringAsFixed(2);
      _shipping.text = (row.shippingCents / 100).toStringAsFixed(2);
      _stock.text = '${row.stock}';
      _dispatch.text = '${row.dispatchDays}';
      _specification.text = row.specification;
      _rightsNote.text = row.rightsNote;
      _kind = row.kind;
      _license = row.license;
      _subject = row.subject;
      _imageId = row.imageId;
      _artworkId = row.artworkId;
      _cover = row.cover;
      _deliveryIds.addAll(row.deliveryIds);
    }
    for (final c in _fields) {
      c.addListener(() => _dirty = true);
    }
  }

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _close() async {
    if (_dirty) {
      final discard = await showAppConfirm(
        context: context,
        title: '离开未保存的作品？',
        message: '可先保存草稿，再回来继续编辑。直接离开会丢失本次修改。',
        confirmLabel: '放弃修改',
        cancelLabel: '继续编辑',
        danger: true,
      );
      if (!discard || !mounted) return;
    }
    widget.onClose();
  }

  Future<void> _upload({bool delivery = false}) async {
    setState(() => _uploading = true);
    try {
      final files = await pickCoursewareFiles(
        allowMultiple: false,
        type: delivery ? CoursewarePickType.any : CoursewarePickType.image,
      );
      if (files.isEmpty) return;
      final file = files.first;
      final resource = await ref
          .read(creativeUploadProvider.notifier)
          .upload(name: file.name, bytes: file.bytes, path: file.path);
      if (!mounted) return;
      setState(() {
        _dirty = true;
        if (delivery) {
          _deliveryIds.add(resource.id);
        } else {
          _imageId = resource.id;
          _artworkId = '';
          _cover = resource.cover;
        }
      });
      ref.invalidate(readingResourcesProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e'.replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save(bool submit) async {
    final price = marketCents(_price.text),
        shipping = marketCents(_shipping.text);
    String? error;
    if (submit && _cover.isEmpty) {
      error = '请先选择作品图片';
    } else if (_kind != MarketKind.showcase && (price == null || price < 100)) {
      error = '售价须为 1 至 100000 元，最多两位小数';
    } else if (_kind == MarketKind.physical &&
        (shipping == null ||
            int.tryParse(_stock.text) == null ||
            int.tryParse(_dispatch.text) == null)) {
      error = '请填写有效运费、库存与发货时限';
    }
    if (error != null) {
      setState(() => _error = error!);
      return;
    }
    final result = await ref.read(commerceProvider.notifier).saveListing({
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'subject': _subject,
      'imageId': _imageId,
      'artworkId': _artworkId,
      'kind': _kind.key,
      'priceCents': _kind == MarketKind.showcase ? 0 : price,
      'license': _license.key,
      'rightsConfirmed': _rights,
      'rightsNote': _rightsNote.text.trim(),
      'submit': submit,
      'stock': int.tryParse(_stock.text) ?? 1,
      'dispatchDays': int.tryParse(_dispatch.text) ?? 3,
      'shippingCents': shipping ?? 0,
      'specification': _specification.text.trim(),
      'deliveryIds': _deliveryIds.toList(),
      'deliverArtwork': _deliverOriginal,
    }, id: widget.initial?.id);
    if (!mounted) return;
    if (!result.success) {
      setState(() => _error = result.error);
    } else {
      _dirty = false;
      AppToast.showSuccess(context, submit ? '已提交审核，通过后公开上架' : '草稿已保存');
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(creativeUploadProvider);
    final resources = ref.watch(readingResourcesProvider);
    final own = ref.watch(marketMyArtworksProvider);
    final busy = ref.watch(commerceProvider.select((s) => s.busy));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && !busy && !_uploading) _close();
      },
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CreativeHeading(
              title: widget.initial == null ? '发布到集市' : '编辑作品',
              subtitle: '作品、交易方式与交付内容一并审核。',
              onBack: busy || _uploading ? null : _close,
              actions: [
                AppButton(
                  label: '保存草稿',
                  variant: AppButtonVariant.secondary,
                  onTap: busy || _uploading ? null : () => _save(false),
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: '提交审核',
                  loading: busy,
                  onTap: busy || _uploading ? null : () => _save(true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppNotice(message: _error, tone: AppTone.danger),
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: ListView(
                      children: [
                        AppCard(
                          title: '作品图片',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_cover.isEmpty)
                                Container(
                                  height: 210,
                                  alignment: Alignment.center,
                                  color: AppColors.surfaceSubtle,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 32,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '上传作品或选择下方示例',
                                        style: AppText.body13,
                                      ),
                                    ],
                                  ),
                                )
                              else
                                AppImage(
                                  src: _cover,
                                  height: 230,
                                  fit: BoxFit.contain,
                                ),
                              const SizedBox(height: 12),
                              AppButton(
                                label: '上传作品图片',
                                icon: Icons.file_upload_outlined,
                                variant: AppButtonVariant.secondary,
                                loading: _uploading,
                                onTap: busy || _uploading
                                    ? null
                                    : () => _upload(),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'JPG / PNG / WebP · 不超过 20 MB',
                                style: AppText.caption12,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (own.asData?.value.isNotEmpty == true)
                          AppCard(
                            title: '我的作品',
                            child: Column(
                              children: [
                                for (final work in own.asData!.value.take(6))
                                  AppListRow(
                                    title: creativeText(work['title']),
                                    leading: AppImage(
                                      src: creativeText(work['cover']),
                                      width: 40,
                                      height: 40,
                                    ),
                                    trailing: _artworkId == work['id']
                                        ? const Icon(
                                            Icons.check,
                                            color: AppColors.brand,
                                            size: 18,
                                          )
                                        : null,
                                    onTap: () => setState(() {
                                      _dirty = true;
                                      _artworkId = creativeText(work['id']);
                                      _imageId = '';
                                      _cover = creativeText(work['cover']);
                                      if (_title.text.isEmpty) {
                                        _title.text = creativeText(
                                          work['title'],
                                        );
                                      }
                                    }),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        AppCard(
                          title: '演示素材',
                          subtitle: '体验发布流程',
                          child: resources.when(
                            loading: () => const AppLoadingIndicator(),
                            error: (_, _) => AppButton(
                              label: '重新加载素材',
                              onTap: () =>
                                  ref.invalidate(readingResourcesProvider),
                            ),
                            data: (items) => Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final r in items.where(
                                  (r) => r.id.startsWith('sample-'),
                                ))
                                  AppPressable(
                                    semanticLabel: '选择${r.title}',
                                    selected: _imageId == r.id,
                                    onTap: () => setState(() {
                                      _dirty = true;
                                      _imageId = r.id;
                                      _artworkId = '';
                                      _cover = r.cover;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        borderRadius: AppRadius.br8,
                                        border: Border.all(
                                          color: _imageId == r.id
                                              ? AppColors.brand
                                              : AppColors.line,
                                        ),
                                      ),
                                      child: AppImage(
                                        src: r.cover,
                                        width: 70,
                                        height: 68,
                                        fit: BoxFit.cover,
                                        borderRadius: AppRadius.br4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 6,
                    child: ListView(
                      children: [
                        AppCard(
                          title: '创作信息',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 16,
                            children: [
                              AppInputField(
                                controller: _title,
                                label: '作品名称',
                                required: true,
                                maxLength: 40,
                                hint: '给这份创作起个名字',
                              ),
                              CreativeSubjectSelect(
                                value: _subject,
                                onChanged: (v) => setState(() {
                                  _subject = v;
                                  _dirty = true;
                                }),
                              ),
                              AppInputField(
                                controller: _description,
                                label: '创作说明',
                                required: true,
                                multiline: true,
                                maxLength: 1000,
                                hint: '分享观察、材料与创作过程',
                              ),
                              Text('交易方式', style: AppText.title16),
                              AppSelect<MarketKind>(
                                value: _kind,
                                options: [
                                  for (final k in MarketKind.values)
                                    AppSelectOption(value: k, label: k.label),
                                ],
                                onChanged: (v) => setState(() {
                                  _kind = v;
                                  _dirty = true;
                                }),
                              ),
                              if (_kind != MarketKind.showcase)
                                AppInputField(
                                  controller: _price,
                                  label: '售价（元）',
                                  required: true,
                                  hint: '1.00–100000.00',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              if (_kind == MarketKind.digital) ...[
                                AppSelect<MarketLicense>(
                                  value: _license,
                                  options: [
                                    for (final l in MarketLicense.values)
                                      AppSelectOption(value: l, label: l.label),
                                  ],
                                  onChanged: (v) => setState(() {
                                    _license = v;
                                    _dirty = true;
                                  }),
                                ),
                                Text(
                                  _license.description,
                                  style: AppText.body13,
                                ),
                                const Divider(height: 1),
                                Text('数字交付文件', style: AppText.title16),
                                Text(
                                  '封面用于公开预览。选中的原图或 PDF 在付款后交付，每份不超过 20 MB。',
                                  style: AppText.body13.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                AppButton(
                                  label: '上传交付文件',
                                  variant: AppButtonVariant.secondary,
                                  loading: _uploading,
                                  onTap: busy || _uploading
                                      ? null
                                      : () => _upload(delivery: true),
                                ),
                                if (_artworkId.isNotEmpty)
                                  Row(
                                    children: [
                                      AppCheckbox(
                                        semanticLabel: '将本人作品原图交付',
                                        value: _deliverOriginal,
                                        onChanged: (v) => setState(() {
                                          _dirty = true;
                                          _deliverOriginal = v;
                                        }),
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(child: Text('交付所选作品的原图')),
                                    ],
                                  ),
                                for (final r
                                    in resources.asData?.value.where(
                                          (r) =>
                                              r.id.startsWith('sample-') ||
                                              r.id.startsWith('resource-') ||
                                              _deliveryIds.contains(r.id),
                                        ) ??
                                        <ReadingResource>[])
                                  Row(
                                    children: [
                                      AppCheckbox(
                                        semanticLabel: '交付${r.title}',
                                        value: _deliveryIds.contains(r.id),
                                        onChanged: (v) => setState(() {
                                          _dirty = true;
                                          v
                                              ? _deliveryIds.add(r.id)
                                              : _deliveryIds.remove(r.id);
                                        }),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          r.title,
                                          style: AppText.body13,
                                        ),
                                      ),
                                      AppTag(label: r.isPdf ? 'PDF' : '图片'),
                                    ],
                                  ),
                                if (widget.initial != null &&
                                    widget.initial!.deliveryCount > 0 &&
                                    _deliveryIds.isEmpty)
                                  Text(
                                    '原有 ${widget.initial!.deliveryCount} 份文件保持可用；选择新文件后替换。',
                                    style: AppText.caption12,
                                  ),
                              ],
                              if (_kind == MarketKind.physical) ...[
                                AppInputField(
                                  controller: _specification,
                                  label: '规格与品相',
                                  required: true,
                                  multiline: true,
                                  maxLength: 200,
                                  hint: '材料、尺寸、装裱、创作年份及瑕疵',
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppInputField(
                                        controller: _stock,
                                        label: '库存（件）',
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: AppInputField(
                                        controller: _shipping,
                                        label: '运费（元）',
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                AppInputField(
                                  controller: _dispatch,
                                  label: '付款后发货时限（天）',
                                  hint: '1–30 天',
                                  keyboardType: TextInputType.number,
                                ),
                                Text(
                                  '原作建议库存为 1。运费计入订单，实物购买不转让著作权。',
                                  style: AppText.body13,
                                ),
                              ],
                              AppInputField(
                                controller: _rightsNote,
                                label: '创作与权属说明',
                                multiline: true,
                                maxLength: 500,
                                hint: '创作者、创作时间与授权来源',
                              ),
                              Row(
                                children: [
                                  AppCheckbox(
                                    semanticLabel: '确认作品发布权限',
                                    value: _rights,
                                    onChanged: (v) => setState(() {
                                      _rights = v;
                                      _dirty = true;
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '我有权发布并按上述范围出售此作品。演示素材仅用于体验。',
                                      style: AppText.body13,
                                    ),
                                  ),
                                ],
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
      ),
    );
  }
}
