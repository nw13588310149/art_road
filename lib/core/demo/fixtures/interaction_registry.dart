import '../demo_backend.dart';
import 'interaction_ai_chat.dart';
import 'interaction_circle.dart';
import 'interaction_personal.dart';
import 'interaction_quiz.dart';

/// 互动类模块的演示接口：小美同学、校圈、美术常识刷题、个人中心。
void registerInteractionFixtures(DemoRouter platform) {
  registerAiChatFixtures(platform);
  registerCircleFixtures(platform);
  registerQuizFixtures(platform);
  registerPersonalCenterFixtures(platform);
}
