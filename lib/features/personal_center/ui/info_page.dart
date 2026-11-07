import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/app_wheel_picker_sheet.dart';
import '../data/avatar_picker.dart';
import '../state/personal_center_controller.dart';
import '../state/personal_center_state.dart';
import '../state/profile_format.dart';

/// 个人信息页：在统一白色面板内展示个人资料、学籍与账号安全。
class InfoPage extends ConsumerWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(personalCenterControllerProvider);
    final controller = ref.read(personalCenterControllerProvider.notifier);

    final Widget body;
    if (state.loading && state.user.isEmpty) {
      body = const _InfoSkeleton();
    } else if ((state.errorMessage ?? '').isNotEmpty && state.user.isEmpty) {
      body = AppErrorState(
        title: '个人资料加载失败',
        description: state.errorMessage,
        onRetry: controller.refresh,
      );
    } else {
      body = _InfoBody(state: state, controller: controller);
    }

    return AppCard(
      padding: EdgeInsets.zero,
      bordered: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(
            centerTitle: true,
            title: '个人信息',
            subtitle: '头像、资料与登录密码',
            onBack: () => _backToPrev(context),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// 从个人中心 push 进来时直接返回；从顶栏菜单（replacement）进来时回到个人中心。
void _backToPrev(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  navigator.pushReplacementNamed(RoutePaths.personalCenter);
}

class _InfoBody extends StatelessWidget {
  const _InfoBody({required this.state, required this.controller});

  final PersonalCenterState state;
  final PersonalCenterController controller;

  @override
  Widget build(BuildContext context) {
    final user = state.user;
    final isTeacher =
        user['role']?.toString().trim().toLowerCase() == 'teacher';
    String field(String key) => user[key]?.toString().trim() ?? '';
    final name = field('nickname');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.s4,
        AppSpace.page,
        AppSpace.s24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FieldGroup(
                title: '基本资料',
                rows: [
                  AppListRow(
                    title: '头像',
                    trailing: AppAvatar(
                      name: name.isEmpty ? '我' : name,
                      url: field('headUrl'),
                    ),
                    chevron: true,
                    onTap: () => _editAvatar(context, controller),
                  ),
                  _fieldRow(
                    '姓名',
                    name,
                    () => _editText(
                      context,
                      controller,
                      key: 'nickname',
                      title: '修改姓名',
                      message: '为方便画室管理，请填写真实姓名',
                      hint: '请输入真实姓名',
                      initial: name,
                      maxLength: 30,
                    ),
                  ),
                  _fieldRow(
                    '性别',
                    field('gender'),
                    () => _editGender(context, controller, user),
                  ),
                  _fieldRow(
                    '生日',
                    formatProfileDate(field('birthday')),
                    () => _editBirthday(context, controller, user),
                  ),
                  _fieldRow(
                    '所在地区',
                    field('province'),
                    () => _editProvince(context, controller, user),
                  ),
                  _fieldRow(
                    '邮箱',
                    field('email'),
                    () => _editEmail(context, controller, user),
                  ),
                  _fieldRow(
                    '个人简介',
                    field('introduce'),
                    () => _editText(
                      context,
                      controller,
                      key: 'introduce',
                      title: '修改个人简介',
                      hint: '介绍一下自己，如备考目标、擅长的科目',
                      initial: field('introduce'),
                      maxLength: 200,
                      multiline: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s16),
              _FieldGroup(
                title: isTeacher ? '任教信息' : '学籍信息',
                rows: [
                  _fieldRow('身份', field('identity'), null),
                  _fieldRow(
                    '所在画室',
                    field('school'),
                    () => _editText(
                      context,
                      controller,
                      key: 'school',
                      title: '修改所在画室',
                      hint: '请输入画室名称',
                      initial: field('school'),
                      maxLength: 60,
                    ),
                  ),
                  if (field('campus').isNotEmpty)
                    _fieldRow('所在校区', field('campus'), null),
                  _fieldRow(
                    '专业方向',
                    field('primary'),
                    () => _editText(
                      context,
                      controller,
                      key: 'primary',
                      title: '修改专业方向',
                      hint: '如美术与设计类',
                      initial: field('primary'),
                      maxLength: 30,
                    ),
                  ),
                  _fieldRow(
                    '擅长科目',
                    field('secondary'),
                    () => _editText(
                      context,
                      controller,
                      key: 'secondary',
                      title: '修改擅长科目',
                      hint: '如素描、色彩、速写',
                      initial: field('secondary'),
                      maxLength: 30,
                    ),
                  ),
                  if (!isTeacher)
                    _fieldRow(
                      '目标院校',
                      field('targetSchool'),
                      () => _editText(
                        context,
                        controller,
                        key: 'targetSchool',
                        title: '修改目标院校',
                        hint: '请输入目标院校',
                        initial: field('targetSchool'),
                        maxLength: 60,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.s16),
              _FieldGroup(
                title: '账号安全',
                rows: [
                  _fieldRow('登录手机号', maskMobile(field('mobile')), null),
                  AppListRow(
                    title: '修改密码',
                    chevron: true,
                    onTap: () => showAppDialog<void>(
                      context: context,
                      builder: (_) =>
                          _PasswordEditDialog(controller: controller),
                    ),
                  ),
                  if (!state.checkStatusEnabled)
                    AppListRow(
                      title: '账号注销',
                      subtitle: '提交申请后我们会在 7 个工作日内处理',
                      chevron: true,
                      onTap: () => _requestAccountDeletion(context),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _fieldRow(String label, String value, VoidCallback? onTap) {
    final empty = value.isEmpty;
    return AppListRow(
      title: label,
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Text(
          empty ? (onTap == null ? '—' : '未填写') : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: AppText.body14.copyWith(
            color: empty ? AppColors.textPlaceholder : AppColors.textSecondary,
          ),
        ),
      ),
      chevron: onTap != null,
      onTap: onTap,
    );
  }
}

class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      bordered: false,
      padding: const EdgeInsets.only(bottom: AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s16,
              AppSpace.s16,
              AppSpace.s4,
            ),
            child: Text(title, style: AppText.title16),
          ),
          for (var i = 0; i < rows.length; i++)
            if (i < rows.length - 1)
              DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
                ),
                child: rows[i],
              )
            else
              rows[i],
        ],
      ),
    );
  }
}

class _InfoSkeleton extends StatelessWidget {
  const _InfoSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.s4,
        AppSpace.page,
        AppSpace.s24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: const Column(
            children: [
              AppCard(child: AppSkeletonText(lines: 7, lineHeight: 18)),
              SizedBox(height: AppSpace.s16),
              AppCard(child: AppSkeletonText(lines: 5, lineHeight: 18)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 编辑动作
// ─────────────────────────────────────────────────────────────────────

Future<void> _save(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> changes,
) async {
  final err = await controller.updateProfileFields(changes);
  if (!context.mounted) {
    return;
  }
  if (err != null) {
    AppToast.showError(context, err);
  } else {
    AppToast.showSuccess(context, '已保存');
  }
}

Future<void> _editText(
  BuildContext context,
  PersonalCenterController controller, {
  required String key,
  required String title,
  required String hint,
  required String initial,
  required int maxLength,
  String? message,
  bool multiline = false,
}) async {
  final value = await showAppDialog<String>(
    context: context,
    builder: (_) => _TextEditDialog(
      title: title,
      message: message,
      hint: hint,
      initial: initial,
      maxLength: maxLength,
      multiline: multiline,
    ),
  );
  if (value == null || value.isEmpty || value == initial || !context.mounted) {
    return;
  }
  await _save(context, controller, <String, dynamic>{key: value});
}

Future<void> _editEmail(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final current = user['email']?.toString().trim() ?? '';
  final value = await showAppDialog<String>(
    context: context,
    builder: (_) => _TextEditDialog(
      title: current.isEmpty ? '填写邮箱' : '修改邮箱',
      hint: '请输入邮箱地址',
      initial: current,
      maxLength: 60,
      keyboardType: TextInputType.emailAddress,
      validator: (value) =>
          RegExp(r'^[\w.+-]+@[\w.-]+\.\w{2,}$').hasMatch(value)
          ? null
          : '邮箱格式不正确，如 name@example.com',
    ),
  );
  if (value == null || value.isEmpty || value == current || !context.mounted) {
    return;
  }
  await _save(context, controller, <String, dynamic>{'email': value});
}

/// 将接口 / 历史数据中的性别字段规范为「男」或「女」。
String? _normalizeGender(String? raw) {
  final g = raw?.trim() ?? '';
  if (g == '男' || g == '1' || g == 'm' || g == 'M') return '男';
  if (g == '女' || g == '2' || g == 'f' || g == 'F') return '女';
  return null;
}

Future<void> _editGender(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final current = _normalizeGender(user['gender']?.toString());
  final selected = await showAppDialog<String>(
    context: context,
    builder: (_) => _GenderDialog(initial: current),
  );
  if (selected == null || selected == current || !context.mounted) {
    return;
  }
  await _save(context, controller, <String, dynamic>{'gender': selected});
}

Future<void> _editProvince(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final result = await controller.ensureProvinces();
  if (!context.mounted) return;
  if (result.provinces.isEmpty) {
    AppToast.showError(context, result.error ?? '地区列表加载失败，请稍后重试');
    return;
  }
  final selected = await showAppProvincePicker(
    context: context,
    provinces: result.provinces,
    selected: user['province']?.toString(),
  );
  final current = user['province']?.toString().trim() ?? '';
  if (selected == null || selected == current || !context.mounted) {
    return;
  }
  await _save(context, controller, <String, dynamic>{'province': selected});
}

Future<void> _editBirthday(
  BuildContext context,
  PersonalCenterController controller,
  Map<String, dynamic> user,
) async {
  final initial =
      DateTime.tryParse(user['birthday']?.toString() ?? '') ??
      DateTime(2010, 1, 1);
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
  await _save(context, controller, <String, dynamic>{
    'birthday': formatProfileDate(picked.toIso8601String()),
  });
}

enum _AvatarSource { gallery, camera }

Future<void> _editAvatar(
  BuildContext context,
  PersonalCenterController controller,
) async {
  final source = await showAppDialog<_AvatarSource>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: '更换头像',
      message: '从相册选择一张照片，或用相机拍摄。',
      actions: [
        AppButton(
          label: '拍照',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(dialogContext).pop(_AvatarSource.camera),
        ),
        AppButton(
          label: '从相册选择',
          onTap: () => Navigator.of(dialogContext).pop(_AvatarSource.gallery),
        ),
      ],
    ),
  );
  if (source == null || !context.mounted) return;

  final picked = await pickAvatarFile(
    useCamera: source == _AvatarSource.camera,
  );
  if (!context.mounted) return;
  if (picked == null) {
    if (source == _AvatarSource.camera) {
      AppToast.showInfo(context, '当前设备暂不支持拍照，请从相册选择');
    }
    return;
  }

  final upload = await controller.uploadAvatar(
    bytes: picked.bytes,
    filename: picked.filename,
  );
  if (!context.mounted) return;
  final error = upload.error;
  if (error != null && error.isNotEmpty) {
    AppToast.showError(context, error);
    return;
  }
  final path = upload.path;
  if (path == null || path.isEmpty) {
    return;
  }
  await _save(context, controller, <String, dynamic>{'headUrl': path});
}

Future<void> _requestAccountDeletion(BuildContext context) async {
  final step1 = await showAppConfirm(
    context: context,
    title: '注销账号',
    message: '注销后，你的个人资料、学习记录及相关数据将被删除且无法恢复。',
    confirmLabel: '继续申请',
    danger: true,
    barrierDismissible: false,
  );
  if (!step1 || !context.mounted) return;

  final step2 = await showAppConfirm(
    context: context,
    title: '提交注销申请',
    message: '提交后我们将在 7 个工作日内处理你的注销申请。',
    confirmLabel: '确定',
    cancelLabel: '再想想',
    danger: true,
    barrierDismissible: false,
  );
  if (!step2 || !context.mounted) return;

  AppToast.showSuccess(context, '已收到你的注销申请，我们将在 7 个工作日内处理');
}

// ─────────────────────────────────────────────────────────────────────
// 弹窗
// ─────────────────────────────────────────────────────────────────────

class _TextEditDialog extends StatefulWidget {
  const _TextEditDialog({
    required this.title,
    required this.hint,
    required this.initial,
    required this.maxLength,
    this.message,
    this.multiline = false,
    this.keyboardType,
    this.validator,
  });

  final String title;
  final String? message;
  final String hint;
  final String initial;
  final int maxLength;
  final bool multiline;
  final TextInputType? keyboardType;

  /// 返回错误提示；合法时返回 null。
  final String? Function(String value)? validator;

  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _ctrl.text.trim();
    if (value.isEmpty) {
      setState(() => _error = '内容不能为空');
      return;
    }
    final error = widget.validator?.call(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.title,
      message: widget.message,
      actions: [
        AppButton(
          label: '取消',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(context).pop(),
        ),
        AppButton(label: '保存', onTap: _submit),
      ],
      child: AppInputField(
        controller: _ctrl,
        hint: widget.hint,
        maxLength: widget.maxLength,
        multiline: widget.multiline,
        errorText: _error,
        autofocus: true,
        keyboardType: widget.keyboardType,
        textInputAction: widget.multiline
            ? TextInputAction.newline
            : TextInputAction.done,
        onChanged: (_) {
          if (_error != null) {
            setState(() => _error = null);
          }
        },
        onSubmitted: widget.multiline ? null : (_) => _submit(),
      ),
    );
  }
}

class _GenderDialog extends StatefulWidget {
  const _GenderDialog({this.initial});

  final String? initial;

  @override
  State<_GenderDialog> createState() => _GenderDialogState();
}

class _GenderDialogState extends State<_GenderDialog> {
  late String _selected = widget.initial ?? '男';

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '选择性别',
      actions: [
        AppButton(
          label: '取消',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: '保存',
          onTap: () => Navigator.of(context).pop(_selected),
        ),
      ],
      child: AppSegmented<String>(
        segments: const [
          AppSegment(value: '男', label: '男'),
          AppSegment(value: '女', label: '女'),
        ],
        value: _selected,
        expand: true,
        onChanged: (value) => setState(() => _selected = value),
      ),
    );
  }
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
  String? _oldError;
  String? _newError;
  String? _confirmError;

  static final _noSpaces = <TextInputFormatter>[
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
  ];

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
    setState(() {
      _oldError = oldPwd.isEmpty ? '请输入原密码' : null;
      _newError = newPwd.isEmpty
          ? '请输入新密码'
          : newPwd == oldPwd
          ? '新密码不能与原密码相同'
          : null;
      _confirmError = _newError == null && newPwd != confirmPwd
          ? '两次输入的新密码不一致'
          : null;
    });
    if (_oldError != null || _newError != null || _confirmError != null) {
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
      AppToast.showError(context, err);
      return;
    }
    Navigator.of(context).pop();
    AppToast.showSuccess(context, '密码已修改');
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '修改密码',
      actions: [
        AppButton(
          label: '取消',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(context).pop(),
        ),
        AppButton(label: '保存', loading: _submitting, onTap: _confirm),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInputField(
            controller: _oldCtrl,
            label: '原密码',
            hint: '请输入原密码',
            errorText: _oldError,
            obscureText: true,
            autofocus: true,
            inputFormatters: _noSpaces,
          ),
          const SizedBox(height: AppSpace.s12),
          AppInputField(
            controller: _newCtrl,
            label: '新密码',
            hint: '请输入新密码，不含空格',
            errorText: _newError,
            obscureText: true,
            inputFormatters: _noSpaces,
          ),
          const SizedBox(height: AppSpace.s12),
          AppInputField(
            controller: _confirmCtrl,
            label: '确认新密码',
            hint: '请再次输入新密码',
            errorText: _confirmError,
            obscureText: true,
            inputFormatters: _noSpaces,
          ),
        ],
      ),
    );
  }
}
