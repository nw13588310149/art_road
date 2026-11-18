import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/artwork_models.dart';
import '../../data/artwork_rules.dart';
import 'artwork_mark_layer.dart';
import 'artwork_mark_response.dart';
import 'artwork_voice_note.dart';

/// 共用播放器里一处定点点评的语音键。
String artworkMarkPlayKey(NumberedArtworkMark mark) => 'mark:${mark.key}';

String _semantics(
  NumberedArtworkMark item, {
  required bool showTeacher,
  bool showResponse = false,
}) => ArtworkRules.markSemantics(
  item.number,
  item.mark.text,
  hasVoice: item.mark.hasVoice,
  voiceSeconds: item.mark.voiceSeconds,
  teacherName: showTeacher ? item.teacherName : '',
  response: showResponse ? item.mark.response?.status : null,
);

/// 学生对一处标「改了 / 没看懂」，null 为取消。
typedef ArtworkMarkRespond =
    void Function(NumberedArtworkMark item, ArtworkMarkResponseStatus? status);

/// 定点点评列表：编号、这一处说的话、老师和语音，行间细线。点一行选中图上
/// 对应的编号。
class ArtworkMarkList extends StatelessWidget {
  const ArtworkMarkList({
    required this.marks,
    this.selectedKey,
    this.onSelect,
    this.showTeacher = false,
    this.maxLines,
    this.rowKeys,
    this.showResponse = false,
    this.onRespond,
    super.key,
  });

  /// 老师端：每行写出学生的回应（学生：改了 / 没看懂）。
  final bool showResponse;

  /// 作品主人：每行带「改了」「没看懂」两个回应。
  final ArtworkMarkRespond? onRespond;

  final List<NumberedArtworkMark> marks;
  final String? selectedKey;
  final ValueChanged<NumberedArtworkMark>? onSelect;

  /// 几位老师都留了定点点评时，每行写上是哪位老师。
  final bool showTeacher;

  /// 文字最多几行；不传时显示全文。
  final int? maxLines;

  /// 按 [NumberedArtworkMark.key] 取每一行的 key，选中图上编号后把那一行滚进视野。
  final Map<String, GlobalKey>? rowKeys;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < marks.length; i++) ...[
          if (i > 0) const AppRule(),
          _MarkRow(
            key: rowKeys?[marks[i].key],
            item: marks[i],
            selected: marks[i].key == selectedKey,
            showTeacher: showTeacher,
            maxLines: maxLines,
            showResponse: showResponse,
            onRespond: onRespond == null
                ? null
                : (status) => onRespond!(marks[i], status),
            onTap: onSelect == null ? null : () => onSelect!(marks[i]),
          ),
        ],
      ],
    );
  }
}

class _MarkRow extends StatelessWidget {
  const _MarkRow({
    required this.item,
    required this.selected,
    required this.showTeacher,
    this.maxLines,
    this.showResponse = false,
    this.onRespond,
    this.onTap,
    super.key,
  });

  final NumberedArtworkMark item;
  final bool selected;
  final bool showTeacher;
  final int? maxLines;
  final bool showResponse;
  final ValueChanged<ArtworkMarkResponseStatus?>? onRespond;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mark = item.mark;
    final text = mark.text.trim();
    final response = showResponse && onRespond == null
        ? mark.response?.status
        : null;
    Widget content = ExcludeSemantics(
      excluding: !mark.hasVoice,
      child: _MarkRowText(
        item: item,
        text: text,
        selected: selected,
        showTeacher: showTeacher,
        maxLines: maxLines,
      ),
    );
    if (response != null || onRespond != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          if (response != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s4),
              child: ExcludeSemantics(
                child: ArtworkMarkResponseLabel(status: response),
              ),
            ),
          if (onRespond case final respond?)
            ArtworkMarkResponseButtons(
              number: item.number,
              value: mark.response?.status,
              onChanged: respond,
            ),
        ],
      );
    }
    return AppPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: _semantics(
        item,
        showTeacher: showTeacher,
        showResponse: response != null,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: ArtworkMarkDot(
                  number: item.number,
                  selected: selected,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }
}

/// 一行里的文字、老师和语音。
class _MarkRowText extends StatelessWidget {
  const _MarkRowText({
    required this.item,
    required this.text,
    required this.selected,
    required this.showTeacher,
    this.maxLines,
  });

  final NumberedArtworkMark item;
  final String text;
  final bool selected;
  final bool showTeacher;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final mark = item.mark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.isEmpty ? '（只有语音）' : text,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
          style: text.isEmpty
              ? AppText.body14.copyWith(color: AppColors.textSecondary)
              : (selected ? AppText.body14Strong : AppText.body14),
        ),
        if (showTeacher && !mark.hasVoice)
          Text('${item.teacherName}老师', style: AppText.caption12),
        if (mark.hasVoice)
          Transform.translate(
            offset: const Offset(-6, 0),
            child: Row(
              children: [
                Flexible(
                  child: ArtworkVoiceNoteButton(
                    playKey: artworkMarkPlayKey(item),
                    source: mark.voiceUrl,
                    seconds: mark.voiceSeconds,
                  ),
                ),
                if (showTeacher)
                  Text(' · ${item.teacherName}老师', style: AppText.caption12),
              ],
            ),
          ),
      ],
    );
  }
}

/// 学生点图上的编号后弹出的小卡：第几处、哪位老师、这一处说的话和语音。
/// 出现时淡入，没有其他动画。
class ArtworkMarkPopover extends StatelessWidget {
  const ArtworkMarkPopover({
    required this.item,
    required this.onClose,
    this.showTeacher = false,
    this.onRespond,
    super.key,
  });

  final NumberedArtworkMark item;
  final VoidCallback onClose;
  final bool showTeacher;

  /// 作品主人：卡片下面带「改了」「没看懂」两个回应。
  final ValueChanged<ArtworkMarkResponseStatus?>? onRespond;

  static const double width = 264;

  @override
  Widget build(BuildContext context) {
    final mark = item.mark;
    final text = mark.text.trim();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 150),
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: Semantics(
        container: true,
        label: _semantics(item, showTeacher: showTeacher),
        child: Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.br8,
            border: Border.all(color: AppColors.line),
            boxShadow: AppShadow.popover,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ArtworkMarkDot(number: item.number, size: 22),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      showTeacher
                          ? '第 ${item.number} 处 · ${item.teacherName}老师'
                          : '第 ${item.number} 处',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption12Strong,
                    ),
                  ),
                  AppIconAction(
                    icon: Icons.close_rounded,
                    size: 18,
                    semanticLabel: '关闭这一处点评',
                    onTap: onClose,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.s12),
                child: Text(
                  text.isEmpty ? '老师在这里留了一段语音。' : text,
                  style: AppText.body14,
                ),
              ),
              if (mark.hasVoice)
                Transform.translate(
                  offset: const Offset(-6, 0),
                  child: ArtworkVoiceNoteButton(
                    playKey: artworkMarkPlayKey(item),
                    source: mark.voiceUrl,
                    seconds: mark.voiceSeconds,
                  ),
                ),
              if (onRespond case final respond?) ...[
                const SizedBox(height: AppSpace.s8),
                ArtworkMarkResponseButtons(
                  number: item.number,
                  value: mark.response?.status,
                  onChanged: respond,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
