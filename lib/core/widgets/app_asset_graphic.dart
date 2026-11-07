import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppAssetGraphic extends StatelessWidget {
  const AppAssetGraphic(
    this.asset, {
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.colorFilter,
    super.key,
  });

  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ColorFilter? colorFilter;

  Widget _buildMissing(BuildContext context, Object error, StackTrace? stack) =>
      SizedBox(width: width, height: height);

  static bool isVectorAsset(String asset) {
    if (asset.endsWith('.svg')) {
      return true;
    }

    // 部分原版图标以 .png 命名，文件内容实际是 SVG。
    // 按文件格式选择解码器，避免图片读取失败时把二进制数据送入 XML 解析器。
    const vectorPngs = <String>{
      'assets/images/aichat/ai_v2_tool_analyze.png',
      'assets/images/aichat/ai_v2_tool_suggest.png',
      'assets/images/auth/v2_bg_shape.png',
      'assets/images/auth/v2_ellipse_big.png',
      'assets/images/auth/v2_ellipse_small.png',
      'assets/images/auth/v2_icon_password.png',
      'assets/images/auth/v2_icon_phone.png',
      'assets/images/shell/topbar_v2/more_arrow.png',
    };
    return vectorPngs.contains(asset);
  }

  @override
  Widget build(BuildContext context) {
    if (isVectorAsset(asset)) {
      return SvgPicture.asset(
        asset,
        width: width,
        height: height,
        fit: fit,
        colorFilter: colorFilter,
        errorBuilder: _buildMissing,
      );
    }
    final image = Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: _buildMissing,
    );
    final filter = colorFilter;
    return filter == null
        ? image
        : ColorFiltered(colorFilter: filter, child: image);
  }
}
