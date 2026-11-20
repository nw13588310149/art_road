import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;

HttpClientAdapter protectRedirects(HttpClientAdapter adapter) =>
    _RedirectGuardAdapter(adapter);

/// XMLHttpRequest ignores followRedirects. Fetch can reject a redirect before
/// forwarding application token headers or an account endpoint body.
class _RedirectGuardAdapter implements HttpClientAdapter {
  _RedirectGuardAdapter(this._delegate);

  final HttpClientAdapter _delegate;
  final _active = <web.AbortController>{};
  bool _closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.followRedirects) {
      return _delegate.fetch(options, requestStream, cancelFuture);
    }
    if (_closed) throw _cancelled(options);
    final controller = web.AbortController();
    _active.add(controller);
    unawaited(cancelFuture?.then((_) => controller.abort()));
    try {
      final body = requestStream == null
          ? null
          : await _readBody(requestStream);
      if (controller.signal.aborted) throw _cancelled(options);
      final headers = web.Headers();
      for (final entry in options.headers.entries) {
        if (entry.key.toLowerCase() == 'content-length' || entry.value == null) {
          continue;
        }
        final value = entry.value;
        headers.set(
          entry.key,
          value is Iterable ? value.join(', ') : value.toString(),
        );
      }
      final beforeResponse =
          options.sendTimeout ??
          (body == null ? options.connectTimeout : options.receiveTimeout);
      final response = await _limit(
        web.window
            .fetch(
              options.uri.toString().toJS,
              web.RequestInit(
                method: options.method,
                headers: headers,
                body: body?.toJS,
                redirect: 'error',
                credentials: 'omit',
                signal: controller.signal,
              ),
            )
            .toDart,
        beforeResponse,
        controller,
        (timeout) => body == null
            ? DioException.connectionTimeout(
                requestOptions: options,
                timeout: timeout,
              )
            : DioException.sendTimeout(
                requestOptions: options,
                timeout: timeout,
              ),
      );
      if (body != null && response.ok) {
        options.onSendProgress?.call(body.length, body.length);
      }
      final bytes = await _limit(
        response.arrayBuffer().toDart,
        options.receiveTimeout,
        controller,
        (timeout) => DioException.receiveTimeout(
          requestOptions: options,
          timeout: timeout,
        ),
      );
      final responseHeaders = <String, List<String>>{};
      _HeadersIterator(response.headers).forEach(
        ((JSString value, JSString key) {
          responseHeaders[key.toDart] = [value.toDart];
        }).toJS,
      );
      return ResponseBody.fromBytes(
        bytes.toDart.asUint8List(),
        response.status,
        statusMessage: response.statusText,
        headers: responseHeaders,
      );
    } on DioException {
      rethrow;
    } catch (_) {
      if (controller.signal.aborted) throw _cancelled(options);
      throw DioException.connectionError(
        requestOptions: options,
        reason: '无法连接服务或请求发生重定向',
      );
    } finally {
      _active.remove(controller);
    }
  }

  @override
  void close({bool force = false}) {
    _closed = true;
    if (force) {
      for (final controller in _active) {
        controller.abort();
      }
    }
    _delegate.close(force: force);
  }

  static Future<T> _limit<T>(
    Future<T> future,
    Duration? timeout,
    web.AbortController controller,
    DioException Function(Duration) error,
  ) => timeout == null || timeout <= Duration.zero
      ? future
      : future.timeout(
          timeout,
          onTimeout: () {
            controller.abort();
            throw error(timeout);
          },
        );

  static Future<Uint8List> _readBody(Stream<Uint8List> stream) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  static DioException _cancelled(RequestOptions options) =>
      DioException.requestCancelled(requestOptions: options, reason: '请求已取消');
}

extension type _HeadersIterator(JSObject _) implements JSObject {
  external void forEach(JSFunction callback);
}
