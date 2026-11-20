import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:the_road_of_art_flutter/core/network/secure_redirect_adapter.dart';
import 'package:web/web.dart' as web;

Future<void> main() async {
  final dio = Dio(
    BaseOptions(
      baseUrl: web.window.location.origin,
      followRedirects: false,
      headers: {'App-Token': 'local-test-token', 'schoolId': '501'},
    ),
  );
  dio.httpClientAdapter = protectRedirects(dio.httpClientAdapter);
  String result = 'ok';
  try {
    try {
      await dio.post('/redirect', data: {'password': 'local-test-password'});
      throw StateError('redirect was accepted');
    } on DioException {
      // Browser Fetch errors before contacting the redirect target.
    }
    final progress = <(int, int)>[];
    final uploaded = await dio.post(
      '/upload',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes([1, 2, 3], filename: 'study.png'),
      }),
      onSendProgress: (sent, total) => progress.add((sent, total)),
    );
    final data = uploaded.data as Map;
    if (data['multipart'] != true ||
        data['token'] != true ||
        data['school'] != true ||
        progress.length != 1 ||
        progress.single.$1 != progress.single.$2) {
      throw StateError('multipart request or upload notification mismatch');
    }
    final bytes = await dio.get<Uint8List>(
      '/file',
      options: Options(responseType: ResponseType.bytes),
    );
    if (bytes.data?.join(',') != '4,5,6') throw StateError('binary mismatch');
    try {
      await dio.get(
        '/slow',
        options: Options(receiveTimeout: const Duration(milliseconds: 50)),
      );
      throw StateError('download timed out but succeeded');
    } on DioException catch (error) {
      if (error.type != DioExceptionType.receiveTimeout) rethrow;
    }
    final pending = dio.get('/slow');
    Future<void>.delayed(
      const Duration(milliseconds: 30),
      () => dio.close(force: true),
    );
    try {
      await pending;
      throw StateError('disposed request succeeded');
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error)) rethrow;
    }
  } catch (error) {
    result = error.toString();
  }
  await web.window
      .fetch('/result'.toJS, web.RequestInit(method: 'POST', body: result.toJS))
      .toDart;
}
