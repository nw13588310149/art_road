import 'package:flutter/material.dart';

import '../../app/router/route_paths.dart';
import '../../core/art/art_subject.dart';
import '../../core/ui/ui.dart';

/// 组件库演示页（`/design-system`）：按分区展示 lib/core/ui 的全部组件、变体与状态。
///
/// 只用组件库搭建，同时作为页面写法的参考。规范见 `docs/设计规范.md`。
class DesignSystemPage extends StatefulWidget {
  const DesignSystemPage({super.key});

  @override
  State<DesignSystemPage> createState() => _DesignSystemPageState();
}

class _DesignSystemPageState extends State<DesignSystemPage> {
  String _view = 'all';
  String _range = 'week';
  String _tab = 'pending';
  final Set<String> _subjects = <String>{'素描'};
  bool _notify = true;
  bool _compact = false;
  bool _rememberMe = true;
  bool _agree = false;
  String? _subject = '色彩';
  String? _className;
  bool _cardSelected = true;
  final _nameController = TextEditingController(text: '联考冲刺');
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: '组件库',
          subtitle: '美术之路统一组件与设计规范 · 演示页面',
          onBack: _back,
          actions: [
            AppButton(
              label: '设计规范',
              icon: Icons.menu_book_outlined,
              variant: AppButtonVariant.quiet,
              size: AppButtonSize.sm,
              onTap: () => AppToast.showInfo(context, '设计规范见项目文档 docs/设计规范.md'),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              0,
              AppSpace.page,
              AppSpace.s32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section('颜色', '品牌紫只用于主操作、选中态、关键数字和链接', _colors()),
                _section(
                  '字体',
                  '字阶 12 / 13 / 14 / 16 / 20 / 24 / 32，数字用 Manrope',
                  _typography(),
                ),
                _section(
                  '间距、圆角与尺寸',
                  '间距 4 的倍数；按钮 44 / 34，控件 34 / 30',
                  _metrics(),
                ),
                _section('按钮', 'AppButton · AppIconButton', _buttons()),
                _section(
                  '分段与页签',
                  'AppSegmented · AppTabs，切换立即生效',
                  _switchers(),
                ),
                _section(
                  '筛选与标签',
                  'AppChip · AppTag · AppStatusTag · AppBadge',
                  _tags(),
                ),
                _section(
                  '表单',
                  'AppSearchField · AppInputField · AppSelect · AppSwitch · AppCheckbox',
                  _forms(),
                ),
                _section(
                  '卡片与列表',
                  'AppCard · AppListRow · AppSectionHeader · AppPageHeader',
                  _cards(),
                ),
                _section(
                  '数据展示',
                  'AppStatTile · AppProgressBar · AppSteps · AppAvatar · AppImage',
                  _data(),
                ),
                _section('课程卡', 'AppCourseCard：300 宽时两个标签也完整显示', _courses()),
                _section(
                  '浮层反馈',
                  'AppToast · AppDialog · AppDrawer，只有浮层有 200ms 内的进场',
                  _overlays(),
                ),
                _section(
                  '加载、空与错误',
                  'AppSkeleton · AppEmptyState · AppErrorState · AppLoadingIndicator',
                  _states(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String title, String subtitle, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      child: AppCard(
        title: title,
        subtitle: subtitle,
        padding: const EdgeInsets.all(AppSpace.s20),
        child: child,
      ),
    );
  }

  Widget _group(
    String label,
    List<Widget> children, {
    double spacing = 12,
    WrapCrossAlignment align = WrapCrossAlignment.center,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption12),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: spacing,
            runSpacing: spacing,
            crossAxisAlignment: align,
            children: children,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 令牌

  Widget _colors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _group('品牌', const [
          _Swatch('brand', AppColors.brand),
          _Swatch('brandDeep', AppColors.brandDeep),
          _Swatch('brandSoft', AppColors.brandSoft),
          _Swatch('brandTint', AppColors.brandTint),
          _Swatch('brandWash', AppColors.brandWash),
        ]),
        _group('文字', const [
          _Swatch('ink', AppColors.ink),
          _Swatch('textSecondary', AppColors.textSecondary),
          _Swatch('textTertiary', AppColors.textTertiary),
          _Swatch('textPlaceholder', AppColors.textPlaceholder),
        ]),
        _group('表面与线', const [
          _Swatch('page', AppColors.page),
          _Swatch('surface', AppColors.surface),
          _Swatch('surfaceSubtle', AppColors.surfaceSubtle),
          _Swatch('line', AppColors.line),
          _Swatch('lineSoft', AppColors.lineSoft),
        ]),
        _group('语义（深字 / 浅底）', const [
          _Swatch('success', AppColors.success),
          _Swatch('successSoft', AppColors.successSoft),
          _Swatch('warning', AppColors.warning),
          _Swatch('warningSoft', AppColors.warningSoft),
          _Swatch('danger', AppColors.danger),
          _Swatch('dangerSoft', AppColors.dangerSoft),
          _Swatch('info', AppColors.info),
          _Swatch('infoSoft', AppColors.infoSoft),
        ]),
        _group('科目色（ArtSubject）', [
          for (final subject in ArtSubject.values)
            _Swatch(subject.label, subject.accent),
        ]),
      ],
    );
  }

