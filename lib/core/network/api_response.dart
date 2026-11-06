class ApiResponse {
  const ApiResponse({required this.code, required this.msg, this.data});

  final int code;
  final String msg;
  final dynamic data;

  bool get isSuccess => code == 0 || code == 200;

  /// 供 UI 展示的后端提示文案，直接使用接口返回的 [msg]。
  String get displayMsg => msg.trim();

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    final codeValue = json['code'];
    final parsedCode = codeValue is int
        ? codeValue
        : int.tryParse(codeValue?.toString() ?? '') ?? -1;

    return ApiResponse(
      code: parsedCode,
      msg: json['msg']?.toString() ?? '',
      data: json['data'],
    );
  }

  factory ApiResponse.failure(String message, {int code = -1}) {
    return ApiResponse(code: code, msg: message, data: null);
  }
}
