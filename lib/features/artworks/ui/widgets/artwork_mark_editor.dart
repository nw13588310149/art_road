import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/artwork_models.dart';
import '../../data/artwork_rules.dart';
import 'artwork_mark_layer.dart';
import 'artwork_mark_list.dart';
import 'artwork_mark_response.dart';
import 'artwork_voice_comment_field.dart';

/// 点评工作台「定点点评」模式下的右栏：选中一处时编辑它的文字和语音，下面列出
/// 我在这份作品上的全部定点点评。改动随点评一起保存。
class ArtworkMarkEditorPanel extends StatelessWidget {
  const ArtworkMarkEditorPanel({
    required this.marks,
    required this.selected,
    required this.textController,
    required this.textFocus,
    required this.onTextChanged,
    required this.onVoiceChanged,
    required this.onUpload,
    required this.onDelete,
    required this.onSelect,
    super.key,
  });

  final List<NumberedArtworkMark> marks;
  final NumberedArtworkMark? selected;
  final TextEditingController textController;
  final FocusNode textFocus;
  final ValueChanged<String> onTextChanged;
  final void Function(String path, int seconds) onVoiceChanged;
  final ArtworkVoiceUpload onUpload;
  final VoidCallback onDelete;
  final ValueChanged<NumberedArtworkMark> onSelect;

  @override
  Widget build(BuildContext context) {
    final current = selected;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(
            title: '定点点评',
            titleStyle: AppText.title16,
            subtitle: marks.isEmpty
                ? null
                : ArtworkRules.markCount(marks.map((m) => m.mark)),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            '点画上要说的位置加一处，写一句话或录一段语音；按住编号可以拖动。'
            '每张图最多 ${ArtworkRules.marksPerImage} 处，随点评一起保存。',
            style: AppText.body13,
          ),
          const SizedBox(height: AppSpace.s16),
          if (current != null) ...[
            Row(
              children: [
                ArtworkMarkDot(number: current.number, size: 24),
                const SizedBox(width: AppSpace.s8),
                Text('第 ${current.number} 处', style: AppText.title16),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: switch (current.mark.response?.status) {
                      final status? => ArtworkMarkResponseLabel(status: status),
                      null => const SizedBox.shrink(),
                    },
                  ),
                ),
                AppIconAction(
                  icon: Icons.delete_outline_rounded,
                  semanticLabel: '删除第 ${current.number} 处点评',
                  onTap: onDelete,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s8),
            AppInputField(
              controller: textController,
              focusNode: textFocus,
              hint: '这一处的问题，例如：三大面区分不够，亮面和灰面要拉开',
              multiline: true,
              minLines: 3,
              maxLines: 5,
              maxLength: ArtworkRules.markTextLimit,
              onChanged: onTextChanged,
            ),
            const SizedBox(height: AppSpace.s12),
            Text('语音（可选）', style: AppText.caption12Strong),
            const SizedBox(height: AppSpace.s8),
            ArtworkVoiceCommentField(
              key: ValueKey<String>('mark-voice-${current.mark.id}'),
              path: current.mark.voiceUrl,
              seconds: current.mark.voiceSeconds,
              onUpload: onUpload,
              onChanged: onVoiceChanged,
            ),
            const SizedBox(height: AppSpace.s16),
            const AppRule(),
          ] else if (marks.isNotEmpty) ...[
            Text('点下面的一处可以修改或删除。', style: AppText.caption12),
            const SizedBox(height: AppSpace.s8),
            const AppRule(),
          ],
          if (marks.isEmpty)
            Text('还没有定点点评。', style: AppText.caption12)
          else
            ArtworkMarkList(
              marks: marks,
              selectedKey: current?.key,
              maxLines: 2,
              showResponse: true,
              onSelect: onSelect,
            ),
        ],
      ),
    );
  }
}
