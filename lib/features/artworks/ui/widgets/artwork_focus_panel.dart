import 'package:flutter/material.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../core/art/art_subject.dart';
import '../../../../core/ui/ui.dart';
import '../../data/artwork_models.dart';
import '../artwork_upload_dialog.dart';

/// 首页与作品成长共用：统计口径、问题证据与下一步练习保持一致。
class ArtworkFocusPanel extends StatelessWidget {
  const ArtworkFocusPanel({
    required this.levels,
    this.compact = true,
    super.key,
  });
  final ArtworkDimensionLevels levels;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final issues = levels.issues.take(compact ? 2 : 5).toList();
    final priority = levels.issues.where((i) => !i.latestResolved).firstOrNull;
    final scores = [...levels.items]
      ..sort((a, b) => (a.level ?? 5).compareTo(b.level ?? 5));
    final dimensions = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('分项观察', style: AppText.title16),
        const SizedBox(height: 4),
        Text(
          '5 级评价 · 同一作品多位老师取均值',
          style: AppText.caption12.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        for (final item in scores)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(item.name, style: AppText.body13),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ((item.level ?? 0) / 5).clamp(0, 1),
                      minHeight: 6,
                      color: artSubjectColor(levels.subject),
                      backgroundColor: AppColors.surfaceSubtle,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 28,
                  child: Text(
                    item.level?.toStringAsFixed(1) ?? '—',
                    style: AppText.body14,
                  ),
                ),
              ],
            ),
          ),
        if (levels.history.length >= 2)
          Text(
            _change(scores.first.key, scores.first.name),
            style: AppText.caption12.copyWith(color: AppColors.textSecondary),
          ),
      ],
    );
    final feedback = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('近期关注', style: AppText.title16),
            const Spacer(),
            Text(
              '按反复出现的作品数排序',
              style: AppText.caption12.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (issues.isEmpty) const Text('暂未标记具体问题，可先查看老师的分项点评。'),
        for (final issue in issues)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(issue.name, style: AppText.body14)),
                    AppTag(
                      label: issue.latestResolved ? '最近已确认改善' : '继续练习',
                      tone: issue.latestResolved
                          ? AppTone.success
                          : AppTone.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  issue.explanation.isEmpty ? issue.advice : issue.explanation,
                  style: AppText.body13.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${issue.count} 份作品 · ${issue.evidence.length} 条点评',
                        style: AppText.caption12.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    AppButton(
                      label: '查看依据',
                      variant: AppButtonVariant.text,
                      size: AppButtonSize.sm,
                      onTap: () => _evidence(context, issue),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '最近 ${levels.sampleCount} 份已点评作品 · ${levels.reviewCount} 条任课点评 · ${_day(levels.fromDate)}—${_day(levels.toDate)}',
          style: AppText.caption12.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (_, constraints) => constraints.maxWidth < 620
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [dimensions, const Divider(height: 24), feedback],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: dimensions),
                    const SizedBox(width: 28),
                    Expanded(flex: 6, child: feedback),
                  ],
                ),
        ),
        if (priority != null) ...[
          const Divider(height: 24),
          LayoutBuilder(
            builder: (_, constraints) {
              final plan = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('下一次练习 · ${priority.name}', style: AppText.title16),
                  const SizedBox(height: 6),
                  Text(
                    priority.advice,
                    style: AppText.body13.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppButton(
                    label: '找学习资料',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    onTap: () => Navigator.of(context).pushNamed(
                      RoutePaths.microLessons,
                      arguments: {
                        'subject': levels.subject,
                        'keyword': priority.keyword,
                      },
                    ),
                  ),
                  AppButton(
                    label: '制定练习',
                    size: AppButtonSize.sm,
                    onTap: () => showArtworkPractice(
                      context,
                      subject: levels.subject,
                      title: priority.name,
                      instruction: priority.advice,
                      sourceLabel: '短板练习 · ${priority.name}',
                    ),
                  ),
                ],
              );
              return constraints.maxWidth < 840
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        plan,
                        const SizedBox(height: 12),
                        Align(alignment: Alignment.centerRight, child: actions),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: plan),
                        const SizedBox(width: 20),
                        actions,
                      ],
                    );
            },
          ),
        ],
      ],
    );
  }

  String _change(String key, String name) {
    final valid = levels.history
        .map((h) => h.levels[key])
        .whereType<double>()
        .toList();
    if (valid.length < 2) return '再积累一份点评后可比较变化';
    final delta = valid.last - valid[valid.length - 2];
    return '$name较上份 ${delta == 0 ? '持平' : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} 级'} · 仅比较相邻两份作品';
  }

  String _day(String text) => text.length >= 10 ? text.substring(5, 10) : '—';

  Future<void> _evidence(BuildContext context, ArtworkInsightTag issue) async {
    final id = await showAppDrawer<String>(
      context: context,
      builder: (drawer) => AppDrawer(
        title: issue.name,
        subtitle: '${levels.subject} · ${issue.count} 份作品的点评依据',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '状态取自最新相关点评；历史改善记录不会覆盖之后再次出现的问题。',
              style: AppText.body13.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            for (final e in issue.evidence)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(e.title, style: AppText.title16),
                      const SizedBox(height: 6),
                      Text(
                        '${e.teacher} · ${e.time}',
                        style: AppText.caption12.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        e.comment.isEmpty ? '老师标记了此问题，请结合原作品查看。' : e.comment,
                        style: AppText.body14,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          AppTag(
                            label: e.resolved ? '本次确认改善' : '本次仍需关注',
                            tone: e.resolved
                                ? AppTone.success
                                : AppTone.warning,
                          ),
                          const Spacer(),
                          AppButton(
                            label: '查看原作品',
                            size: AppButtonSize.sm,
                            variant: AppButtonVariant.text,
                            onTap: () => Navigator.of(drawer).pop(e.artworkId),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (id != null && context.mounted) {
      Navigator.of(
        context,
      ).pushNamed(RoutePaths.artworks, arguments: {'artworkId': id});
    }
  }
}

Future<void> showArtworkPractice(
  BuildContext context, {
  required String subject,
  required String title,
  required String instruction,
  required String sourceLabel,
  String sourceId = '',
}) async {
  final begin = await showAppDrawer<bool>(
    context: context,
    builder: (drawer) => AppDrawer(
      title: '练习安排',
      subtitle: '$subject · $title',
      actions: [
        AppButton(label: '提交练习作品', onTap: () => Navigator.of(drawer).pop(true)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('本次目标', style: AppText.title16),
          const SizedBox(height: 8),
          Text(instruction, style: AppText.body14),
          const SizedBox(height: 24),
          Text('准备与步骤', style: AppText.title16),
          const SizedBox(height: 8),
          Text(
            '准备同科目的画具、纸张与一份参考作品。\n1. 用 3 分钟观察并标记需要调整的位置。\n2. 用 10–15 分钟完成局部练习。\n3. 对照参考检查，拍下完整画面与局部。',
            style: AppText.body14.copyWith(height: 1.8),
          ),
          const SizedBox(height: 24),
          Text('提交前自检', style: AppText.title16),
          const SizedBox(height: 8),
          Text(
            '画面完整清晰；说明本次改动的位置；写下仍不确定的一点。提交后由任课老师点评，再回到作品成长查看变化。',
            style: AppText.body14.copyWith(height: 1.7),
          ),
        ],
      ),
    ),
  );
  if (begin == true && context.mounted) {
    final created = await showArtworkUploadDialog(
      context,
      subject: subject,
      title: '$title练习',
      description: '$sourceLabel\n练习目标：$instruction\n本次改动：\n希望老师关注：',
      practiceSource: {
        'kind': sourceId.isEmpty ? 'weakness' : 'microLesson',
        'id': sourceId,
        'label': sourceLabel,
      },
    );
    if (created == true && context.mounted) {
      AppToast.showSuccess(context, '已提交练习，可在作品档案查看老师点评');
    }
  }
}