  Widget _typography() {
    final rows = <(String, TextStyle, String)>[
      ('display32 · 32 / 40 · 600', AppText.display32, '美术之路 2026 届'),
      ('title24 · 24 / 32 · 600', AppText.title24, '我的学情'),
      ('title20 · 20 / 28 · 600', AppText.title20, '作品档案'),
      ('title16 · 16 / 24 · 600', AppText.title16, '本周课程'),
      ('body16 · 16 / 24 · 400', AppText.body16, '记录每一张画，收好老师的每一次点评'),
      ('body14 · 14 / 22 · 400', AppText.body14, '色彩冷暖关系要统一，暗部注意环境色'),
      ('body14Strong · 14 / 22 · 500', AppText.body14Strong, '王老师 · 素描头像'),
      ('body13 · 13 / 20 · 400', AppText.body13, '180 分钟 · 联考冲刺 1 班 · 301 教室'),
      ('caption12 · 12 / 18 · 400', AppText.caption12, '3 分钟前更新'),
      ('caption12Strong · 12 / 18 · 500', AppText.caption12Strong, '待点评'),
      (
        'number(size: 24) · Manrope',
        AppText.number(size: 24),
        '87.5  128 / 150',
      ),
      (
        'displayNumber(size: 32) · Barlow',
        AppText.displayNumber(),
        '08:30 – 11:30',
      ),
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: Text(row.$1, style: AppText.caption12),
                ),
                Expanded(
                  child: Text(
                    row.$3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: row.$2,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _metrics() {
    const spaces = <double>[4, 8, 12, 16, 20, 24, 32];
    const radii = <(String, double)>[
      ('4 复选框', AppRadius.checkbox),
      ('8 按钮 / 控件', AppRadius.control),
      ('12 卡片 / 弹窗', AppRadius.card),
      ('16 大面板', AppRadius.panel),
      ('999 标签', AppRadius.pill),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _group('间距 AppSpace', [
          for (final space in spaces)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: space, height: 24, color: AppColors.brandTint),
                const SizedBox(height: AppSpace.s4),
                Text(
                  space.toStringAsFixed(0),
                  style: AppText.number(
                    size: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
        ], spacing: AppSpace.s20),
        _group('圆角 AppRadius', [
          for (final radius in radii)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandWash,
                    borderRadius: BorderRadius.circular(radius.$2),
                    border: Border.all(color: AppColors.brandTint),
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(radius.$1, style: AppText.caption12),
              ],
            ),
        ]),
        _group('尺寸 AppSize', [
          for (final size in const <(String, double)>[
            ('按钮 md', AppSize.buttonMd),
            ('按钮 sm', AppSize.buttonSm),
            ('控件 md', AppSize.control),
            ('控件 sm', AppSize.controlSm),
            ('标签', AppSize.tag),
          ])
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: size.$2,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: AppRadius.br8,
                  ),
                  child: Text(
                    size.$2.toStringAsFixed(0),
                    style: AppText.number(size: 12),
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(size.$1, style: AppText.caption12),
              ],
            ),
        ]),
      ],
    );
  }

  // ---------------------------------------------------------------- 组件

  Widget _buttons() {
    void tap() => AppToast.showInfo(context, '点击了按钮');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final size in AppButtonSize.values)
          _group(size == AppButtonSize.md ? '尺寸 md · 44 高' : '尺寸 sm · 34 高', [
            AppButton(label: '开始点评', onTap: tap, size: size),
            AppButton(
              label: '取消',
              onTap: tap,
              size: size,
              variant: AppButtonVariant.secondary,
            ),
            AppButton(
              label: '筛选',
              onTap: tap,
              size: size,
              variant: AppButtonVariant.quiet,
            ),
            AppButton(
              label: '删除作品',
              onTap: tap,
              size: size,
              variant: AppButtonVariant.danger,
            ),
            AppButton(
              label: '查看全部',
              onTap: tap,
              size: size,
              variant: AppButtonVariant.text,
            ),
          ]),
        _group('图标 / 加载 / 禁用', [
          AppButton(
            label: '上传作品',
            icon: Icons.add_photo_alternate_outlined,
            onTap: tap,
          ),
          AppButton(
            label: '成长曲线',
            icon: Icons.show_chart_rounded,
            variant: AppButtonVariant.quiet,
            size: AppButtonSize.sm,
            onTap: tap,
          ),
          AppButton(label: '提交中', loading: true, onTap: tap),
          const AppButton(label: '提交', onTap: null),
          AppButton(
            label: '已收藏',
            variant: AppButtonVariant.secondary,
            enabled: false,
            onTap: tap,
          ),
        ]),
        _group('撑满宽度 expand', [
          SizedBox(
            width: 360,
            child: AppButton(label: '保存', expand: true, onTap: tap),
          ),
        ]),
        _group('图标按钮 AppIconButton', [
          AppIconButton(
            icon: Icons.notifications_none_rounded,
            semanticLabel: '消息',
            onTap: tap,
          ),
          AppIconButton(
            icon: Icons.notifications_none_rounded,
            semanticLabel: '消息',
            badgeCount: 3,
            onTap: tap,
          ),
          AppIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            semanticLabel: '私信',
            badgeCount: 120,
            onTap: tap,
          ),
          AppIconButton(
            icon: Icons.fullscreen_rounded,
            semanticLabel: '全屏查看',
            size: AppButtonSize.sm,
            onTap: tap,
          ),
          AppIconButton(
            icon: Icons.close_rounded,
            semanticLabel: '关闭',
            size: AppButtonSize.sm,
            filled: false,
            color: AppColors.textSecondary,
            onTap: tap,
          ),
          const AppIconButton(
            icon: Icons.delete_outline_rounded,
            semanticLabel: '删除',
            onTap: null,
          ),
        ]),
      ],
    );
  }

  Widget _switchers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _group('分段控件 md', [
          AppSegmented<String>(
            segments: const [
              AppSegment(value: 'all', label: '全部'),
              AppSegment(value: 'pending', label: '待点评', badge: '3'),
              AppSegment(value: 'done', label: '已点评'),
            ],
            value: _view,
            onChanged: (value) => setState(() => _view = value),
          ),
        ]),
        _group('分段控件 sm · 含禁用选项', [
          AppSegmented<String>(
            size: AppControlSize.sm,
            segments: const [
              AppSegment(value: 'week', label: '本周'),
              AppSegment(value: 'month', label: '本月'),
              AppSegment(value: 'year', label: '全年', enabled: false),
            ],
            value: _range,
            onChanged: (value) => setState(() => _range = value),
          ),
          AppSegmented<String>(
            size: AppControlSize.sm,
            enabled: false,
            segments: const [
              AppSegment(value: 'week', label: '查看'),
              AppSegment(value: 'month', label: '编辑'),
            ],
            value: 'week',
            onChanged: (_) {},
          ),
        ]),
        _group('等分宽度 expand', [
          SizedBox(
            width: 360,
            child: AppSegmented<String>(
              expand: true,
              segments: const [
                AppSegment(value: 'all', label: '全部'),
                AppSegment(value: 'pending', label: '待点评'),
                AppSegment(value: 'done', label: '已点评'),
              ],
              value: _view,
              onChanged: (value) => setState(() => _view = value),
            ),
          ),
        ]),
        _group('页签 AppTabs', [
          AppTabs<String>(
            tabs: const [
              AppTab(value: 'pending', label: '待点评', count: 12),
              AppTab(value: 'done', label: '已点评', count: 86),
              AppTab(value: 'mine', label: '我上传的'),
            ],
            value: _tab,
            onChanged: (value) => setState(() => _tab = value),
          ),
        ]),
      ],
    );
  }

  Widget _tags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _group('筛选胶囊 AppChip（可多选）', [
          for (final subject in const ['素描', '色彩', '速写', '高分卷'])
            AppChip(
              label: subject,
              selected: _subjects.contains(subject),
              onTap: () => setState(() {
                if (!_subjects.remove(subject)) {
                  _subjects.add(subject);
                }
              }),
            ),
          AppChip(
            label: '只看收藏',
            icon: Icons.favorite_border_rounded,
            selected: false,
            onTap: () {},
          ),
          const AppChip(
            label: '已归档',
            selected: false,
            enabled: false,
            onTap: null,
          ),
        ], spacing: AppSpace.s8),
        _group('标签 AppTag · 语义色调', const [
          AppTag(label: '草稿'),
          AppTag(label: '推荐', tone: AppTone.brand),
          AppTag(label: '已出分', tone: AppTone.success),
          AppTag(label: '阅卷中', tone: AppTone.warning),
          AppTag(label: '已驳回', tone: AppTone.danger),
          AppTag(label: '模拟数据', tone: AppTone.info),
          AppTag(label: '高分卷', tone: AppTone.brand, icon: Icons.star_rounded),
        ], spacing: AppSpace.s8),
        _group('标签 AppTag · 科目色与圆点', [
          AppTag.subject('素描'),
          AppTag.subject('色彩'),
          AppTag.subject('速写'),
          AppTag.subject('美术常识'),
          AppTag.subject('素描', muted: true),
          const AppTag(label: '大课', dotColor: AppColors.brandSoft),
          const AppTag(label: '小课', dotColor: AppColors.success),
          const AppTag(label: '色彩写生（风景）· 联考冲刺 1 班', tone: AppTone.brand),
        ], spacing: AppSpace.s8),
        _group('状态 AppStatusTag', const [
          AppStatusTag(label: '进行中', tone: AppTone.brand),
          AppStatusTag(label: '已完成', tone: AppTone.success),
          AppStatusTag(label: '待开始', tone: AppTone.warning),
          AppStatusTag(label: '缺勤', tone: AppTone.danger),
          AppStatusTag(label: '已结束'),
        ], spacing: AppSpace.s16),
        _group('角标 AppBadge', const [
          AppBadge(count: 3),
          AppBadge(count: 28),
          AppBadge(count: 120),
          AppBadge(label: '新'),
          AppBadge.dot(),
        ]),
      ],
    );
  }

  Widget _forms() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _group('搜索框 AppSearchField', [
          SizedBox(
            width: 280,
            child: AppSearchField(
              hint: '搜索作品、学生',
              onSubmitted: (value) => AppToast.showInfo(context, '搜索：$value'),
            ),
          ),
          const SizedBox(
            width: 220,
            child: AppSearchField(hint: '小号搜索', size: AppControlSize.sm),
          ),
          const SizedBox(
            width: 220,
            child: AppSearchField(hint: '禁用', enabled: false),
          ),
        ]),
        _group(
          '输入框 AppInputField',
          [
            SizedBox(
              width: 280,
              child: AppInputField(
                label: '班级名称',
                required: true,
                controller: _nameController,
                hint: '例如：联考冲刺 1 班',
                maxLength: 20,
              ),
            ),
            const SizedBox(
              width: 280,
              child: AppInputField(
                label: '准考证号',
                hint: '请输入 10 位准考证号',
                errorText: '准考证号应为 10 位数字',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(
              width: 280,
              child: AppInputField(label: '所属画室', hint: '示范画室', readOnly: true),
            ),
            const SizedBox(
              width: 280,
              child: AppInputField(label: '禁用', hint: '暂不可编辑', enabled: false),
            ),
            SizedBox(
              width: 576,
              child: AppInputField(
                label: '点评意见',
                hint: '写下这张画的优点和需要改进的地方',
                controller: _noteController,
                multiline: true,
                maxLength: 200,
              ),
            ),
          ],
          spacing: AppSpace.s16,
          align: WrapCrossAlignment.start,
        ),
        _group('下拉选择 AppSelect', [
          SizedBox(
            width: 200,
            child: AppSelect<String>(
              options: const [
                AppSelectOption(value: '素描', label: '素描'),
                AppSelectOption(value: '色彩', label: '色彩'),
                AppSelectOption(value: '速写', label: '速写'),
                AppSelectOption(value: '美术常识', label: '美术常识', enabled: false),
              ],
              value: _subject,
              onChanged: (value) => setState(() => _subject = value),
            ),
          ),
          SizedBox(
            width: 200,
            child: AppSelect<String>(
              size: AppControlSize.sm,
              hint: '选择班级',
              options: const [
                AppSelectOption(value: 'a', label: '联考冲刺 1 班'),
                AppSelectOption(value: 'b', label: '联考冲刺 2 班'),
                AppSelectOption(value: 'c', label: '校考提高班'),
              ],
              value: _className,
              onChanged: (value) => setState(() => _className = value),
            ),
          ),
          SizedBox(
            width: 200,
            child: AppSelect<String>(
              enabled: false,
              options: const [AppSelectOption(value: 'x', label: '禁用')],
              value: 'x',
              onChanged: (_) {},
            ),
          ),
        ]),
        _group('开关 AppSwitch', [
          AppSwitch(
            value: _notify,
            semanticLabel: '出分提醒',
            onChanged: (value) => setState(() => _notify = value),
          ),
          AppSwitch(
            value: _compact,
            size: AppControlSize.sm,
            semanticLabel: '紧凑模式',
            onChanged: (value) => setState(() => _compact = value),
          ),
          const AppSwitch(value: true, onChanged: null),
          const AppSwitch(value: false, onChanged: null),
        ], spacing: AppSpace.s16),
        _group('复选框 AppCheckbox', [
          AppCheckbox(
            value: _rememberMe,
            label: '记住账号',
            onChanged: (value) => setState(() => _rememberMe = value),
          ),
          AppCheckbox(
            value: _agree,
            label: '已阅读并同意服务协议',
            onChanged: (value) => setState(() => _agree = value),
          ),
          const AppCheckbox(value: true, label: '禁用（已选）', onChanged: null),
          const AppCheckbox(value: false, label: '禁用（未选）', onChanged: null),
        ], spacing: AppSpace.s20),
      ],
    );
  }

  Widget _cards() {
    void open() => AppToast.showInfo(context, '进入详情');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _group('卡片 AppCard', [
          SizedBox(
            width: 280,
            child: AppCard(
              child: Text(
                '白底 + 1px 浅描边 + 圆角 12，静止时没有阴影。',
                style: AppText.body13,
              ),
            ),
          ),
          SizedBox(
            width: 280,
            child: AppCard(
              title: '本周作品',
              subtitle: '共 6 件',
              trailing: AppButton(
                label: '更多',
                variant: AppButtonVariant.text,
                size: AppButtonSize.sm,
                onTap: open,
              ),
              child: Text('标题行右侧放「更多」或筛选。', style: AppText.body13),
            ),
          ),
          SizedBox(
            width: 280,
            child: AppCard(
              onTap: open,
              color: AppColors.surfaceSubtle,
              bordered: false,
              child: Text('浅灰子卡片，可点击（无按压效果）。', style: AppText.body13),
            ),
          ),
        ], align: WrapCrossAlignment.start),
        _group('列表行 AppListRow', [
          SizedBox(
            width: 576,
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppListRow(
                    leading: const AppAvatar(name: '林晓雨', size: 36),
                    title: '林晓雨',
                    subtitle: '联考冲刺 1 班 · 准考证号 2026010203',
                    trailing: const AppTag(label: '待点评', tone: AppTone.warning),
                    chevron: true,
                    divider: true,
                    onTap: open,
                  ),
                  AppListRow(
                    leading: const Icon(
                      Icons.insights_outlined,
                      color: AppColors.brand,
                    ),
                    title: '成绩报告',
                    subtitle: '2026 届联考模拟（三）',
                    trailing: Text('87.5', style: AppText.number(size: 16)),
                    chevron: true,
                    divider: true,
                    onTap: open,
                  ),
                  const AppListRow(
                    leading: Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textTertiary,
                    ),
                    title: '原卷查看',
                    subtitle: '出分后开放',
                    enabled: false,
                  ),
                ],
              ),
            ),
          ),
        ]),
        _group('区块标题 AppSectionHeader', [
          SizedBox(
            width: 576,
            child: AppSectionHeader(title: '最新资讯', onMore: open),
          ),
          SizedBox(
            width: 576,
            child: AppSectionHeader(
              title: '本周课程',
              subtitle: '共 12 节',
              onMore: open,
            ),
          ),
        ]),
        _group('页头 AppPageHeader', [
          SizedBox(
            width: 576,
            child: AppCard(
              padding: EdgeInsets.zero,
              child: AppPageHeader(
                title: '作品点评',
                subtitle: '多位老师独立点评，保存后可查看其他老师的意见',
                onBack: () {},
                actions: [
                  AppButton(
                    label: '点评标签',
                    variant: AppButtonVariant.quiet,
                    size: AppButtonSize.sm,
                    onTap: open,
                  ),
                  AppButton(label: '开始点评', size: AppButtonSize.sm, onTap: open),
                ],
                bottom: AppTabs<String>(
                  tabs: const [
                    AppTab(value: 'pending', label: '待点评', count: 12),
                    AppTab(value: 'done', label: '已点评'),
                  ],
                  value: _tab,
                  onChanged: (value) => setState(() => _tab = value),
                ),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _data() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _group('指标 AppStatTile', const [
          SizedBox(
            width: 160,
            child: AppStatTile(
              label: '本次总分',
              value: '256',
              unit: '分',
              delta: 12,
            ),
          ),
          SizedBox(
            width: 160,
            child: AppStatTile(
              label: '班级名次',
              value: '7',
              unit: '名',
              delta: 3,
              invertDelta: true,
            ),
          ),
          SizedBox(
            width: 160,
            child: AppStatTile(
              label: '平均分',
              value: '81.5',
              delta: -2.5,
              boxed: true,
            ),
          ),
          SizedBox(
            width: 160,
            child: AppStatTile(
              label: '待点评',
              value: '12',
              unit: '件',
              valueColor: AppColors.brand,
              boxed: true,
            ),
          ),
        ], spacing: AppSpace.s16),
        _group('进度条 AppProgressBar（静态）', const [
          SizedBox(width: 240, child: AppProgressBar(value: 0.62)),
          SizedBox(
            width: 240,
            child: AppProgressBar(value: 0.78, height: 12, striped: true),
          ),
          SizedBox(
            width: 240,
            child: AppProgressBar(
              value: 1,
              height: 12,
              striped: true,
              color: AppColors.success,
            ),
          ),
          SizedBox(width: 240, child: AppProgressBar(value: 0)),
        ], spacing: AppSpace.s20),
        _group('步骤条 AppSteps', const [
          SizedBox(
            width: 520,
            child: AppSteps(labels: ['选择人员', '采集人脸', '确认提交'], current: 1),
          ),
          SizedBox(
            width: 520,
            child: AppSteps(labels: ['选择人员', '采集人脸', '确认提交'], current: 3),
          ),
        ], spacing: AppSpace.s16),
        _group('头像 AppAvatar', const [
          AppAvatar(
            name: '林晓雨',
            url: 'asset:assets/demo/avatars/student_female.png',
            size: 48,
          ),
          AppAvatar(name: '王建国', size: 48),
          AppAvatar(name: '陈老师', size: 40),
          AppAvatar(name: '赵', size: 32),
          AppAvatar(name: 'Lucy', size: 32),
          AppAvatar(name: '', size: 24),
        ]),
        _group('图片 AppImage', [
          const AppImage(
            src: 'asset:assets/demo/art/sketch-bust-1.jpg',
            width: 120,
            height: 90,
            borderRadius: AppRadius.br8,
          ),
          const AppImage(
            src: 'assets/demo/art/color-still-2.jpg',
            width: 120,
            height: 90,
            borderRadius: AppRadius.br8,
          ),
          const AppImage(
            src: '',
            width: 120,
            height: 90,
            borderRadius: AppRadius.br8,
          ),
          const AppImage(
            src: 'asset:assets/demo/art/missing.jpg',
            width: 120,
            height: 90,
            borderRadius: AppRadius.br8,
          ),
        ]),
      ],
    );
  }

  Widget _courses() {
    void open() => AppToast.showInfo(context, '打开课表');
    return Wrap(
      spacing: AppSpace.s16,
      runSpacing: AppSpace.s16,
      children: [
        SizedBox(
          width: 300,
          child: AppCourseCard(
            startTime: '08:30',
            endTime: '11:30',
            subject: '模拟考试',
            teacherName: '王建国',
            subtitle: '180 分钟 · 联考冲刺 1 班 · 301 教室',
            status: AppCourseStatus.inProgress,
            onTap: open,
          ),
        ),
        SizedBox(
          width: 300,
          child: AppCourseCard(
            startTime: '14:00',
            endTime: '17:30',
            subject: '色彩静物',
            teacherName: '陈思远',
            subtitle: '210 分钟 · 联考冲刺 1 班 · 色彩教室 B',
            classKindDotColor: const Color(0xFFF99C5D),
            onTap: open,
          ),
        ),
        SizedBox(
          width: 300,
          child: AppCourseCard(
            startTime: '19:00',
            endTime: '21:00',
            subject: '速写人物动态',
            teacherName: '李明',
            subtitle: '120 分钟 · 校考提高班 · 速写教室',
            isSmallCourse: true,
            status: AppCourseStatus.ended,
            onTap: open,
          ),
        ),
        SizedBox(
          width: 300,
          child: AppCourseCard(
            startTime: '21:10',
            endTime: '22:00',
            subject: '素描头像精讲（一对一）',
            teacherName: '周敏',
            subtitle: '50 分钟 · 小课教室 3',
            isSmallCourse: true,
            status: AppCourseStatus.upcoming,
            selected: _cardSelected,
            onTap: () => setState(() => _cardSelected = !_cardSelected),
          ),
        ),
        const SizedBox(
          width: 300,
          child: AppCourseCard(
            startTime: '08:00',
            endTime: '11:30',
            subject: '美术常识',
            teacherName: '王建国',
            subtitle: '210 分钟 · 301 教室',
            status: AppCourseStatus.ended,
            statusTag: AppTag(label: '缺勤', tone: AppTone.danger),
          ),
        ),
      ],
    );
  }

  Widget _overlays() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _group('轻提示 AppToast', [
          AppButton(
            label: '成功',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: () => AppToast.showSuccess(context, '点评已保存'),
          ),
          AppButton(
            label: '失败',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: () => AppToast.showError(context, '上传失败，请检查网络后重试'),
          ),
          AppButton(
            label: '信息',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: () => AppToast.showInfo(context, '演示数据，不会上传'),
          ),
        ]),
        _group('弹窗 AppDialog', [
          AppButton(
            label: '二次确认',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: () async {
              final ok = await showAppConfirm(
                context: context,
                title: '提交点评',
                message: '提交后学生会收到通知，其他老师可以查看你的点评。',
                confirmLabel: '提交',
              );
              if (mounted) {
                AppToast.showInfo(context, ok ? '已提交' : '已取消');
              }
            },
          ),
          AppButton(
            label: '危险确认',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: () => showAppConfirm(
              context: context,
              title: '删除这件作品',
              message: '删除后老师的点评也会一并移除，且无法恢复。',
              confirmLabel: '删除',
              danger: true,
            ),
          ),
          AppButton(
            label: '表单弹窗',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: _openFormDialog,
          ),
          AppButton(
            label: '纯展示弹窗',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: () => showAppDialog<void>(
              context: context,
              builder: (dialogContext) => const AppDialog(
                title: '档位说明',
                message:
                    'A 档 90 分以上，B 档 80–89 分，C 档 70–79 分，D 档 60–69 分，E 档 60 分以下。',
              ),
            ),
          ),
        ]),
        _group('抽屉 AppDrawer', [
          AppButton(
            label: '打开抽屉（420）',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: () => _openDrawer(AppSize.drawer),
          ),
          AppButton(
            label: '打开抽屉（560）',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: () => _openDrawer(AppSize.drawerWide),
          ),
        ]),
      ],
    );
  }

  Future<void> _openFormDialog() {
    return showAppDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: '新建倒计时',
        message: '到期前首页会提醒你。',
        actions: [
          AppButton(
            label: '取消',
            variant: AppButtonVariant.secondary,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton(
            label: '保存',
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ],
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInputField(label: '考试名称', required: true, hint: '例如：2027 届美术联考'),
            SizedBox(height: AppSpace.s16),
            AppInputField(
              label: '备注',
              hint: '选填',
              multiline: true,
              maxLength: 100,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDrawer(double width) {
    return showAppDrawer<void>(
      context: context,
      builder: (drawerContext) => AppDrawer(
        title: '选择点评老师',
        subtitle: '已选 2 位，每件作品至少 1 位',
        width: width,
        actions: [
          AppButton(
            label: '取消',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: () => Navigator.of(drawerContext).pop(),
          ),
          AppButton(
            label: '确定',
            size: AppButtonSize.sm,
            onTap: () => Navigator.of(drawerContext).pop(),
          ),
        ],
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSearchField(hint: '搜索老师'),
            SizedBox(height: AppSpace.s12),
            AppListRow(
              leading: AppAvatar(name: '王建国', size: 36),
              title: '王建国',
              subtitle: '素描 · 联考冲刺 1 班',
              trailing: AppTag(label: '已选', tone: AppTone.brand),
              padding: EdgeInsets.symmetric(vertical: AppSpace.s12),
              divider: true,
            ),
            AppListRow(
              leading: AppAvatar(name: '陈思远', size: 36),
              title: '陈思远',
              subtitle: '色彩 · 联考冲刺 1 班',
              trailing: AppTag(label: '已选', tone: AppTone.brand),
              padding: EdgeInsets.symmetric(vertical: AppSpace.s12),
              divider: true,
            ),
            AppListRow(
              leading: AppAvatar(name: '李明', size: 36),
              title: '李明',
              subtitle: '速写 · 校考提高班',
              padding: EdgeInsets.symmetric(vertical: AppSpace.s12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _states() {
    return Wrap(
      spacing: AppSpace.s16,
      runSpacing: AppSpace.s16,
      children: [
        const SizedBox(
          width: 260,
          height: 240,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppSkeleton.circle(size: 36),
                    SizedBox(width: AppSpace.s12),
                    Expanded(child: AppSkeletonText(lines: 2)),
                  ],
                ),
                SizedBox(height: AppSpace.s16),
                AppSkeleton(height: 96, radius: AppRadius.control),
                SizedBox(height: AppSpace.s16),
                AppSkeletonText(lines: 2, lineHeight: 12),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 260,
          height: 240,
          child: AppCard(
            child: AppEmptyState(
              icon: Icons.palette_outlined,
              title: '还没有作品',
              description: '上传第一张画，老师点评后会出现在这里',
              actionLabel: '上传作品',
              onAction: () => AppToast.showInfo(context, '打开上传'),
            ),
          ),
        ),
        SizedBox(
          width: 260,
          height: 240,
          child: AppCard(
            child: AppErrorState(
              description: '请检查网络后重试',
              onRetry: () => AppToast.showInfo(context, '重新加载'),
            ),
          ),
        ),
        const SizedBox(
          width: 260,
          height: 240,
          child: AppCard(child: Center(child: AppLoadingIndicator(size: 36))),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color);

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hex = color
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();
    return SizedBox(
      width: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadius.br8,
              border: Border.all(color: AppColors.lineSoft),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption12Strong.copyWith(color: AppColors.ink),
          ),
          Text(
            '#${hex.substring(2)}',
            style: AppText.number(size: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
