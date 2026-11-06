import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import 'auth_design_canvas.dart';

/// 登录 / 注册 / 忘记密码页左侧装饰背景（统一使用设计稿导出图）。
class AuthBackgroundArt extends StatelessWidget {
  const AuthBackgroundArt({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Image.asset(
        AppAssets.authBg,
        width: AuthDesignCanvas.designSize.width,
        height: AuthDesignCanvas.designSize.height,
        fit: BoxFit.cover,
      ),
    );
  }
}
