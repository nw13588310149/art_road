import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../state/personal_center_controller.dart';
import 'widgets/my_qr_code_card.dart';

/// 我的二维码（`/qrcode`）：与个人中心「我的二维码」弹窗内容一致。
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: '我的二维码',
              subtitle: '好友扫码即可下载绘画星球并添加你为好友',
              onBack: _back,
              actions: [
                AppButton(
                  label: '保存二维码',
                  icon: Icons.download_rounded,
                  size: AppButtonSize.sm,
                  loading: _saving,
                  onTap: ready ? () => _save(url, nickname) : null,
                ),
              ],
            ),
            Expanded(child: _body(snapshot, profile.loading && user.isEmpty)),
          ],
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
      padding: const EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.s4,
        AppSpace.page,
        AppSpace.s24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AppCard(
            child: MyQrCodeCard(
              nickname: nickname.isEmpty ? '未命名' : nickname,
              mobile: user['mobile']?.toString() ?? '',
              avatarUrl: user['headUrl']?.toString() ?? '',
              imageUrl: result!.url!,
              qrSize: 200,
            ),
          ),
        ),
      ),
    );
  }
}

class _QrSkeleton extends StatelessWidget {
  const _QrSkeleton();

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
          constraints: const BoxConstraints(maxWidth: 420),
          child: const AppCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppSkeleton.circle(size: 44),
                    SizedBox(width: AppSpace.s12),
                    AppSkeleton(width: 96, height: 16),
                  ],
                ),
                SizedBox(height: AppSpace.s16),
                AppSkeleton(width: 224, height: 224, radius: 12),
                SizedBox(height: AppSpace.s12),
                AppSkeleton(width: 200, height: 14),
                SizedBox(height: AppSpace.s8),
                AppSkeleton(width: 260, height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
