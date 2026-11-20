import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_config.dart';
import 'package:the_road_of_art_flutter/core/network/api_client.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/features/courseware/data/cloud_drive_repository.dart';

const _upload = '/app/common/v2/fileUpload';
const _legacyUpload = '/app/user/fileUpload';
const _testOrigin = 'https://art-road.example.test';
const _token = 'offline-test-token';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    '正式模式下平台、阅卷和云盘走同一个配置地址，并使用各自的认证头',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = AppStorage(await SharedPreferences.getInstance());
      await storage.saveToken(_token);
      await storage.saveSchoolId('501');
      final client = _OfflineHttpClient();

      await HttpOverrides.runZoned(() async {
        final providers = ProviderContainer(
          overrides: [appStorageProvider.overrideWithValue(storage)],
        );
        try {
          final platform = providers.read(apiClientProvider);
          final marking = providers.read(markingApiClientProvider);
          final drive = providers.read(cloudDriveRepositoryProvider);
          expect((await platform.get('/app/user/myInfo')).isSuccess, isTrue);
          expect((await marking.get('/app/artworks')).isSuccess, isTrue);
          expect((await drive.getCoursewareUsage()).isSuccess, isTrue);
          final upload = await drive.uploadFile(
            bytes: Uint8List(1),
            filename: '素描.png',
          );
          expect(upload.isSuccess, isTrue);
        } finally {
          providers.dispose();
        }
      }, createHttpClient: (_) => client);

      expect(client.requests.map((r) => '${r.method} ${r.uri}'), [
        'GET $_testOrigin/app/user/myInfo',
        'GET $_testOrigin/app/artworks',
        'POST $_testOrigin/app/courseware/v2/usage',
        'POST $_testOrigin$_upload',
      ]);
      expect(
        client.requests.map((r) => r.headers.values['app-token']),
        everyElement([_token]),
      );
      expect(client.requests.map((r) => r.headers.values['school-token']), [
        null,
        [_token],
        null,
        null,
      ]);
      expect(client.requests.map((r) => r.headers.values['schoolid']), [
        ['501'],
        null,
        ['501'],
        ['501'],
      ]);
      expect(
        client.requests.last.headers.values['content-type']?.single,
        startsWith('multipart/form-data;'),
      );
    },
    skip: kDemoMode
        ? '用 DEMO_MODE=false 和 ART_ROAD_API_BASE_URL=https://art-road.example.test/ 运行正式模式测试'
        : false,
  );

  test('只有接口不存在才回退，备用端点使用新的上传表单', () async {
    final client = _UploadClient([
      const ApiResponse(code: 404, msg: '接口不存在'),
      const ApiResponse(code: 0, msg: 'ok'),
    ]);
    final result = await _send(client);
    expect(result.isSuccess, isTrue);
    expect(client.paths, [_upload, _legacyUpload]);
    expect(identical(client.forms.first, client.forms.last), isFalse);
    expect(
      client.forms.map((form) => form.files.single.key),
      everyElement('file'),
    );
  });

  for (final response in [
    const ApiResponse(code: 400, msg: '文件格式不支持'),
    const ApiResponse(code: 403, msg: '没有权限'),
    const ApiResponse(code: 429, msg: '今日上传额度已用完'),
    const ApiResponse(code: 404, msg: '文件不存在'),
    const ApiResponse(code: 503, msg: '服务暂不可用'),
    const ApiResponse(code: -1, msg: '网络异常'),
  ]) {
    test('保留上传错误 ${response.code} ${response.msg}，不重复提交', () async {
      final client = _UploadClient([response]);
      final result = await _send(client);
      expect(result, same(response));
      expect(client.paths, [_upload]);
    });
  }
}

Future<ApiResponse> _send(ApiClient client) => CloudDriveRepository(
  client: client,
).uploadFile(bytes: Uint8List(1), filename: '素描.png');

class _UploadClient extends Fake implements ApiClient {
  _UploadClient(this.responses);

  final List<ApiResponse> responses;
  final paths = <String>[];
  final forms = <FormData>[];

  @override
  Future<ApiResponse> postFormData(
    String path, {
    required FormData data,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    Duration? timeout,
  }) async {
    paths.add(path);
    forms.add(data);
    return responses[paths.length - 1];
  }
}

class _OfflineHttpClient extends Fake implements HttpClient {
  final requests = <_OfflineRequest>[];

  @override
  bool autoUncompress = true;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = _OfflineRequest(method, url);
    requests.add(request);
    return request;
  }
}

class _OfflineRequest extends Fake implements HttpClientRequest {
  _OfflineRequest(this.method, this.uri);

  @override
  final String method;
  @override
  final Uri uri;
  @override
  final _OfflineHeaders headers = _OfflineHeaders();
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<HttpClientResponse> close() async => _OfflineResponse();
}

class _OfflineResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  final _OfflineHeaders headers = _OfflineHeaders()
    ..set('content-type', 'application/json');
  @override
  int get statusCode => 200;
  @override
  String get reasonPhrase => 'OK';
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(
        Uint8List.fromList(utf8.encode('{"code":0,"msg":"ok","data":{}}')),
      ).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OfflineHeaders extends Fake implements HttpHeaders {
  final values = <String, List<String>>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name.toLowerCase()] = [value.toString()];
  }

  @override
  void forEach(void Function(String name, List<String> values) action) =>
      values.forEach(action);
}
