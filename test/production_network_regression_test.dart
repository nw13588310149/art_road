import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/network/api_client.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/core/network/api_unauthorized_handler.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/features/courseware/data/cloud_drive_repository.dart';

const _upload = '/app/common/v2/fileUpload';
const _legacyUpload = '/app/user/fileUpload';
const _configuredBase = String.fromEnvironment('ART_ROAD_API_BASE_URL');
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

      final origin = Uri.parse(_configuredBase).origin;
      expect(client.requests.map((r) => '${r.method} ${r.uri}'), [
        'GET $origin/app/user/myInfo',
        'GET $origin/app/artworks',
        'POST $origin/app/courseware/v2/usage',
        'POST $origin$_upload',
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
    skip: _configuredBase.isEmpty
        ? '用 DEMO_MODE=false 和 ART_ROAD_API_BASE_URL=https://art-road.example.test/ 运行正式模式测试'
        : false,
  );

  test('同一客户端按账号及会话切换传输，旧会话 401 不影响新账号', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = AppStorage(await SharedPreferences.getInstance());
    final localStarted = Completer<void>();
    final localFinish = Completer<void>();
    final realStarted = Completer<void>();
    final realFinish = Completer<_OfflineResponse>();
    final who = DemoAccounts.headTeacher;
    final detectedLocal = <String>[];
    final router = DemoRouter('mixed')
      ..post('/app/user/mobileLogin', (request) {
        detectedLocal.add('login');
        expect(request.token, '');
        expect(request.str('mobile'), who.mobile);
        return {'token': who.token};
      })
      ..post('/app/user/sendSmsCode', (request) {
        detectedLocal.add('sms');
        expect(request.token, '');
        return true;
      })
      ..get('/profile', (request) => request.account.role.name)
      ..get('/exam', (request) {
        expect(request.headers['app-token'], who.token);
        expect(request.headers['school-token'], who.token);
        expect(request.headers['schoolid'], isNull);
        return '演示考试';
      })
      ..get('/export', (_) => DemoBytes(Uint8List.fromList([11, 12])))
      ..post(_upload, (request) => request.files.single.bytes.length)
      ..get('/local-late', (_) async {
        localStarted.complete();
        await localFinish.future;
        throw const DemoApiException('旧演示会话已失效', code: 401);
      });
    final wire = _OfflineHttpClient((request) async {
      switch (request.uri.path) {
        case '/real-late':
          realStarted.complete();
          return realFinish.future;
        case '/app/user/mobileLogin':
          return _OfflineResponse(body: '{"code":400,"msg":"账号或密码错误"}');
        case '/export':
        case '/public-file':
          return _OfflineResponse(body: 'bytes');
        default:
          return _OfflineResponse();
      }
    });

    await HttpOverrides.runZoned(() async {
      final platform = ApiClient(
        storage: storage,
        baseUrl: 'https://art-road.example.test/',
        demoRouter: router,
      );
      final marking = ApiClient(
        storage: storage,
        baseUrl: 'https://marking.example.test/',
        demoRouter: router,
        authHeaders: (s) => {'app-token': s.token, 'school-token': s.token},
      );
      final unconfigured = ApiClient(
        storage: storage,
        baseUrl: '',
        demoRouter: router,
      );
      expect((await unconfigured.get('/profile')).msg, '请先配置正式服务地址');
      const login = '/app/user/mobileLogin';
      expect(
        (await unconfigured.post(login, data: {'mobile': who.mobile})).data,
        {'token': who.token},
      );
      expect(
        (await platform.post(
          '/app/user/sendSmsCode',
          data: {'mobile': who.mobile},
        )).isSuccess,
        isTrue,
      );
      expect(wire.requests, isEmpty);
      ApiUnauthorizedHandler.instance.reset();
      await storage.saveToken(who.token);
      expect((await platform.get('/profile')).data, who.role.name);
      expect((await marking.get('/exam')).data, '演示考试');
      expect(
        (await platform.postFormData(
          _upload,
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes([21, 22], filename: '素描.png'),
          }),
        )).data,
        2,
      );
      expect(await platform.getBytes('/export'), [11, 12]);
      expect(wire.requests, isEmpty);
      expect(
        await platform.getBytes(
          'https://media.example.test/public-file',
          headers: {
            'App-Token': who.token,
            'school-token': who.token,
            'Authorization': 'Bearer ${who.token}',
          },
        ),
        utf8.encode('bytes'),
      );
      expect(
        wire.requests.single.headers.values.keys,
        isNot(
          contains(
            anyOf('app-token', 'school-token', 'authorization', 'schoolid'),
          ),
        ),
      );

      final rejected = await platform.post(
        login,
        data: {'mobile': '13900000000'},
      );
      expect(rejected.code, 400);
      expect(wire.requests.last.headers.values['app-token'], isNull);
      expect(detectedLocal, ['login', 'sms']);

      final staleLocal = platform.get('/local-late');
      await localStarted.future;
      ApiUnauthorizedHandler.instance.reset();
      await storage.saveToken(_token);
      await storage.saveSchoolId('502');
      localFinish.complete();
      expect((await staleLocal).code, 401);
      expect(storage.token, _token);
      expect(storage.schoolId, '502');
      expect((await platform.get('/profile')).isSuccess, isTrue);
      expect(wire.requests.last.headers.values['app-token'], [_token]);
      expect(wire.requests.last.headers.values['schoolid'], ['502']);
      expect((await marking.get('/exam')).isSuccess, isTrue);
      expect(wire.requests.last.uri.host, 'marking.example.test');
      expect(wire.requests.last.headers.values['school-token'], [_token]);
      expect(await platform.getBytes('/export'), utf8.encode('bytes'));

      final staleReal = platform.get('/real-late');
      await realStarted.future;
      ApiUnauthorizedHandler.instance.reset();
      await storage.saveToken(who.token);
      await storage.saveSchoolId('503');
      realFinish.complete(
        _OfflineResponse(statusCode: 401, body: '{"code":401,"msg":"已失效"}'),
      );
      expect((await staleReal).code, 401);
      expect(storage.token, who.token);
      expect(storage.schoolId, '503');
      platform.dispose();
      final count = wire.requests.length;
      expect((await platform.get('/profile')).msg, '请求已取消，请重试');
      expect(wire.requests.length, count);
      await storage.saveToken('demo.unknown.13900000000');
      expect((await marking.get('/exam')).msg, '演示账号已失效，请重新登录');
      expect(wire.requests.length, count);
    }, createHttpClient: (_) => wire);
    expect(
      wire.requests.every(
        (request) => request.headers.values.values
            .expand((v) => v)
            .every((value) => !value.contains(who.token)),
      ),
      isTrue,
    );
  });

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
  _OfflineHttpClient([this.respond]);

  final Future<_OfflineResponse> Function(_OfflineRequest)? respond;
  final requests = <_OfflineRequest>[];

  @override
  bool autoUncompress = true;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  Duration? connectionTimeout;

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = _OfflineRequest(method, url, respond);
    requests.add(request);
    return request;
  }
}

class _OfflineRequest extends Fake implements HttpClientRequest {
  _OfflineRequest(this.method, this.uri, this.respond);

  final Future<_OfflineResponse> Function(_OfflineRequest)? respond;

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
  Future<HttpClientResponse> close() async =>
      respond?.call(this) ?? _OfflineResponse();
}

class _OfflineResponse extends Stream<List<int>> implements HttpClientResponse {
  _OfflineResponse({
    this.statusCode = 200,
    this.body = '{"code":0,"msg":"ok","data":{}}',
  });

  final String body;
  @override
  final _OfflineHeaders headers = _OfflineHeaders()
    ..set('content-type', 'application/json');
  @override
  final int statusCode;
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
  }) => Stream<List<int>>.value(Uint8List.fromList(utf8.encode(body))).listen(
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
