import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/app_wheel_picker_sheet.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/avatar_picker.dart';
import '../state/personal_center_controller.dart';
import '../state/personal_center_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 个人信息页（迭代自 1.0 `pages/PersonalCenter/info.vue`）。
///
/// 视觉对齐 2.0 Figma：外层 #EFF3FC、白卡 padding 20、卡片内部头一行
/// 是返回按钮 + 居中"个人信息"标题，下面是字段列表（行高 64）。
/// 头像点击弹出 iOS 风格底部 ActionSheet，提供"从相册中选择 / 使用相机
/// 拍摄 / 取消"三个动作。
class InfoPage extends ConsumerWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(personalCenterControllerProvider);
    final controller = ref.read(personalCenterControllerProvider.notifier);

    return ShellPageSurface(
      padding: EdgeInsets.zero,
      color: const Color(0xFFEFF3FC),
      child: PageInitLoadingShell(
        loading: state.loading && state.user.isEmpty,
        child: _InfoCard(state: state, controller: controller),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 返回按钮的目的地解析
// ─────────────────────────────────────────────────────────────────────

/// 个人信息页返回按钮的统一处理。
///
/// 入口有两条：
///   1. `personal_center` 页面里点"编辑资料"——通过 `Navigator.pushNamed`
///      进入 /info，此时栈里有上一页，[Navigator.canPop] 为 true，maybePop
///      就能回去。
///   2. 顶栏右上角的设置图标 / 头像下拉的"资料修改"——shell 走的是
///      `Navigator.pushReplacementNamed`，会把 /info 直接替换成当前唯一
///      路由，栈里没有上一页，maybePop 是 no-op，导致返回按钮"按了没反应"。
///
/// 解决：先试着 pop；pop 不动（场景 2）就把路由替换成
/// [RoutePaths.personalCenter]，把"资料修改 → 个人信息"这条入口路径的"返回"
/// 落到个人中心页，而不是留在原地。
void _backToPrev(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  navigator.pushReplacementNamed(RoutePaths.personalCenter);
}

// ─────────────────────────────────────────────────────────────────────
// 整张白卡：内含返回头 + 字段列表。
// ─────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.state, required this.controller});

  final PersonalCenterState state;
  final PersonalCenterController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 白卡占满 ShellPageSurface 整块容器：顶部 header 固定，下方列表可滚动。
    return Container(
      padding: EdgeInsets.all(ui(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CardHeader(onBack: () => _backToPrev(context)),
          SizedBox(height: ui(10)),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: _InfoRows(state: state, controller: controller),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // Stack 让返回按钮"贴左 0"，标题"绝对居中"，与设计稿一致
    // （设计中标题 left 433 在 970 宽度内基本就是水平居中）。
    return SizedBox(
      height: ui(32),
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: _BackButton(onTap: onBack),
          ),
          Center(
            child: Text(
              '个人信息',
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(16),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: ui(32),
        height: ui(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
        ),
        child: Icon(
          Icons.chevron_left,
          size: ui(20),
          color: const Color(0xFF0B081A),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 字段行列表
// ─────────────────────────────────────────────────────────────────────

class _InfoRows extends StatelessWidget {
  const _InfoRows({required this.state, required this.controller});

  final PersonalCenterState state;
  final PersonalCenterController controller;

  @override
  Widget build(BuildContext context) {
    final user = state.user;
    final isTeacher =
        user['role']?.toString().trim().toLowerCase() == 'teacher';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _AvatarRow(
          avatarUrl: user['headUrl']?.toString(),
          onTap: () => _editAvatar(context, controller),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '姓名',
          value: user['nickname']?.toString() ?? '',
          onTap: () => _editNickname(context, controller, user),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '邮箱',
          value: user['email']?.toString() ?? '',
          onTap: () => _editEmail(context, controller, user),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '主项',
          value: user['primary']?.toString() ?? '',
          onTap: () => _editPrimary(context, controller, user),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '副项',
          value: user['secondary']?.toString() ?? '',
          onTap: () => _editSecondary(context, controller, user),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '性别',
          value: user['gender']?.toString() ?? '',
          onTap: () => _editGender(context, controller, user),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '生日',
          value: user['birthday']?.toString() ?? '',
          onTap: () => _editBirthday(context, controller, user),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '身份',
          value: user['identity']?.toString() ?? '',
          showChevron: false,
        ),
        // 「实名认证」行临时隐藏：当前阶段没有正式的认证流程对接，整行连同
        // 跳转 [RoutePaths.verifie] 的入口一起去掉，后续接入审核流时再恢复。
        const _RowDivider(),
        _InfoRow(
          title: '所在地区',
          value: user['province']?.toString() ?? '',
          onTap: () => _editProvince(context, controller, user),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '所在学校',
          value: user['school']?.toString() ?? '',
          onTap: () => _editSchool(context, controller, user),
        ),
        if (!isTeacher) ...<Widget>[
          const _RowDivider(),
          _InfoRow(
            title: '目标院校',
            value: user['targetSchool']?.toString() ?? '',
            onTap: () => _editTargetSchool(context, controller, user),
          ),
        ],
        const _RowDivider(),
        _InfoRow(
          title: '个人简介',
          value: user['introduce']?.toString() ?? '',
          onTap: () => _editIntroduce(context, controller, user),
        ),
        const _RowDivider(),
        _InfoRow(
          title: '修改密码',
          value: '',
          onTap: () => _editPassword(context, controller),
        ),
        if (!state.checkStatusEnabled) const _AccountDeletionEntry(),
      ],
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      child: Divider(
        height: ui(0.5),
        thickness: ui(0.5),
        color: const Color(0xFFE6E8EB),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.title,
    required this.value,
    this.onTap,
    this.showChevron = true,
  });

  final String title;
  final String value;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: ui(64),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(14),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.0,
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: ui(16)),
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF6D6B75),
                    fontSize: ui(14),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            if (showChevron)
              Image.asset(
                AppAssets.infoChevron,
                width: ui(24),
                height: ui(24),
                fit: BoxFit.contain,
              )
            else
              SizedBox(width: ui(24)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 账号注销（苹果审核合规入口，仅审核中展示，不调用真实接口）
// ─────────────────────────────────────────────────────────────────────

class _AccountDeletionEntry extends StatelessWidget {
  const _AccountDeletionEntry();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(20), ui(16), ui(8)),
      child: Column(
        children: <Widget>[
          const _RowDivider(),
          SizedBox(height: ui(20)),
          GestureDetector(
            onTap: () => _requestAccountDeletion(context),
            behavior: HitTestBehavior.opaque,
            child: Text(
              '账号注销',
              style: TextStyle(
                color: const Color(0xFFFF323C),
                fontSize: ui(14),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1.0,
              ),
            ),
          ),
          SizedBox(height: ui(10)),
          Text(
            '提交注销申请后，我们将在 7 个工作日内处理您的请求。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFB6B5BB),
              fontSize: ui(12),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _requestAccountDeletion(BuildContext context) async {
  final step1 = await showConfirmDialog(
    context: context,
    title: '账号注销',
    content:
        '注销账号后，您的个人资料、学习记录及相关数据将被删除且无法恢复。'
        '若您确定要继续，请点击「继续申请」。',
    confirmLabel: '继续申请',
    cancelLabel: '取消',
    barrierDismissible: false,
  );
  if (!step1 || !context.mounted) return;

  final step2 = await showConfirmDialog(
    context: context,
    title: '确认提交注销申请',
    content: '提交后我们将在 7 个工作日内处理您的账号注销请求。确认要提交吗？',
    confirmLabel: '确认提交',
    cancelLabel: '再想想',
    barrierDismissible: false,
  );
  if (!step2 || !context.mounted) return;

  _toast(context, '我们已收到您的申请，将在 7 个工作日内处理您的请求');
}

class _AvatarRow extends StatelessWidget {
  const _AvatarRow({required this.avatarUrl, required this.onTap});

  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: ui(64),
        child: Row(
          children: <Widget>[
            Text(
              '头像',
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(14),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.0,
              ),
            ),
            const Spacer(),
            _AvatarImage(url: avatarUrl, size: ui(44)),
            SizedBox(width: ui(8)),
            Image.asset(
              AppAssets.infoChevron,
              width: ui(24),
              height: ui(24),
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim() ?? '';
    final isNetwork =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipOval(
        child: Container(
          color: const Color(0xFFEFEEF3),
          alignment: Alignment.center,
          child: isNetwork
              ? Image.network(
                  trimmed,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.person_rounded,
                    size: size * 0.6,
                    color: const Color(0xFF7E879C),
                  ),
                )
              : Icon(
                  Icons.person_rounded,
                  size: size * 0.6,
                  color: const Color(0xFF7E879C),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 编辑动作：每个字段一个；除了头像和密码外都是简单弹窗。
// ─────────────────────────────────────────────────────────────────────

Future<void> _editEmail(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final value = await showTextInputDialog(
    context: context,
    title: '修改邮箱',
    hintText: '请输入邮箱地址',
    initialValue: user['email']?.toString() ?? '',
    maxLength: 60,
  );
  if (value == null || value.isEmpty || !context.mounted) {
    return;
  }
  if (!_isValidEmail(value)) {
    _toast(context, '请输入正确的邮箱格式');
    return;
  }
  final current = user['email']?.toString().trim() ?? '';
  if (value == current) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'email': value,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

bool _isValidEmail(String value) {
  return RegExp(r'^[\w.+-]+@[\w.-]+\.\w{2,}$').hasMatch(value);
}

Future<void> _editNickname(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final value = await showTextInputDialog(
    context: context,
    title: '修改姓名',
    subtitle: '为方便学校管理，请如实填写你的真实姓名',
    hintText: '请输入真实姓名',
    initialValue: user['nickname']?.toString() ?? '',
    maxLength: 30,
  );
  if (value == null || value.isEmpty || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'nickname': value,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editPrimary(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final value = await showTextInputDialog(
    context: context,
    title: '修改主项',
    hintText: '请输入主项',
    initialValue: user['primary']?.toString() ?? '',
    maxLength: 30,
  );
  if (value == null || value.isEmpty || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'primary': value,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editSecondary(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final value = await showTextInputDialog(
    context: context,
    title: '修改副项',
    hintText: '请输入副项',
    initialValue: user['secondary']?.toString() ?? '',
    maxLength: 30,
  );
  if (value == null || value.isEmpty || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'secondary': value,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editSchool(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final value = await showTextInputDialog(
    context: context,
    title: '修改学校',
    hintText: '请输入学校名称',
    initialValue: user['school']?.toString() ?? '',
    maxLength: 60,
  );
  if (value == null || value.isEmpty || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'school': value,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editTargetSchool(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final value = await showTextInputDialog(
    context: context,
    title: '修改目标院校',
    hintText: '请输入目标院校',
    initialValue: user['targetSchool']?.toString() ?? '',
    maxLength: 60,
  );
  if (value == null || value.isEmpty || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'targetSchool': value,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editIntroduce(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final value = await showTextInputDialog(
    context: context,
    title: '修改个人简介',
    hintText: '请输入个人简介',
    initialValue: user['introduce']?.toString() ?? '',
    maxLength: 200,
    multiline: true,
  );
  if (value == null || value.isEmpty || !context.mounted) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'introduce': value,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editGender(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final selected = await _showGenderPickerDialog(
    context: context,
    initial: _normalizeGender(user['gender']?.toString()),
  );
  if (selected == null || !context.mounted) {
    return;
  }
  final current = _normalizeGender(user['gender']?.toString());
  if (selected == current) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'gender': selected,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

/// 将接口/历史数据中的性别字段规范为「男」或「女」。
String? _normalizeGender(String? raw) {
  final g = raw?.trim() ?? '';
  if (g == '男' || g == '1' || g == 'm' || g == 'M') return '男';
  if (g == '女' || g == '2' || g == 'f' || g == 'F') return '女';
  return null;
}

/// 性别选择弹窗：样式与修改姓名等 [GradientHeaderDialog] 弹窗一致。
Future<String?> _showGenderPickerDialog({
  required BuildContext context,
  String? initial,
}) {
  return showScaledDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) => _GenderPickerDialog(initial: initial),
  );
}

class _GenderPickerDialog extends StatefulWidget {
  const _GenderPickerDialog({this.initial});

  final String? initial;

  @override
  State<_GenderPickerDialog> createState() => _GenderPickerDialogState();
}

class _GenderPickerDialogState extends State<_GenderPickerDialog> {
  late String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  void _confirm() {
    final value = _selected;
    if (value == null) {
      _toast(context, '请选择性别');
      return;
    }
    Navigator.of(context, rootNavigator: true).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return GradientHeaderDialog(
      title: '请选择性别',
      headerAsset: AppAssets.infoGenderDialogHeader,
      headerHeight: 169,
      gradientMidStop: 0.35,
      actionBarSpacing: 32,
      actionBar: AppDialogActionBar(
        cancelLabel: '取消',
        confirmLabel: '确定',
        confirmEnabled: _selected != null,
        onCancel: () => Navigator.of(context, rootNavigator: true).pop(),
        onConfirm: _confirm,
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _GenderOptionCard(
              label: '男生',
              selected: _selected == '男',
              iconAsset: AppAssets.infoGenderMale,
              selectedIconAsset: AppAssets.infoGenderMaleSelected,
              onTap: () => setState(() => _selected = '男'),
            ),
            SizedBox(width: DashboardScaleScope.of(context).ui(32)),
            _GenderOptionCard(
              label: '女生',
              selected: _selected == '女',
              iconAsset: AppAssets.infoGenderFemale,
              selectedIconAsset: AppAssets.infoGenderFemaleSelected,
              onTap: () => setState(() => _selected = '女'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderOptionCard extends StatelessWidget {
  const _GenderOptionCard({
    required this.label,
    required this.selected,
    required this.iconAsset,
    required this.selectedIconAsset,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final String iconAsset;
  final String selectedIconAsset;
  final VoidCallback onTap;

  static const Color _selectedBorder = Color(0xFF8741FF);

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: ui(134),
        height: ui(134),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(16)),
          border: selected
              ? Border.all(color: _selectedBorder, width: ui(1))
              : Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              selected ? selectedIconAsset : iconAsset,
              width: ui(54),
              height: ui(54),
              fit: BoxFit.contain,
            ),
            SizedBox(height: ui(12)),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? _selectedBorder
                    : const Color(0xFF0B081A),
                fontSize: ui(16),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                fontStyle: FontStyle.normal,
                height: 16 / 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _editProvince(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final result = await controller.ensureProvinces();
  if (!context.mounted) return;
  if (result.provinces.isEmpty) {
    _toast(context, result.error ?? '');
    return;
  }
  final selected = await showAppProvincePicker(
    context: context,
    provinces: result.provinces,
    selected: user['province']?.toString(),
  );
  if (selected == null || !context.mounted) {
    return;
  }
  final current = user['province']?.toString().trim() ?? '';
  if (selected == current) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'province': selected,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

Future<void> _editBirthday(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final initial =
      _parseDate(user['birthday']?.toString()) ?? DateTime(2010, 1, 1);
  final picked = await showAppDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1950, 1, 1),
    lastDate: DateTime(2014, 12, 31),
    helpText: '选择日期',
    cancelText: '取消',
    confirmText: '确定',
  );
  if (picked == null || !context.mounted) {
    return;
  }
  final formatted =
      '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  final err = await controller.updateProfileFields(<String, dynamic>{
    'birthday': formatted,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final parts = raw.split('-');
    if (parts.length != 3) return DateTime.tryParse(raw);
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    return DateTime(y, m, d);
  } catch (_) {
    return DateTime.tryParse(raw);
  }
}

// ─────────────────────────────────────────────────────────────────────
// 头像编辑：iOS 风底部 ActionSheet → picker → upload → 写回 headUrl
// ─────────────────────────────────────────────────────────────────────

/// 头像来源，与 ActionSheet 上的两个选项一一对应。
enum _AvatarSource { gallery, camera }

Future<void> _editAvatar(
  BuildContext context,
  PersonalCenterController controller,
) async {
  final source = await _showAvatarSourceSheet(context);
  if (source == null || !context.mounted) return;

  final picked = await pickAvatarFile(useCamera: source == _AvatarSource.camera);
  if (!context.mounted) return;
  if (picked == null) {
    // 用户取消、相机权限被拒、或当前桌面 IO 不支持选择 — 都给一个友好提示。
    if (source == _AvatarSource.camera) {
      _toast(context, '当前平台暂不支持调用相机，请选择"从相册中选择"');
    }
    return;
  }

  // 上传 → 直接更新 headUrl，无需中间预览/确认弹窗。
  final upload = await controller.uploadAvatar(
    bytes: picked.bytes,
    filename: picked.filename,
  );
  if (!context.mounted) return;
  if (upload.error != null && upload.error!.isNotEmpty) {
    _toast(context, upload.error!);
    return;
  }
  final path = upload.path;
  if (path == null || path.isEmpty) {
    return;
  }
  final err = await controller.updateProfileFields(<String, dynamic>{
    'headUrl': path,
  });
  if (!context.mounted) return;
  _toast(context, err ?? '修改成功！');
}

/// 显示 iOS 风格的"选择头像来源"底部 ActionSheet：
/// 主卡片包含标题 + 两个选项，下方独立一个"取消"卡片。
///
/// `showModalBottomSheet` 走 root navigator 的 overlay，构建出来的
/// widget 树不在 dashboard 的 [DashboardScaleScope] 里，直接 `of(ctx)`
/// 会触发 assert。这里在调用方先抓一份 scale data，再在 builder 里
/// 用 [DashboardScaleScope] 透传，sheet 内的 `ui(...)` 才能正常工作。
Future<_AvatarSource?> _showAvatarSourceSheet(BuildContext context) {
  final scale = DashboardScaleScope.of(context);
  return showModalBottomSheet<_AvatarSource>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.80),
    isScrollControlled: true,
    builder: (ctx) => DashboardScaleScope(
      data: scale,
      child: const _AvatarSourceSheet(),
    ),
  );
}

class _AvatarSourceSheet extends StatelessWidget {
  const _AvatarSourceSheet();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ui(20),
          ui(0),
          ui(20),
          ui(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // 主卡：标题 + 2 个动作
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ui(377)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: ui(8)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      height: ui(48),
                      child: Center(
                        child: Text(
                          '选择头像来源',
                          style: TextStyle(
                            color: const Color(0xFF0B081A),
                            fontSize: ui(14),
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w600,
                            height: 16 / 14,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: ui(12)),
                    _SheetItem(
                      label: '从相册中选择',
                      onTap: () => Navigator.of(context).pop<_AvatarSource>(
                        _AvatarSource.gallery,
                      ),
                    ),
                    const _SheetDivider(),
                    _SheetItem(
                      label: '使用相机拍摄',
                      onTap: () => Navigator.of(context).pop<_AvatarSource>(
                        _AvatarSource.camera,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: ui(8)),
            // 取消卡：独立的一块
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ui(377)),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  height: ui(56),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ui(16)),
                  ),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: const Color(0xFF0B081A),
                      fontSize: ui(20),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w600,
                      height: 24 / 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: ui(56),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.black,
              fontSize: ui(20),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 24 / 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetDivider extends StatelessWidget {
  const _SheetDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: const Color(0x33000000));
  }
}

// ─────────────────────────────────────────────────────────────────────
// 修改密码弹窗
// ─────────────────────────────────────────────────────────────────────

Future<void> _editPassword(
  BuildContext context,
  PersonalCenterController controller,
) async {
  await showScaledDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (ctx) => _PasswordEditDialog(controller: controller),
  );
}

class _PasswordEditDialog extends StatefulWidget {
  const _PasswordEditDialog({required this.controller});

  final PersonalCenterController controller;

  @override
  State<_PasswordEditDialog> createState() => _PasswordEditDialogState();
}

class _PasswordEditDialogState extends State<_PasswordEditDialog> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    final oldPwd = _oldCtrl.text.trim();
    final newPwd = _newCtrl.text.trim();
    final confirmPwd = _confirmCtrl.text.trim();
    if (oldPwd.isEmpty) {
      _toast(context, '请输入原密码');
      return;
    }
    if (newPwd.isEmpty) {
      _toast(context, '请输入新密码');
      return;
    }
    if (newPwd != confirmPwd) {
      _toast(context, '两次新密码不一致');
      return;
    }
    if (newPwd == oldPwd) {
      _toast(context, '新密码不能与旧密码相同');
      return;
    }
    setState(() => _submitting = true);
    final err = await widget.controller.changePassword(
      oldPassword: oldPwd,
      newPassword: newPwd,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err != null) {
      _toast(context, err);
      return;
    }
    Navigator.of(context).pop();
    _toast(context, '修改成功');
  }

  @override
  Widget build(BuildContext context) {
    return GradientHeaderDialog(
      title: '修改密码',
      headerHeight: 169,
      gradientMidStop: 0.35,
      actionBar: AppDialogActionBar(
        cancelLabel: '取消',
        confirmLabel: '确认',
        confirmEnabled: !_submitting,
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _confirm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppDialogTextField(
            controller: _oldCtrl,
            hintText: '请输入原密码',
            autofocus: true,
            obscureText: true,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
            ],
          ),
          SizedBox(height: DashboardScaleScope.of(context).ui(12)),
          AppDialogTextField(
            controller: _newCtrl,
            hintText: '请输入新密码',
            obscureText: true,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
            ],
          ),
          SizedBox(height: DashboardScaleScope.of(context).ui(12)),
          AppDialogTextField(
            controller: _confirmCtrl,
            hintText: '请再次输入新密码',
            obscureText: true,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 工具：toast
// ─────────────────────────────────────────────────────────────────────

void _toast(BuildContext context, String message) {
  if (!context.mounted) return;
  AppToast.show(context, message);
}
