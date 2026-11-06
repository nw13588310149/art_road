import 'package:flutter/material.dart';

import '../../features/auth/ui/forget_password_page.dart';
import '../../features/auth/ui/login_page.dart';
import '../../features/auth/ui/register_page.dart';
import '../../features/common/ui/feature_default_pages.dart';
import '../../features/common/ui/legacy_placeholder_content.dart';
import '../../features/common/ui/terms_page.dart';
import '../../features/courseware/ui/courseware_page.dart';
import '../../features/circle/ui/circle_page.dart';
import '../../features/dictation/ui/dictation_page.dart';
import '../../features/home/ui/home_page.dart';
import '../../features/help_guide/ui/help_guide_page.dart';
import '../../features/my_collection/ui/my_collection_page.dart'
    as my_collection;
import '../../features/my_notes/ui/my_notes_page.dart' as my_notes;
import '../../features/music_companion/ui/music_companion_page.dart';
import '../../features/music_play/ui/music_play_page.dart';
import '../../features/consultation/ui/consultation_detail_page.dart';
import '../../features/consultation/ui/consultation_page.dart';
import '../../features/personal_center/ui/info_page.dart';
import '../../features/personal_center/ui/personal_center_page.dart';
import '../../features/primary/ui/primary_pages.dart' as primary_pages;
import '../../features/quiz_practice/ui/quiz_practice_page.dart';
import '../../features/quiz_practice/ui/quiz_session_page.dart';
import '../../features/recording_system/ui/recording_system_page.dart'
    as recording_system;
