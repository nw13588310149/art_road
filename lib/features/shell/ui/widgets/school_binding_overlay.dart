import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../state/school_binding_controller.dart';
import '../../state/school_binding_state.dart';

/// 「绑定画室」强制弹窗的整页遮罩。
///
/// 登录后若 `/v2/user/schoolList` 返回空列表，就在所有受保护页面之上盖一层遮罩，
/// 居中显示不可关闭的弹窗，用户必须完成绑定（三种阶段见 [SchoolBindingStage]）：
/// - [SchoolBindingStage.initial]：填写 6 位画室编码并提交；
/// - [SchoolBindingStage.pending]：审核中，可重新绑定；
/// - [SchoolBindingStage.rejected]：未通过，显示原因，可重新绑定。
///
/// 不弹路由：遮罩层吃掉所有点击，系统返回键 / 路由 pop 都无法关闭它，
/// 只有数据层的 hasSchool 变为 true 后由 ShellScaffold 卸载。
class SchoolBindingOverlay extends ConsumerStatefulWidget {
  const SchoolBindingOverlay({super.key});

  @override
  ConsumerState<SchoolBindingOverlay> createState() =>
      _SchoolBindingOverlayState();
}

class _SchoolBindingOverlayState extends ConsumerState<SchoolBindingOverlay> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(schoolBindingControllerProvider).schoolIdInput;
    _textController = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// 校验与接口错误写在 state.errorMessage，显示在输入框下方。
  Future<void> _submit() async {
    final notifier = ref.read(schoolBindingControllerProvider.notifier);
    final ok = await notifier.submitBinding();
    if (ok && mounted) {
      AppToast.showSuccess(context, '已提交，等待画室审核');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 控制器清空 schoolIdInput（重新绑定 / 提交成功）时同步输入框。
    ref.listen<SchoolBindingState>(schoolBindingControllerProvider, (
      previous,
      next,
    ) {
      if (next.schoolIdInput != _textController.text) {
        _textController.value = TextEditingValue(
          text: next.schoolIdInput,
          selection: TextSelection.collapsed(offset: next.schoolIdInput.length),
        );
      }
    });

    final state = ref.watch(schoolBindingControllerProvider);
    final notifier = ref.read(schoolBindingControllerProvider.notifier);
    final initial = state.stage == SchoolBindingStage.initial;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // 空 onTap：遮罩吃掉点击，避免点到下层页面。
              onTap: () {},
              child: const ColoredBox(color: AppColors.scrim),
            ),
          ),
          Positioned.fill(
            child: AppDialog(
              title: initial ? '绑定所在画室' : '画室绑定审核',
              message: _messageOf(state),
              showClose: false,
              actions: [
                AppButton(
                  label: initial ? '提交绑定' : '重新绑定',
                  loading: state.submitting,
                  onTap: initial ? _submit : notifier.enterRebindForm,
                ),
              ],
              child: initial
                  ? AppInputField(
                      controller: _textController,
                      label: '画室编码',
                      required: true,
                      hint: '请输入 6 位数字编码',
                      errorText: state.errorMessage.isEmpty
                          ? null
                          : state.errorMessage,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: notifier.setSchoolIdInput,
                      onSubmitted: (_) => _submit(),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: state.stage == SchoolBindingStage.pending
                          ? const AppStatusTag(
                              label: '审核中',
                              tone: AppTone.warning,
                            )
                          : const AppStatusTag(
                              label: '未通过',
                              tone: AppTone.danger,
                            ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static String _messageOf(SchoolBindingState state) {
    switch (state.stage) {
      case SchoolBindingStage.initial:
        return '请输入画室提供的 6 位编码，提交后由画室审核，通过后即可使用全部功能。';
      case SchoolBindingStage.pending:
        return '你的绑定申请正在审核，审核通过后会自动进入。编码填错了可以重新绑定。';
      case SchoolBindingStage.rejected:
        final reason = state.rejectReason.isEmpty
            ? '画室编码填写错误'
            : state.rejectReason;
        return '绑定申请未通过：$reason。请核对编码后重新绑定。';
    }
  }
}
