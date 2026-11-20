import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../constants/app_constants.dart';
import '../demo/demo_accounts.dart';
import '../demo/demo_api_interceptor.dart';
import '../demo/demo_backend.dart';
import '../storage/app_storage.dart';
import 'api_response.dart';
import 'api_unauthorized_handler.dart';
import 'big_int_safe_transformer.dart';
import 'media_url.dart';
import 'secure_redirect_adapter.dart';

class ApiClient {
  static const String extraLightweightJson = 'lightweightJson';

  static final _demoCredential = RegExp(
    r'^(?:Bearer\s+)?demo\.',
    caseSensitive: false,
  );

  static const _accountEndpoints = <String>{
    '/app/user/mobileLogin',
    '/app/user/register',
    '/app/user/resetPassword',
    '/app/user/sendSmsCode',
  };

  static const _credentialHeaders = {
    'app-token',
    'school-token',
    'token',
    'authorization',
  };

  ApiClient({
    required AppStorage storage,
    String? baseUrl,
    DemoRouter? demoRouter,
    bool dispatchDemoBySession = true,
    Map<String, dynamic> Function(AppStorage storage)? authHeaders,
  }) : _storage = storage,
       _authHeaders = authHeaders ?? _platformAuthHeaders,
       _hasDemoRouter = demoRouter != null,
       _dispatchDemoBySession = dispatchDemoBySession {
    final configured = AppConstants.secureApiBase(
      baseUrl ?? AppConstants.apiBaseUrl,
    );
    _hasRealBase = configured.isNotEmpty;
    _baseUri = Uri.parse(
      _hasRealBase ? configured : 'https://local-demo.invalid/',
    );
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUri.toString(),
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
        contentType: Headers.jsonContentType,
      ),
    )..transformer = const BigIntSafeTransformer();
    _dio.httpClientAdapter = protectRedirects(_dio.httpClientAdapter);
    if (demoRouter != null) {
      _dio.interceptors.add(DemoApiInterceptor(router: demoRouter));
    }
  }

  final AppStorage _storage;
  late final Dio _dio;
  late final Uri _baseUri;
  late final bool _hasRealBase;
  bool _disposed = false;
  final bool _hasDemoRouter;
  final bool _dispatchDemoBySession;
  final Map<String, dynamic> Function(AppStorage storage) _authHeaders;

  static Map<String, dynamic> _platformAuthHeaders(AppStorage storage) =>
      <String, dynamic>{
        'app-token': storage.token,
        'schoolId': storage.schoolId,
      };

  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    Duration? timeout,
  }) => _requestJson(
    'GET',
    path,
    queryParameters: queryParameters,
    headers: headers,
    timeout: timeout,
  );

  Future<ApiResponse> post(
    String path, {
    Object? data,
    Map<String, dynamic>? headers,
    Duration? timeout,
    bool lightweightJson = false,
  }) => _requestJson(
    'POST',
    path,
    data: data,
    headers: headers,
    timeout: timeout,
    lightweightJson: lightweightJson,
  );

  Future<ApiResponse> postFormData(
    String path, {
    required FormData data,
    void Function(int sent, int total)? onSendProgress,
    Map<String, dynamic>? headers,
    Duration? timeout,
  }) => _requestJson(
    'POST',
    path,
    data: data,
    headers: headers,
    timeout: timeout,
    onSendProgress: onSendProgress,
  );

  Future<ApiResponse> _requestJson(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    Duration? timeout,
    bool lightweightJson = false,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final session = _captureSession();
    try {
      final options = _buildOptions(
        method,
        path,
        session,
        data: data,
        headers: headers,
        timeout: timeout,
        lightweightJson: lightweightJson,
      );
      final response = await _dio.request<dynamic>(
        _baseUri.resolve(path).toString(),
        data: data,
        queryParameters: queryParameters,
        onSendProgress: onSendProgress,
        options: options,
      );
      return _finalizeResponse(
        response.requestOptions,
        session,
        _normalizeForPath(
          response.requestOptions.uri.path,
          _toApiResponse(response.data),
        ),
      );
    } on DioException catch (error) {
      return _finalizeResponse(
        error.requestOptions,
        session,
        _fromDioException(error),
      );
    } on _ApiUnavailable catch (error) {
      return ApiResponse.failure(error.message);
    } catch (_) {
      return ApiResponse.failure('网络异常，请稍后重试');
    }
  }

  Future<Uint8List> getBytes(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    Duration? timeout,
    bool allowEmpty = false,
  }) async {
    final session = _captureSession();
    try {
      final response = await _dio.get<List<int>>(
        _baseUri.resolve(url).toString(),
        queryParameters: queryParameters,
        options: _buildOptions(
          'GET',
          url,
          session,
          headers: headers,
          timeout: timeout,
        ).copyWith(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || (!allowEmpty && bytes.isEmpty)) {
        throw StateError('Empty response bytes');
      }
      return Uint8List.fromList(bytes);
    } on DioException catch (error) {
      _finalizeResponse(
        error.requestOptions,
        session,
        _fromDioException(error),
      );
      rethrow;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _dio.close(force: true);
  }

  Future<void> updateToken(String token) async {
    if (_disposed) return;
    await _storage.saveToken(token);
  }

  ({String token, int generation}) _captureSession() => (
    token: _storage.token,
    generation: ApiUnauthorizedHandler.instance.sessionGeneration,
  );

  Options _buildOptions(
    String method,
    String path,
    ({String token, int generation}) session, {
    Object? data,
    Map<String, dynamic>? headers,
    Duration? timeout,
    bool lightweightJson = false,
  }) {
    if (_disposed) throw const _ApiUnavailable('请求已取消，请重试');
    final sessionToken = session.token;
    final uri = _baseUri.resolve(path);
    final firstParty =
        uri.scheme == _baseUri.scheme &&
        uri.host == _baseUri.host &&
        uri.port == _baseUri.port;
    final accountRequest =
        firstParty && method == 'POST' && _accountEndpoints.contains(uri.path);
    final forcedDemo = !_dispatchDemoBySession && _hasDemoRouter;
    final demoAccount =
        accountRequest &&
        data is Map &&
        DemoAccounts.lookupMobile(data['mobile']?.toString().trim() ?? '') !=
            null;
    final useDemo =
        firstParty &&
        (forcedDemo || (accountRequest ? demoAccount : _storage.isDemoSession));
    if (useDemo && !_hasDemoRouter) {
      throw const _ApiUnavailable('演示服务暂不可用');
    }
    if (firstParty &&
        !accountRequest &&
        !useDemo &&
        DemoAccounts.isObsoleteDemoToken(sessionToken)) {
      throw const _ApiUnavailable('演示账号已失效，请重新登录');
    }
    if (firstParty && !useDemo && !_hasRealBase) {
      throw const _ApiUnavailable('请先配置正式服务地址');
    }

    final mergedHeaders = <String, dynamic>{
      ..._authHeaders(_storage),
      ...?headers,
    };
    mergedHeaders.removeWhere((key, value) {
      final name = key.toLowerCase();
      if (name == Headers.contentTypeHeader && data is FormData) return true;
      if (name == 'schoolid' && (!firstParty || accountRequest)) return true;
      if (!_credentialHeaders.contains(name)) return false;
      if (!firstParty || accountRequest) return true;
      final credential = value.toString().trim();
      return !useDemo &&
          (isGuestSessionToken(credential) ||
              _demoCredential.hasMatch(credential));
    });
    if (data is! FormData &&
        !mergedHeaders.keys.any(
          (key) => key.toLowerCase() == Headers.contentTypeHeader,
        )) {
      mergedHeaders[Headers.contentTypeHeader] = Headers.jsonContentType;
    }

    final bindsSession =
        firstParty &&
        !accountRequest &&
        sessionToken.isNotEmpty &&
        mergedHeaders.entries.any(
          (entry) =>
              _credentialHeaders.contains(entry.key.toLowerCase()) &&
              entry.value == sessionToken,
        );
    return Options(
      method: method,
      headers: mergedHeaders,
      followRedirects: !firstParty,
      sendTimeout: timeout,
      receiveTimeout: timeout,
      extra: {
        if (lightweightJson) extraLightweightJson: true,
        if (useDemo)
          DemoApiInterceptor.canDispatch: () =>
              !_disposed &&
              session.token == _storage.token &&
              session.generation ==
                  ApiUnauthorizedHandler.instance.sessionGeneration,
        if (bindsSession) 'bindsSession': true,
      },
    );
  }

  ApiResponse _toApiResponse(dynamic body) {
    if (body is Map<String, dynamic>) {
      return ApiResponse.fromJson(body);
    }
    // dio 默认会按响应的 Content-Type 解析：服务端如果给上传接口返
    // 回的是 `text/plain` / `text/html`（部分网关上传场景遇到），
    // dio 拿到的就是原始 JSON 字符串而不是 Map。这里再走一次 String
    // -> jsonDecode 兜底，保证 `{code, msg, data}` 这类标准响应不会
    // 因为 Content-Type 一栏的差异而被误判成"接口数据格式错误"。
    if (body is String) {
      final trimmed = body.trim();
      if (trimmed.isNotEmpty) {
        try {
          final decoded = decodeBigIntSafeJson(trimmed);
          if (decoded is Map<String, dynamic>) {
            return ApiResponse.fromJson(decoded);
          }
          if (decoded is Map) {
            return ApiResponse.fromJson(
              decoded.map((key, value) => MapEntry(key.toString(), value)),
            );
          }
        } catch (_) {
          debugPrint('[api] _toApiResponse: not JSON string');
        }
      }
    }
    if (body is Map) {
      return ApiResponse.fromJson(
        body.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    debugPrint(
      '[api] _toApiResponse: unsupported body type=${body.runtimeType}',
    );
    return ApiResponse.failure('接口数据格式错误');
  }

  /// 针对个别接口做返回数据的规范化。目前只处理 `/app/user/myInfo`：
  /// 后端有时会把 `headUrl` 写成相对路径（如 `app/upload/.../xxx.png`），
  /// 这里统一拼成完整 URL，避免上层每个消费方都去 import [MediaUrl]。
  /// 直接修改 `data['user']` 这个 Map 是安全的——它来自 dio 解析出的
  /// JSON，仅由本次响应使用，没有任何共享引用。
  ApiResponse _normalizeForPath(String path, ApiResponse response) {
    if (!response.isSuccess) {
      return response;
    }
    if (path == '/app/user/myInfo') {
      _normalizeMyInfoData(response.data);
    }
    return response;
  }

  void _normalizeMyInfoData(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return;
    }
    // 兼容两种返回形态：data.user.headUrl（标准）和 data.headUrl（兜底）。
    final user = data['user'];
    if (user is Map<String, dynamic>) {
      _resolveStringField(user, 'headUrl');
    }
    _resolveStringField(data, 'headUrl');
  }

  void _resolveStringField(Map<String, dynamic> map, String key) {
    final raw = map[key];
    if (raw is! String) {
      return;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return;
    }
    map[key] = MediaUrl.resolve(trimmed);
  }

  ApiResponse _finalizeResponse(
    RequestOptions request,
    ({String token, int generation}) session,
    ApiResponse response,
  ) {
    if (response.code != 401 ||
        request.extra['bindsSession'] != true ||
        request.uri.path == '/app/user/logout') {
      return response;
    }
    final toastMsg = response.msg.trim().isEmpty
        ? ApiUnauthorizedHandler.defaultMessage
        : response.msg;
    unawaited(
      ApiUnauthorizedHandler.instance.handle(
        storage: _storage,
        message: toastMsg,
        requestToken: session.token,
        requestGeneration: session.generation,
      ),
    );
    return ApiResponse.failure(toastMsg, code: 401);
  }

  ApiResponse _fromDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final parsed = ApiResponse.fromJson(data);
      if (parsed.code == 401) return parsed;
    }
    if (statusCode == 401) {
      return ApiResponse.failure(_extractDioMessage(error), code: 401);
    }
    return ApiResponse.failure(_extractDioMessage(error));
  }

  String _extractDioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['msg'] != null) {
      return data['msg'].toString();
    }
    if (data is Map && data['msg'] != null) {
      return data['msg'].toString();
    }
    if (error.message != null && error.message!.isNotEmpty) {
      return error.message!;
    }
    return '';
  }
}

class _ApiUnavailable implements Exception {
  const _ApiUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
