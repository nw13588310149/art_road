import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../data/gallery_models.dart';
import 'gallery_widgets.dart';

/// 范画详情的右栏：出处，照着练的点评要点和说明，标签，然后是相关作品。
class GalleryDetailPanel extends StatelessWidget {
  const GalleryDetailPanel({
    required this.detail,
    required this.onOpenWork,
    required this.onTagSelected,
    super.key,
  });

  final GalleryWorkDetail detail;
  final ValueChanged<String> onOpenWork;
  final ValueChanged<String> onTagSelected;

  @override
  Widget build(BuildContext context) {
    final work = detail.work;
    final facts = [
      work.categoryLabel,
      if (work.publishDate.isNotEmpty) '发布于\u00A0${work.publishDate}',
      '${formatViewCount(work.views).replaceAll(' ', '\u00A0')}\u00A0次浏览',
    ].where((part) => part.isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Provenance(work: work),
        if (work.points.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s24),
          const AppSectionTitle(title: '点评要点'),
          const SizedBox(height: AppSpace.s8),
          for (var i = 0; i < work.points.length; i++)
            _PointRow(index: i + 1, text: work.points[i]),
        ],
        if (detail.description.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s16),
          const AppSectionTitle(title: '作品说明'),
          const SizedBox(height: AppSpace.s8),
          _Description(text: detail.description),
        ],
        if (work.tags.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s24),
          const AppSectionTitle(title: '标签', note: '点按查看同类范画'),
          Wrap(
            spacing: AppSpace.s8,
            children: [
              for (final tag in work.tags)
                _TagLink(tag: tag, onTap: () => onTagSelected(tag)),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.s12),
        Text(facts, style: AppText.caption12),
        if (detail.related.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s24),
          const AppRule(),
          const SizedBox(height: AppSpace.s24),
          const AppSectionTitle(title: '相关作品'),
          const SizedBox(height: AppSpace.s4),
          for (final (index, related) in detail.related.indexed) ...[
            if (index > 0) const AppRule(),
            _RelatedRow(work: related, onTap: () => onOpenWork(related.id)),
          ],
        ],
      ],
    );
  }
}

/// 出处：高分卷先写分数和档位，再写作者、校区和考试；其余作品写
/// 「来源 · 作者 · 单位」。
class _Provenance extends StatelessWidget {
  const _Provenance({required this.work});

  final GalleryWork work;

  @override
  Widget build(BuildContext context) {
    final author = work.author.isEmpty ? '佚名' : work.author;
    if (work.isExamPaper && work.score != null) {
      final byline = [
        author,
        work.authorTitle,
        work.examName,
      ].where((part) => part.isNotEmpty).join(' · ');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatScore(work.score),
                style: AppText.displayNumber(size: 32),
              ),
              const SizedBox(width: AppSpace.s4),
              Text('分', style: AppText.body13),
              if (work.grade.isNotEmpty) ...[
                const SizedBox(width: AppSpace.s12),
                Text('${work.grade} 档', style: AppText.body14Strong),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Text(byline, style: AppText.body13),
        ],
      );
    }
    final byline = [
      gallerySourceLabel(work.source),
      author,
      work.authorTitle,
    ].where((part) => part.isNotEmpty).join(' · ');
    return Text(byline, style: AppText.body13);
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$index',
                style: AppText.number(size: 14, color: AppColors.textTertiary),
              ),
            ),
          ),
          Expanded(child: Text(text, style: AppText.body14)),
        ],
      ),
    );
  }
}

/// 作品说明：按段落排开；「临摹建议：」开头的那一段把这几个字加粗，方便找到。
class _Description extends StatelessWidget {
  const _Description({required this.text});

  final String text;

  static final _lead = RegExp(r'^(临摹建议[:：])');

  @override
  Widget build(BuildContext context) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n|\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, paragraph) in paragraphs.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpace.s12),
          _paragraph(paragraph),
        ],
      ],
    );
  }

  Widget _paragraph(String paragraph) {
    final lead = _lead.firstMatch(paragraph)?.group(1);
    if (lead == null) {
      return Text(paragraph, style: AppText.body14);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: lead, style: AppText.body14Strong),
          TextSpan(text: paragraph.substring(lead.length)),
        ],
      ),
      style: AppText.body14,
    );
  }
}

/// 标签：点按后按这个词搜索同类范画。看上去高 32，能点的范围高 44。
class _TagLink extends StatelessWidget {
  const _TagLink({required this.tag, required this.onTap});

  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticLabel: '搜索「$tag」',
      child: SizedBox(
        height: 44,
        child: Center(
          widthFactor: 1,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
            decoration: BoxDecoration(
              borderRadius: AppRadius.brPill,
              border: Border.all(color: AppColors.line),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                tag,
                style: AppText.body13.copyWith(color: AppColors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 相关作品的一行：完整显示的小图、名称两行、说明一行、箭头。
class _RelatedRow extends StatelessWidget {
  const _RelatedRow({required this.work, required this.onTap});

  final GalleryWork work;
  final VoidCallback onTap;

  static const double _thumb = 56;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticLabel: '${work.title}，${galleryTileMeta(work)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
        child: Row(
          children: [
            SizedBox(
              width: _thumb,
              child: AppImageTile.frame(
                aspectRatio: 1,
                child: ColoredBox(
                  color: AppColors.canvas,
                  child: AppImage(
                    src: work.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: const ColoredBox(color: AppColors.canvas),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      work.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body14Strong,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      galleryTileMeta(work),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption12,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
