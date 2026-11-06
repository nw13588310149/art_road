import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'help_guide_state.dart';

final helpGuideControllerProvider =
    NotifierProvider.autoDispose<HelpGuideController, HelpGuideState>(
      HelpGuideController.new,
    );

class HelpGuideController extends AutoDisposeNotifier<HelpGuideState> {
  @override
  HelpGuideState build() {
    return const HelpGuideState(
      selectedCategoryId: HelpGuideState.allCategoryId,
      categories: <HelpGuideCategory>[
        HelpGuideCategory(id: HelpGuideState.allCategoryId, label: '全部'),
        HelpGuideCategory(id: 'account', label: '如何开通账号'),
        HelpGuideCategory(id: 'campus', label: '配置智慧校园'),
        HelpGuideCategory(id: 'evaluation', label: '考评管理全流程'),
        HelpGuideCategory(id: 'principal', label: '校长及教务老师端'),
        HelpGuideCategory(id: 'headTeacher', label: '班主任端'),
        HelpGuideCategory(id: 'teacher', label: '任课老师端'),
        HelpGuideCategory(id: 'dormitory', label: '宿管端'),
      ],
      items: <HelpGuideItem>[
        HelpGuideItem(
          id: 'account-1',
          categoryId: 'account',
          title: '如何开通账号使用',
          subtitle: '开通账号',
        ),
        HelpGuideItem(
          id: 'campus-1',
          categoryId: 'campus',
          title: '如何配置智慧校园',
          subtitle: '智慧校园',
        ),
        HelpGuideItem(
          id: 'evaluation-1',
          categoryId: 'evaluation',
          title: '考评管理全流程',
          subtitle: '考评管理',
        ),
        HelpGuideItem(
          id: 'principal-1',
          categoryId: 'principal',
          title: '校长及教务老师端使用指南',
          subtitle: '校长及教务老师端',
        ),
        HelpGuideItem(
          id: 'head-teacher-1',
          categoryId: 'headTeacher',
          title: '班主任端使用指南',
          subtitle: '班主任端',
        ),
        HelpGuideItem(
          id: 'teacher-1',
          categoryId: 'teacher',
          title: '任课老师端使用指南',
          subtitle: '任课老师端',
        ),
        HelpGuideItem(
          id: 'dormitory-1',
          categoryId: 'dormitory',
          title: '宿管端使用指南',
          subtitle: '宿管端',
        ),
        HelpGuideItem(
          id: 'account-2',
          categoryId: 'account',
          title: '账号登录与安全设置',
          subtitle: '开通账号',
        ),
        HelpGuideItem(
          id: 'campus-2',
          categoryId: 'campus',
          title: '校园资料与班级配置',
          subtitle: '智慧校园',
        ),
      ],
    );
  }

  void selectCategory(String categoryId) {
    if (categoryId == state.selectedCategoryId) return;
    if (!state.categories.any((category) => category.id == categoryId)) return;
    state = state.copyWith(selectedCategoryId: categoryId);
  }
}
