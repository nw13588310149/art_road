import 'package:flutter/material.dart';

import '../../features/ai_chat/ui/ai_chat_page.dart';
import '../../features/art_toolbox/ui/art_toolbox_page.dart';
import '../../features/artworks/ui/artworks_page.dart';
import '../../features/auth/ui/forget_password_page.dart';
import '../../features/auth/ui/login_page.dart';
import '../../features/auth/ui/register_page.dart';
import '../../features/common/ui/feature_default_pages.dart';
import '../../features/common/ui/legacy_placeholder_content.dart';
import '../../features/common/ui/terms_page.dart';
import '../../features/courseware/ui/courseware_page.dart';
import '../../features/circle/ui/circle_page.dart';
import '../../features/home/ui/home_page.dart';
import '../../features/help_guide/ui/help_guide_page.dart';
import '../../features/my_collection/ui/my_collection_page.dart'
    as my_collection;
import '../../features/my_notes/ui/my_notes_page.dart' as my_notes;
import '../../features/consultation/ui/consultation_detail_page.dart';
import '../../features/consultation/ui/consultation_page.dart';
import '../../features/personal_center/ui/info_page.dart';
import '../../features/personal_center/ui/personal_center_page.dart';
import '../../features/quiz_practice/ui/quiz_practice_page.dart';
import '../../features/quiz_practice/ui/quiz_session_page.dart';
import '../../features/school/ui/school_courseware_page.dart';
import '../../features/school/ui/school_quiz_practice_page.dart';
import '../../features/school/ui/school_video_tutorial_page.dart';
import '../../features/school_website/ui/school_website_page.dart';
import '../../features/shell/ui/shell_scaffold.dart';
import '../../features/feedback/ui/app_feedback_page.dart';
import '../../features/gallery/ui/gallery_page.dart';
import '../../features/smart_campus/ui/smart_campus_page.dart';
import '../../features/study_center/ui/study_center_page.dart';
import '../../features/video_tutorial/ui/video_tutorial_page.dart';
import 'route_paths.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name ?? RoutePaths.home;

    if (_isPublicRoute(routeName)) {
      return _buildPublicRoute(routeName, settings);
    }

    return _buildProtectedRoute(
      ShellScaffold(
        currentRoute: routeName,
        child: _buildProtectedContent(routeName),
      ),
      settings,
    );
  }

  /// 登录 / 注册 / 找回密码等无需登录态的认证页。
  static bool isAuthRoute(String routeName) {
    return routeName == RoutePaths.login ||
        routeName == RoutePaths.register ||
        routeName == RoutePaths.forget;
  }

  static bool _isPublicRoute(String routeName) {
    return isAuthRoute(routeName) || routeName == RoutePaths.xieyi2;
  }

  static Route<dynamic> _buildPublicRoute(
    String routeName,
    RouteSettings settings,
  ) {
    switch (routeName) {
      case RoutePaths.login:
        return _buildRoute(const LoginPage(), settings);
      case RoutePaths.register:
        return _buildRoute(const RegisterPage(), settings);
      case RoutePaths.forget:
        return _buildRoute(const ForgetPasswordPage(), settings);
      case RoutePaths.xieyi2:
        return _buildRoute(const TermsPage(), settings);
      default:
        return _buildRoute(const LoginPage(), settings);
    }
  }

  static Widget _buildProtectedContent(String routeName) {
    switch (routeName) {
      case RoutePaths.home:
        return const HomePage();
      case RoutePaths.personalAi:
        return const AiChatPage();
      case RoutePaths.studyCenter:
        return const StudyCenterPage();
      case RoutePaths.artworks:
        return const ArtworksPage();
      case RoutePaths.gallery:
        return const GalleryPage();
      case RoutePaths.artToolbox:
        return const ArtToolboxPage();
      case RoutePaths.school:
        return const SchoolCoursewareV2Page();
      case RoutePaths.circle:
        // 独立路由入口（首页 / 侧栏）：返回时 pop 回发起页面。
        // 智慧校园内部入口不走此路由，而是直接嵌入 CirclePage 并由
        // SmartCampusController.backToDashboard() 处理返回。
        return const CirclePage();
      case RoutePaths.courseware:
        return const MyCloudDrivePage();
      case RoutePaths.videoTutorial:
        return const VideoTutorialV2Page();
      case RoutePaths.smartCampus:
        return const SmartCampusPage();
      case RoutePaths.schoolWebsite:
        return const SchoolWebsitePage();
      case RoutePaths.myNotes:
        return const my_notes.MyNotesPage();
      case RoutePaths.myCollection:
        return const my_collection.MyCollectionPage();
      case RoutePaths.personalCenter:
        return const PersonalCenterPage();
      case RoutePaths.info:
        return const InfoPage();
      case RoutePaths.fankui:
      case RoutePaths.helpFeedback:
        return const AppFeedbackPage();
      case RoutePaths.helpGuide:
        return const HelpGuidePage();
      case RoutePaths.mock:
        return const MockExamDefaultPage();
      case RoutePaths.camp:
        return const QuizPracticePage();
      // 校园专属刷题 / 视频页（独立于公开资料，后续接入校园接口）。
      case RoutePaths.schoolCamp:
        return const SchoolQuizPracticePage();
      case RoutePaths.schoolVideo:
        return const SchoolVideoTutorialPage();
      // 刷题三级页：做题界面，由 /camp 入口跳入。
      case RoutePaths.campAnswer:
        return const QuizSessionPage();
      // 1.0 的 camp_over 路由：进入即弹出完成统计弹窗。
      case RoutePaths.campOver:
        return const QuizSessionPage(openCompletion: true);
      case RoutePaths.consultation:
        return const ConsultationPage();
      case RoutePaths.consultationDetail:
        return const ConsultationDetailPage();
      default:
        return LegacyPlaceholderContent(
          routeName: routeName,
          title: _legacyPageTitle(routeName),
        );
    }
  }

  static MaterialPageRoute<dynamic> _buildRoute(
    Widget page,
    RouteSettings settings,
  ) {
    return MaterialPageRoute<dynamic>(builder: (_) => page, settings: settings);
  }

  static PageRouteBuilder<dynamic> _buildProtectedRoute(
    Widget page,
    RouteSettings settings,
  ) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => page,
    );
  }

  static String _legacyPageTitle(String routeName) {
    const legacyRoutes = <String, String>{
      RoutePaths.smartCampusSignRecords: '签到记录',
      RoutePaths.smartCampusSignApprovals: '签到审批',
      RoutePaths.noteBg: '笔记背景',
      RoutePaths.detail: '课件详情',
      RoutePaths.detail2: '课件详情',
      RoutePaths.qrcode: '我的二维码',
      RoutePaths.chat: '班级聊天',
      RoutePaths.noteDetail: '笔记详情',
      RoutePaths.verifie: '实名认证',
      RoutePaths.set: '设置',
      RoutePaths.xieyi: '服务协议',
      RoutePaths.email: '邮箱绑定',
    };
    return legacyRoutes[routeName] ?? '待迁移页面';
  }
}
