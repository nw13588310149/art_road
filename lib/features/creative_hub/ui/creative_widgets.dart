import 'package:flutter/material.dart';

import '../../../core/art/art_subject.dart';
import '../../../core/ui/ui.dart';

const creativeSubjects = ['素描', '色彩', '速写', '美术常识'];

class CreativeHeading extends StatelessWidget {
  const CreativeHeading({
    required this.title,
    required this.subtitle,
    this.onBack,
    this.actions = const [],
    super.key,
  });
  final String title, subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (onBack != null) ...[
        AppIconButton.back(onTap: onBack),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.title24),
            const SizedBox(height: 4),
            Text(subtitle, style: AppText.body13),
          ],
        ),
      ),
      ...actions,
    ],
  );
}

class CreativeSubjectFilter extends StatelessWidget {
  const CreativeSubjectFilter({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      AppChip(
        label: '全部科目',
        selected: value.isEmpty,
        onTap: () => onChanged(''),
      ),
      for (final name in creativeSubjects)
        AppChip(
          label: ArtSubject.tryParse(name)?.label ?? name,
          selected: value == name,
          onTap: () => onChanged(name),
        ),
    ],
  );
}

class CreativeSubjectSelect extends StatelessWidget {
  const CreativeSubjectSelect({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => AppSelect<String>(
    value: value,
    onChanged: onChanged,
    options: [
      for (final name in creativeSubjects)
        AppSelectOption(
          value: name,
          label: ArtSubject.tryParse(name)?.label ?? name,
        ),
    ],
  );
}
