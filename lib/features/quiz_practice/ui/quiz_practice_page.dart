import 'package:flutter/material.dart';

import '../state/quiz_practice_state.dart';
import 'quiz_practice_view.dart';

/// 公开题库：首页「题库」入口。
class QuizPracticePage extends StatelessWidget {
  const QuizPracticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const QuizPracticeView(
      schoolId: kPublicQuizSchoolId,
      subtitle: '美术常识与美术史练习，做错的题会自动收进错题本',
      showPictureQuiz: true,
    );
  }
}
