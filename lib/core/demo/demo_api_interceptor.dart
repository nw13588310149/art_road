import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'demo_backend.dart';

/// 将客户端明确分配到本地演示的请求交给 [router]。
class DemoApiInterceptor extends Interceptor {
  DemoApiInterceptor({required this.router});

  static const canDispatch = 'canDispatchDemo';
  final DemoRouter router;
  final math.Random _random = math.Random();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final allowed = options.extra[canDispatch];
    if (allowed is! bool Function()) {
      handler.next(options);
      return;
    }
    final method = options.method.toUpperCase();
    final uri = options.uri;
    final path = uri.path.isEmpty ? '/' : uri.path;
    final match = router.match(method, path);

    await Future<void>.delayed(
      Duration(milliseconds: 120 + _random.nextInt(180)),
    );

    if (!allowed()) {
      handler.reject(_cancelled(options));
      return;
    }
    if (match == null) {
      DemoBackend.reportMissing(router.name, method, path);
      if (options.responseType == ResponseType.bytes) {
        handler.reject(_byteError(options, 404, '接口不存在'));
        return;
      }
      handler.resolve(
        _json(options, <String, dynamic>{'code': 0, 'msg': 'ok', 'data': null}),
      );
      return;
    }

    try {
      final request = await _buildRequest(options, method, path, match.params);
      if (!allowed()) {
        handler.reject(_cancelled(options));
        return;
      }
      final result = await match.handler(request);
      if (result is DemoBytes) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: result.bytes,
          ),
        );
        return;
      }
      if (options.responseType == ResponseType.bytes) {
        handler.reject(_byteError(options, 500, '接口未返回文件'));
        return;
      }
      handler.resolve(
        _json(options, <String, dynamic>{
          'code': 0,
          'msg': 'ok',
          'data': _jsonify(result),
        }),
      );
    } on DemoApiException catch (error) {
      if (options.responseType == ResponseType.bytes) {
        final expected = error.code >= 400 && error.code <= 599;
        handler.reject(
          _byteError(options, expected ? error.code : 500, error.message),
        );
        return;
      }
      handler.resolve(
        _json(options, <String, dynamic>{
          'code': error.code,
          'msg': error.message,
          'data': null,
        }),
      );
    } catch (_) {
      debugPrint('[demo] $method $path 处理失败');
      if (options.responseType == ResponseType.bytes) {
        handler.reject(_byteError(options, 500, '演示数据暂不可用'));
        return;
      }
      handler.resolve(
        _json(options, <String, dynamic>{
          'code': 500,
          'msg': '演示数据暂不可用',
          'data': null,
        }),
      );
    }
  }

  DioException _cancelled(RequestOptions options) =>
      DioException.requestCancelled(requestOptions: options, reason: '会话已切换');

  DioException _byteError(RequestOptions options, int status, String message) =>
      DioException.badResponse(
        statusCode: status,
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: status,
          data: {'code': status, 'msg': message, 'data': null},
        ),
      );

  Response<dynamic> _json(RequestOptions options, Map<String, dynamic> body) {
    return Response<dynamic>(
      requestOptions: options,
      statusCode: 200,
      data: body,
      headers: Headers.fromMap(<String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      }),
    );
  }

  Future<DemoRequest> _buildRequest(
    RequestOptions options,
    String method,
    String path,
    Map<String, String> params,
  ) async {
    final query = <String, dynamic>{
      ...options.uri.queryParameters,
      ...options.queryParameters,
    };
    final headers = <String, dynamic>{
      for (final entry in options.headers.entries)
        entry.key.toLowerCase(): entry.value,
    };
    Object? body = options.data;
    final files = <DemoUploadedFile>[];
    if (body is FormData) {
      final form = body;
      body = <String, dynamic>{
        for (final field in form.fields) field.key: field.value,
      };
      for (final entry in form.files) {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in entry.value.finalize()) {
          builder.add(chunk);
        }
        files.add(
          DemoUploadedFile(
            field: entry.key,
            fileName: entry.value.filename ?? 'file',
            bytes: builder.takeBytes(),
          ),
        );
      }
    } else if (body is String && body.trim().isNotEmpty) {
      try {
        body = jsonDecode(body);
      } catch (_) {
        // 非 JSON 文本体按原样交给处理函数。
      }
    }
    return DemoRequest(
      method: method,
      path: path,
      query: query,
      body: _jsonify(body),
      headers: headers,
      pathParams: params,
      files: files,
    );
  }

  /// 深拷贝成与 jsonDecode 同构的可变 Map / List，
  /// 避免业务代码修改响应时碰到 const 集合或泛型不匹配。
  static Object? _jsonify(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _jsonify(entry.value),
      };
    }
    if (value is Iterable) {
      return <dynamic>[for (final item in value) _jsonify(item)];
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value.toString();
  }
}
