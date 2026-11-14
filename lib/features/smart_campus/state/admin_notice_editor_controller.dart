import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_repository.dart';

final adminNoticeEditorProvider =
    StateNotifierProvider.autoDispose<AdminNoticeEditorController, bool>(
      (ref) => AdminNoticeEditorController(ref.watch(adminRepositoryProvider)),
    );

class AdminNoticeEditorController extends StateNotifier<bool> {
  AdminNoticeEditorController(this.repository) : super(false);
  final AdminRepository repository;
  Future<String?> save(Map<String, dynamic> body) async {
    if (state) return '正在保存，请稍候';
    state = true;
    try {
      final response = await repository.noticeSave(body);
      return response.isSuccess
          ? null
          : response.displayMsg.isEmpty
          ? '保存失败，请稍后重试'
          : response.displayMsg;
    } catch (_) {
      return '保存失败，请检查网络后重试';
    } finally {
      if (mounted) state = false;
    }
  }
}