import '../../features/school/ui/school_courseware_page.dart';
import '../../features/school/ui/school_quiz_practice_page.dart';
import '../../features/school/ui/school_video_tutorial_page.dart';
import '../../features/school_website/ui/school_website_page.dart';
import '../../features/shell/ui/shell_scaffold.dart';
import '../../features/feedback/ui/app_feedback_page.dart';
import '../../features/smart_campus/ui/smart_campus_page.dart';
import '../../features/smart_dictation/ui/smart_dictation_page.dart';
import '../../features/smart_sight_singing/ui/smart_sight_singing_catalog_page.dart';
import '../../features/smart_sight_singing/ui/smart_sight_singing_page.dart';
import '../../features/study_catalog/ui/study_catalog_page.dart';
import '../../features/theory/ui/theory_page.dart';
import '../../features/video_tutorial/ui/video_tutorial_page.dart';
import '../../features/voice/ui/voice_page.dart';
import 'route_paths.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name ?? RoutePaths.home;

    if (_isPublicRoute(routeName)) {
      return _buildPublicRoute(routeName, settings);
    }

    if (_isShelllessRoute(routeName)) {
      return _buildShelllessRoute(_buildShelllessContent(routeName), settings);
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

  /// 需登录但不在 Shell 侧栏/顶栏内展示的全屏页。
  static bool _isShelllessRoute(String routeName) {
    return false;
  }

  static Widget _buildShelllessContent(String routeName) {
    return LegacyPlaceholderContent(
      routeName: routeName,
      title: _legacyPageTitle(routeName),
    );
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
        return const primary_pages.PersonalAiPage();
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
      case RoutePaths.smartDictation:
        return const SmartDictationV2Page();
      case RoutePaths.smartSinging:
        return const SmartSightSingingCatalogPage();
      case RoutePaths.smartSightSinging:
        return const SmartSightSingingPage();
      case RoutePaths.music:
        return const MusicCompanionV2Page();
      case RoutePaths.smartCampus:
        return const SmartCampusPage();
      case RoutePaths.schoolWebsite:
        return const SchoolWebsitePage();
      case RoutePaths.myNotes:
        return const my_notes.MyNotesPage();
      case RoutePaths.recording:
        return const recording_system.RecordingSystemPage();
      case RoutePaths.myCollection:
        return const my_collection.MyCollectionPage();
      case RoutePaths.personalCenter:
        return const PersonalCenterPage();
      case RoutePaths.info:
        return const InfoPage();
      case RoutePaths.fankui:
        return const primary_pages.FeedbackPage();
      case RoutePaths.helpFeedback:
        return const AppFeedbackPage();
      case RoutePaths.helpGuide:
        return const HelpGuidePage();
      // ── 首页九宫格功能默认页 ─────────────────────────────────────
      case RoutePaths.dictation:
        return const DictationPage();
      case RoutePaths.sightSinging:
        return const SightSingingPage();
      case RoutePaths.musicTheory:
        return const MusicTheoryPage();
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
      case RoutePaths.answerQuestions:
        return const AnswerQuestionsPage();
      case RoutePaths.consultation:
        return const ConsultationPage();
      case RoutePaths.consultationDetail:
        return const ConsultationDetailPage();
      case RoutePaths.aiSong:
        return const StoreDefaultPage();
      case RoutePaths.voice:
        return const VoicePage();
      case RoutePaths.instrumental:
        return const InstrumentalPage();
      case RoutePaths.musicPlay:
        return const MusicPlayPage();
      case RoutePaths.answerEnd:
        return const TheoryPage();
      case RoutePaths.answerEnd2:
        return const MusicPlayPage();
      case RoutePaths.theory:
        return const TheoryPage();
      default:
        return LegacyPlaceholderContent(
          routeName: routeName,
          title: _legacyPageTitle(routeName),
        );
    }
  }

  static Route<dynamic> _buildShelllessRoute(
    Widget page,
    RouteSettings settings,
  ) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      opaque: true,
      fullscreenDialog: true,
      barrierColor: Colors.white,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => page,
    );
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
      RoutePaths.school: '校园课件',
      RoutePaths.music: '音乐伴侣',
      RoutePaths.courseware: '我的云盘',
      RoutePaths.videoTutorial: '视频中心',
      RoutePaths.smartDictation: '智能听写',
      RoutePaths.smartCampus: '智慧校园',
      RoutePaths.smartCampusSignRecords: '签到记录',
      RoutePaths.smartCampusSignApprovals: '签到审批',
      RoutePaths.smartSinging: '智能视唱',
      RoutePaths.smartSightSinging: '智能视唱',
      RoutePaths.myNotes: '我的笔记',
      RoutePaths.myCollection: '我的收藏',
      RoutePaths.personalCenter: '个人中心',
      RoutePaths.helpFeedback: '意见反馈',
      RoutePaths.helpGuide: '操作指南',
      RoutePaths.noteBg: '笔记背景',
      RoutePaths.answerQuestions: '答题入口',
      RoutePaths.camp: '闯关练习',
      RoutePaths.consultation: '学习资讯',
      RoutePaths.dictation: '听写练习',
      RoutePaths.mock: '模拟考试',
      RoutePaths.schoolWebsite: '微校',
      RoutePaths.musicTheory: '乐理练习',
      RoutePaths.sightSinging: '视唱练习',
      RoutePaths.store: '商城',
      RoutePaths.musicPlay: '乐谱播放',
      RoutePaths.recording: '录音系统',
      RoutePaths.voice: '声乐训练',
      RoutePaths.instrumental: '器乐训练',
      RoutePaths.theory: '乐理详情',
      RoutePaths.answer: '听写答题',
      RoutePaths.answer2: '听写答题2',
      RoutePaths.answer3: '听写答题3',
      RoutePaths.over: '听写结果',
      RoutePaths.detail: '课件详情',
      RoutePaths.detail2: '课件详情2',
      RoutePaths.info: '个人资料',
      RoutePaths.fankui: '意见反馈',
      RoutePaths.qrcode: '我的二维码',
      RoutePaths.campAnswer: '闯关作答',
      RoutePaths.campOver: '闯关结算',
      RoutePaths.chat: '班级聊天',
      RoutePaths.consultationDetail: '资讯详情',
      RoutePaths.noteDetail: '笔记详情',
      RoutePaths.answerEnd: '答题结束',
      RoutePaths.answerEnd2: '答题结束2',
      RoutePaths.verifie: '实名认证',
      RoutePaths.set: '设置',
      RoutePaths.xieyi: '服务协议',
      RoutePaths.personalAi: '小艺同学',
      RoutePaths.email: '邮箱绑定',
      RoutePaths.aiSong: 'AI 作歌',
      RoutePaths.circle: '校圈',
    };
    return legacyRoutes[routeName] ?? '待迁移页面';
  }
}
