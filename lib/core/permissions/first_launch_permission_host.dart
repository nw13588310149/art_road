import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/shell/ui/shell_layout.dart';
import '../providers/app_providers.dart';
import '../storage/app_storage.dart';
import '../ui/ui.dart';
import 'app_permission_service.dart';

/// 首次启动时说明用途并批量申请相机 / 相册 / 麦克风 / 通知权限。
///
/// 挂在 [MaterialApp.builder] 最外层（位于 Navigator 之上），弹窗通过
/// [navigatorKey] 打开；只执行一次，由 [AppStorage.nativePermissionsPrimed] 持久化。
class FirstLaunchPermissionHost extends ConsumerStatefulWidget {
  const FirstLaunchPermissionHost({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  ConsumerState<FirstLaunchPermissionHost> createState() =>
      _FirstLaunchPermissionHostState();
}

/// 权限说明：与 [AppPermissionService.essentialPermissions] 一一对应。
const firstLaunchPermissionItems = <({IconData icon, String name, String use})>[
  (
    icon: Icons.photo_camera_outlined,
    name: '相机',
    use: '拍摄作品与头像，考勤时进行人脸采集',
  ),
  (
    icon: Icons.photo_library_outlined,
    name: '相册与文件',
    use: '上传作品照片、课件与作业附件',
  ),
  (icon: Icons.mic_none_rounded, name: '麦克风', use: '仅在班级群聊发送语音消息时使用'),
  (
    icon: Icons.notifications_none_rounded,
    name: '通知',
    use: '接收成绩发布、作品点评、课程与审批提醒',
  ),
];

class _FirstLaunchPermissionHostState
    extends ConsumerState<FirstLaunchPermissionHost> {
  bool _started = false;
  bool _scheduled = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (layoutContext, constraints) {
        if (!_scheduled) {
          _scheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybePrime(layoutContext);
          });
        }
        final scale = DashboardScaleScope.fromSize(constraints.biggest);
        return DashboardScaleScope(
          data: scale,
          child: widget.child,
        );
      },
    );
  }

  Future<void> _maybePrime(BuildContext scopedContext) async {
    if (_started || !mounted) return;
    if (kIsWeb) return;
    final storage = ref.read(appStorageProvider);
    if (storage.nativePermissionsPrimed) return;
    final dialogContext = widget.navigatorKey?.currentContext ?? scopedContext;
    _started = true;

    final proceed = await showFirstLaunchPermissionDialog(dialogContext);
    if (!mounted) return;

    if (proceed) {
      await const AppPermissionService().requestEssentialPermissions();
    }
    await storage.setNativePermissionsPrimed(true);
  }
}

/// 权限用途说明弹窗：返回 true 表示继续申请。
Future<bool> showFirstLaunchPermissionDialog(BuildContext context) async {
  final result = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AppDialog(
      title: '权限使用说明',
      message: '为正常使用以下功能，绘画星球需要申请对应的系统权限。拒绝后不影响其他功能，也可以随时在系统设置中修改。',
      actions: [
        AppButton(
          label: '稍后再说',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(dialogContext).pop(false),
        ),
        AppButton(
          label: '去开启',
          onTap: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in firstLaunchPermissionItems)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s12),
              child: _PermissionRow(
                icon: item.icon,
                name: item.name,
                use: item.use,
              ),
            ),
          Text(
            '点击「去开启」后，系统会依次弹出授权窗口，请按需允许。',
            style: AppText.caption12,
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.name,
    required this.use,
  });

  final IconData icon;
  final String name;
  final String use;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: AppRadius.br8,
          ),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: AppText.body14Strong),
              Text(use, style: AppText.body13),
            ],
          ),
        ),
      ],
    );
  }
}
