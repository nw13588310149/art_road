import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/snowflake_id.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';
import '../../school/data/school_repository.dart';

final schoolWebsiteRepositoryProvider = Provider<SchoolWebsiteRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final storage = ref.watch(appStorageProvider);
  final schoolRepository = ref.watch(schoolRepositoryProvider);
  return SchoolWebsiteRepository(
    client: client,
    storage: storage,
    schoolRepository: schoolRepository,
  );
});

class SchoolWebsiteRepository {
  SchoolWebsiteRepository({
    required this.client,
    required this.storage,
    required this.schoolRepository,
  });

  final ApiClient client;
  final AppStorage storage;
  final SchoolRepository schoolRepository;

  /// 校园官网首页 HTML：`POST /app/school/v2/user/homePage`
  ///
  /// `schoolId` 为 19 位雪花 id，Web 端 JS Number 无法精确表示，直接以
  /// **带引号的字符串** 形态发送（`{"schoolId":"2066…201"}`）。先从
  /// `/app/school/v2/user/schoolList` 取最新 id 字符串，避免本地缓存里
  /// 可能已精度受损的旧值。
  Future<ApiResponse> getHomePage() async {
    final sid = await _resolveSchoolId();
    if (sid == null || sid == '0') {
      return ApiResponse.failure('未绑定学校');
    }
    return client.post(
      '/app/school/v2/user/homePage',
      data: <String, dynamic>{'schoolId': sid},
    );
  }

  /// 优先从 schoolList 接口取 id（响应侧已做雪花 id 字符串化），
  /// 避免使用本地 SharedPreferences 里可能已精度受损的旧值。
  Future<String?> _resolveSchoolId() async {
    final schoolResponse = await schoolRepository.getSchoolInfo();
    if (schoolResponse.isSuccess) {
      final fromApi = _readFirstSchoolId(schoolResponse.data);
      if (fromApi != null && fromApi != '0') {
        return fromApi;
      }
    }

    final stored = readSnowflakeId(storage.schoolId);
    if (stored != null && stored != '0') {
      return stored;
    }
    return null;
  }

  static String? _readFirstSchoolId(dynamic data) {
    Map? school;
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map) {
        school = first;
      }
    } else if (data is Map) {
      school = data;
    }
    return readSnowflakeId(school?['id']);
  }
}
