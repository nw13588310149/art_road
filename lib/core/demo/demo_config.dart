/// 演示模式开关。
///
/// v1 没有美术版正式后端，默认开启：所有接口由 `lib/core/demo/` 下的本地演示
/// 后端应答。对接真实后端时以 `--dart-define=DEMO_MODE=false` 构建即可，
/// 请求会按原路径发往 [AppConstants.apiBaseUrl] / [AppConstants.markingApiBaseUrl]。
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);
