import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/ebook_models.dart';
import 'ebook_widgets.dart';

/// 书库首屏的那一行：左边是接着读的一本（没有在读的书时是第一本编辑推荐），
/// 配这一屏唯一的主按钮；竖线右边是另外两本编辑推荐。
class EbookLeadStrip extends StatelessWidget {
  const EbookLeadStrip({
    required this.lead,
    required this.picks,
    required this.wide,
    required this.onOpen,
    required this.onRead,
    super.key,
  });

  final EbookSummary lead;
  final List<EbookSummary> picks;
  final bool wide;
  final ValueChanged<EbookSummary> onOpen;
  final ValueChanged<EbookSummary> onRead;

  @override
  Widget build(BuildContext context) {
    final reading = lead.reading;
    final leadPart = Row(
      children: [
        Expanded(
          child: AppPressable(
            onTap: () => onOpen(lead),
            semanticLabel: lead.title,
            child: ExcludeSemantics(
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: EbookCover(url: lead.coverUrl, small: true),
                  ),
                  const SizedBox(width: AppSpace.s16),
                  Expanded(child: _LeadText(book: lead, reading: reading)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s16),
        AppButton(label: ebookReadLabel(lead), onTap: () => onRead(lead)),
      ],
    );
    if (picks.isEmpty) {
      return leadPart;
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: wide ? 5 : 3, child: leadPart),
          const AppRule.vertical(),
          Expanded(
            flex: wide ? 4 : 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reading ? '编辑推荐' : '更多推荐',
                  style: AppText.caption12Strong,
                ),
                for (final book in picks.take(2)) ...[
                  const SizedBox(height: AppSpace.s4),
                  EbookBookRow(
                    book: book,
                    note: book.featuredIntro.isNotEmpty
                        ? book.featuredIntro
                        : book.intro,
                    onTap: () => onOpen(book),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadText extends StatelessWidget {
  const _LeadText({required this.book, required this.reading});

  final EbookSummary book;
  final bool reading;

  @override
  Widget build(BuildContext context) {
    final intro = book.featuredIntro.isNotEmpty
        ? book.featuredIntro
        : book.intro;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(reading ? '接着读' : '编辑推荐', style: AppText.caption12Strong),
        const SizedBox(height: AppSpace.s4),
        Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.title16,
        ),
        const SizedBox(height: AppSpace.s8),
        if (reading)
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 96,
                child: AppProgressBar(value: book.progressFraction, height: 4),
              ),
              Text(ebookProgressLabel(book), style: AppText.caption12),
            ],
          )
        else if (intro.isNotEmpty)
          Text(
            intro,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body13,
          ),
      ],
    );
  }
}
