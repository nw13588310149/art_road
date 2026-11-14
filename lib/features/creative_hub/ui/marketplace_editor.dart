import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../courseware/ui/courseware_file_picker.dart';
import '../data/creative_models.dart';
import '../state/creative_controllers.dart';
import 'creative_widgets.dart';

class MarketplaceEditor extends ConsumerStatefulWidget {
  const MarketplaceEditor({required this.onClose, super.key});
  final VoidCallback onClose;
  @override
  ConsumerState<MarketplaceEditor> createState() => _MarketplaceEditorState();
}

class _MarketplaceEditorState extends ConsumerState<MarketplaceEditor> {
  final _title = TextEditingController(),
      _description = TextEditingController(),
      _price = TextEditingController(text: '18.00');
  String _subject = '素描',
      _imageId = '',
      _artworkId = '',
      _cover = '',
      _error = '';
  bool _sale = false, _rights = false, _uploading = false;
  MarketLicense _license = MarketLicense.study;
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    setState(() => _uploading = true);
    try {
      final files = await pickCoursewareFiles(
        allowMultiple: false,
        type: CoursewarePickType.image,
      );
      if (files.isEmpty) return;
      final resource = await ref
          .read(creativeUploadProvider.notifier)
          .upload(
            name: files.first.name,
            bytes: files.first.bytes,
            path: files.first.path,
          );
      if (mounted) {
        setState(() {
          _imageId = resource.id;
          _artworkId = '';
          _cover = resource.cover;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error'.replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final money = double.tryParse(_price.text.trim());
    if (_sale &&
        (money == null ||
            !money.isFinite ||
            !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(_price.text.trim()))) {
      setState(() => _error = '售价须为有效金额，最多两位小数');
      return;
    }
    if (_cover.isEmpty) {
      setState(() => _error = '请先选择作品图片');
      return;
    }
    final error = await ref.read(marketplaceProvider.notifier).publish({
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'subject': _subject,
      'imageId': _imageId,
      'artworkId': _artworkId,
      'forSale': _sale,
      'priceCents': ((money ?? 0) * 100).round(),
      'license': _license.key,
      'rightsConfirmed': _rights,
    });
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
    } else {
      AppToast.showSuccess(context, '作品已发布到集市');
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(creativeUploadProvider);
    final resources = ref.watch(readingResourcesProvider);
    final own = ref.watch(marketMyArtworksProvider);
    final busy = ref.watch(marketplaceProvider.select((state) => state.busy));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          CreativeHeading(
            title: '发布到集市',
            subtitle: '分享原创作品，清楚说明它可以如何被使用。',
            onBack: busy ? null : widget.onClose,
            actions: [
              AppButton(
                label: '发布到集市',
                loading: busy,
                onTap: busy || _uploading ? null : _save,
              ),
            ],
          ),
          if (_error.isNotEmpty)
            AppNotice(message: _error, tone: AppTone.danger),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 20,
              children: [
                Expanded(
                  flex: 5,
                  child: ListView(
                    children: [
                      AppCard(
                        title: '作品图片',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 12,
                          children: [
                            if (_cover.isEmpty)
                              Container(
                                height: 210,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  borderRadius: AppRadius.br12,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 32,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text('上传作品，或选择下方示例', style: AppText.body14),
                                  ],
                                ),
                              )
                            else
                              AppImage(
                                src: _cover,
                                height: 250,
                                fit: BoxFit.contain,
                              ),
                            AppButton(
                              label: '上传作品图片',
                              icon: Icons.file_upload_outlined,
                              variant: AppButtonVariant.secondary,
                              loading: _uploading,
                              onTap: _uploading || busy ? null : _upload,
                            ),
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
                          title: '从我的作品中选择',
                          child: Column(
                            children: [
                              for (final work in own.asData!.value.take(6))
                                AppListRow(
                                  title: creativeText(work['title']),
                                  leading: AppImage(
                                    src: creativeText(work['cover']),
                                    width: 42,
                                    height: 42,
                                  ),
                                  trailing: _artworkId == work['id']
                                      ? const Icon(
                                          Icons.check,
                                          size: 18,
                                          color: AppColors.brand,
                                        )
                                      : null,
                                  onTap: () => setState(() {
                                    _artworkId = creativeText(work['id']);
                                    _imageId = '';
                                    _cover = creativeText(work['cover']);
                                    if (_title.text.isEmpty) {
                                      _title.text = creativeText(work['title']);
                                    }
                                  }),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      AppCard(
                        title: '演示素材',
                        subtitle: '用于体验发布流程',
                        child: resources.when(
                          loading: () => const AppLoadingIndicator(),
                          error: (_, _) => const Text('示例暂不可用，请上传作品'),
                          data: (items) => Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final item in items.where(
                                (r) => r.id.startsWith('sample-'),
                              ))
                                AppPressable(
                                  semanticLabel: '选择${item.title}',
                                  onTap: () => setState(() {
                                    _imageId = item.id;
                                    _artworkId = '';
                                    _cover = item.cover;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      borderRadius: AppRadius.br8,
                                      border: Border.all(
                                        color: _imageId == item.id
                                            ? AppColors.brand
                                            : AppColors.line,
                                      ),
                                    ),
                                    child: AppImage(
                                      src: item.cover,
                                      width: 76,
                                      height: 72,
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
                              onChanged: (value) =>
                                  setState(() => _subject = value),
                            ),
                            AppInputField(
                              controller: _description,
                              label: '创作说明',
                              required: true,
                              multiline: true,
                              maxLength: 1000,
                              hint: '分享观察、材料与创作过程',
                            ),
                            AppSegmented<bool>(
                              value: _sale,
                              onChanged: (value) =>
                                  setState(() => _sale = value),
                              segments: const [
                                AppSegment(value: false, label: '仅展示'),
                                AppSegment(value: true, label: '出售使用许可'),
                              ],
                            ),
                            if (_sale) ...[
                              AppInputField(
                                controller: _price,
                                label: '售价（元）',
                                hint: '1.00–1000.00',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                              AppSelect<MarketLicense>(
                                value: _license,
                                onChanged: (value) =>
                                    setState(() => _license = value),
                                options: [
                                  for (final license in MarketLicense.values)
                                    AppSelectOption(
                                      value: license,
                                      label: license.label,
                                    ),
                                ],
                              ),
                              Text(_license.description, style: AppText.body13),
                              const AppNotice(
                                message: '当前为演示交易，不收取真实款项。许可不表示著作权转让。',
                                tone: AppTone.neutral,
                              ),
                            ],
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppCheckbox(
                                  semanticLabel: '确认作品发布权限',
                                  value: _rights,
                                  onChanged: (value) =>
                                      setState(() => _rights = value),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '我确认拥有这份作品的发布权限，或正在使用提供的演示素材。',
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
    );
  }
}
