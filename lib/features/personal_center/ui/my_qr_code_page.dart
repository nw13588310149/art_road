import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/ui/ui.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/personal_center_controller.dart';
import 'widgets/my_qr_code_card.dart';

/// 我的二维码（`/qrcode`）：专用路由，内容对齐个人中心弹窗内卡。
class MyQrCodePage extends ConsumerStatefulWidget {
  const MyQrCodePage({super.key});

  @override
  ConsumerState<MyQrCodePage> createState() => _MyQrCodePageState();
}

class _MyQrCodePageState extends ConsumerState<MyQrCodePage> {
  late Future<({String? url, String? error})> _qr;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qr = _fetch();
  }

  Future<({String? url, String? error})> _fetch() {
    return ref
        .read(personalCenterControllerProvider.notifier)
        .fetchQrImageUrl();
  }

  void _reload() {
    setState(() => _qr = _fetch());
  }

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(RoutePaths.personalCenter);
  }

  Future<void> _save(String url, String nickname) async {
    setState(() => _saving = true);
    await saveMyQrCode(context, imageUrl: url, nickname: nickname);
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(personalCenterControllerProvider);
    final user = profile.user;
    final nickname = user['nickname']?.toString().trim() ?? '';
    return FutureBuilder<({String? url, String? error})>(
      future: _qr,
      builder: (context, snapshot) {
        final result = snapshot.data;
        final url = result?.url;
        final ready = url != null && url.isNotEmpty && user.isNotEmpty;
        return ShellPageSurface(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _QrPageHeader(
                onBack: _back,
                saving: _saving,
                onSave: ready ? () => _save(url, nickname) : null,
              ),
              Expanded(child: _body(snapshot, profile.loading && user.isEmpty)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(
    AsyncSnapshot<({String? url, String? error})> snapshot,
    bool profileLoading,
  ) {
    final result = snapshot.data;
    if (snapshot.connectionState != ConnectionState.done || profileLoading) {
      return const _QrSkeleton();
    }
    final error = snapshot.hasError
        ? '网络异常，请稍后重试'
        : (result?.error ?? (result?.url == null ? '二维码为空' : null));
    if (error != null) {
      return AppErrorState(
        title: '二维码加载失败',
        description: error,
        onRetry: _reload,
      );
    }
    final user = ref.read(personalCenterControllerProvider).user;
    final nickname = user['nickname']?.toString().trim() ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: MyQrCodeCard(
            nickname: nickname.isEmpty ? '未命名' : nickname,
            mobile: user['mobile']?.toString() ?? '',
            avatarUrl: user['headUrl']?.toString() ?? '',
            imageUrl: result!.url!,
          ),
        ),
      ),
    );
  }
}

class _QrPageHeader extends StatelessWidget {
  const _QrPageHeader({
    required this.onBack,
    required this.saving,
    required this.onSave,
  });

  final VoidCallback onBack;
  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(62),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: ui(12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(8)),
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(ui(8)),
                child: Container(
                  width: ui(32),
                  height: ui(32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ui(8)),
                    border: Border.all(color: const Color(0xFFF3F2F3)),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: ui(20),
                    color: const Color(0xFF0B081A),
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '我的二维码',
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  fontSize: ui(16),
                  height: 1.1,
                  fontWeight: AppFont.w600,
                ),
              ),
              SizedBox(height: ui(3)),
              Text(
                '好友扫码即可下载美育集并添加你为好友',
                style: TextStyle(
                  color: const Color(0xFFB6B5BB),
                  fontFamily: 'PingFang SC',
                  fontSize: ui(12),
                  height: 1.1,
                  fontWeight: AppFont.w400,
                ),
              ),
            ],
          ),
          Positioned(
            right: ui(12),
            child: AppButton(
              label: saving ? '保存中…' : '保存到相册',
              icon: Icons.download_rounded,
              size: AppButtonSize.sm,
              loading: saving,
              onTap: onSave,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrSkeleton extends StatelessWidget {
  const _QrSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: const Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppSkeleton.circle(size: 44),
                  SizedBox(width: 12),
                  AppSkeleton(width: 96, height: 16),
                ],
              ),
              SizedBox(height: 12),
              AppSkeleton(width: 152, height: 154, radius: 12),
              SizedBox(height: 10),
              AppSkeleton(width: 220, height: 16),
              SizedBox(height: 6),
              AppSkeleton(width: 280, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
