enum AuthScene { login, register, forgetPassword }

/// 校验失败时出错的位置：输入框下方显示错误，[terms] 表示需要先同意协议。
enum AuthField { mobile, password, confirmPassword, smsCode, terms }

class AuthState {
  const AuthState({
    this.mobile = '',
    this.password = '',
    this.confirmPassword = '',
    this.smsCode = '',
    this.isSubmitting = false,
    this.isSendingSms = false,
    this.smsCountDown = 0,
    this.agreeTerms = false,
    this.errorField,
    this.errorMessage = '',
  });

  final String mobile;
  final String password;
  final String confirmPassword;
  final String smsCode;
  final bool isSubmitting;
  final bool isSendingSms;
  final int smsCountDown;

  /// 是否已勾选同意协议；默认不勾选，只能由用户主动勾选或在协议弹窗里同意。
  final bool agreeTerms;
  final AuthField? errorField;
  final String errorMessage;

  String get smsButtonText =>
      smsCountDown > 0 ? '$smsCountDown 秒后重发' : '获取验证码';

  /// [field] 对应的错误文字，没有错误时为 null。
  String? errorOf(AuthField field) =>
      errorField == field && errorMessage.isNotEmpty ? errorMessage : null;

  AuthState copyWith({
    String? mobile,
    String? password,
    String? confirmPassword,
    String? smsCode,
    bool? isSubmitting,
    bool? isSendingSms,
    int? smsCountDown,
    bool? agreeTerms,
    AuthField? errorField,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      mobile: mobile ?? this.mobile,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      smsCode: smsCode ?? this.smsCode,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSendingSms: isSendingSms ?? this.isSendingSms,
      smsCountDown: smsCountDown ?? this.smsCountDown,
      agreeTerms: agreeTerms ?? this.agreeTerms,
      errorField: clearError ? null : (errorField ?? this.errorField),
      errorMessage: clearError ? '' : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthActionResult {
  const AuthActionResult({
    required this.success,
    required this.message,
    this.field,
  });

  final bool success;
  final String message;

  /// 校验失败的字段；为 null 时是接口结果，用轻提示展示。
  final AuthField? field;
}
