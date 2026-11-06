import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/school_config_data.dart';
import '../data/school_repository.dart';

final schoolDormitoryCheckConfigProvider =
    FutureProvider<SchoolDormitoryCheckConfig>((ref) async {
      final response = await ref.watch(schoolRepositoryProvider).schoolConfigList();
      if (!response.isSuccess) {
        return SchoolDormitoryCheckConfig.empty;
      }
      return parseSchoolDormitoryCheckConfig(response.data);
    });
