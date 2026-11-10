import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// 服务协议与隐私政策（登录 / 注册页打开的公开页面）。
///
/// 路由参数传 [TermsPage.privacyAnchor] 时直接定位到隐私政策；
/// 底部「我已阅读并同意」返回 `true`，左上角返回为 `false`。
class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  /// 路由参数：打开后定位到《隐私政策》。
  static const privacyAnchor = 'privacy';

  @override
  Widget build(BuildContext context) {
    final anchor = ModalRoute.of(context)?.settings.arguments;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: TermsContent(
          initialAnchor: anchor is String ? anchor : null,
          onBack: () => Navigator.of(context).pop(false),
          onAgree: () => Navigator.of(context).pop(true),
        ),
      ),
    );
  }
}

/// 协议正文 + 页头，可嵌在外壳内（不带同意按钮）或公开页面里使用。
class TermsContent extends StatefulWidget {
  const TermsContent({
    this.onBack,
    this.onAgree,
    this.initialAnchor,
    super.key,
  });

  final VoidCallback? onBack;

  /// 为空时不显示底部「我已阅读并同意」操作栏。
  final VoidCallback? onAgree;
  final String? initialAnchor;

  @override
  State<TermsContent> createState() => _TermsContentState();
}

class _TermsContentState extends State<TermsContent> {
  final _privacyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialAnchor == TermsPage.privacyAnchor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _privacyKey.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(target, duration: Duration.zero);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final onAgree = widget.onAgree;
    return AppCard(
      padding: EdgeInsets.zero,
      bordered: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(
            title: '服务协议与隐私政策',
            subtitle: '更新日期 2026-11-01 · 生效日期 2026-11-01',
            onBack: widget.onBack,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final section in _sections)
                    _TermsSectionView(
                      key: section.anchor == TermsPage.privacyAnchor
                          ? _privacyKey
                          : null,
                      section: section,
                    ),
                ],
              ),
            ),
          ),
          if (onAgree != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s16,
                AppSpace.s8,
                AppSpace.s16,
                AppSpace.s20,
              ),
              child: Center(
                child: SizedBox(
                  width: 230,
                  child: AppButton(
                    label: '我已阅读并同意',
                    onTap: onAgree,
                    expand: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TermsSection {
  const _TermsSection(
    this.title,
    this.paragraphs, {
    this.major = false,
    this.anchor,
  });

  final String title;
  final List<String> paragraphs;

  /// 协议 / 政策的大标题。
  final bool major;
  final String? anchor;
}

class _TermsSectionView extends StatelessWidget {
  const _TermsSectionView({required this.section, super.key});

  final _TermsSection section;

  static final _paragraphStyle = AppText.body14.copyWith(
    height: 1.7,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: section.major ? AppSpace.s8 : 0,
        bottom: AppSpace.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: section.major ? AppText.title20 : AppText.title16,
          ),
          const SizedBox(height: AppSpace.s8),
          for (final paragraph in section.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s8),
              child: Text(paragraph, style: _paragraphStyle),
            ),
        ],
      ),
    );
  }
}

const _operator = '艺考网';

const _sections = <_TermsSection>[
  _TermsSection('绘画星球服务协议', [
    '欢迎使用「绘画星球」（以下简称「本应用」）。本应用由$_operator（以下简称「我们」）开发和运营，'
        '面向美术艺考学生、画室教师及教学管理人员，提供学情查询、作品点评、范画学习、画室工具、视频课程、'
        '智慧校园和美术答疑助手「小美同学」等服务。',
    '请您在注册、登录或使用本应用前，仔细阅读并充分理解本协议与隐私政策的全部内容。您勾选同意或实际使用本应用，'
        '即视为您已阅读并同意受其约束。若您未满 18 周岁，请在监护人陪同下阅读，并在取得监护人同意后使用。',
  ], major: true),
  _TermsSection('一、服务内容', [
    '1. 学情服务：查看所在画室组织的月考、阶段考的各科成绩、档位、排名、原卷、评分标准与成长曲线。',
    '2. 作品服务：上传日常作品照片，由任课老师在线点评、评分并归档；在校圈中分享作品与画室动态。',
    '3. 学习服务：范画库、画室工具箱、视频中心、美术常识题库、笔记与收藏等学习功能。',
    '4. 智慧校园：课表、考勤签到、宿舍、班级群聊与通知等管理功能，具体以您所在画室开通的服务为准。',
    '5. 美术答疑助手「小美同学」：美术常识问答，回答仅供参考。',
  ]),
  _TermsSection('二、账号注册与使用', [
    '1. 您应使用本人手机号注册，或使用画室分配的账号登录，所填写的姓名、所在画室、身份等信息应真实、准确。',
    '2. 学生、任课老师、班主任、宿管、管理员等身份由所在画室统一配置，不同身份可使用的功能和可查看的数据范围不同。',
    '3. 请妥善保管账号和密码，不得出借、转让或与他人共用；发现账号被盗用时，请及时联系我们或所在画室处理。',
  ]),
  _TermsSection('三、作品与内容', [
    '1. 您上传的作品照片、文字、图片、视频等内容，著作权归您或原作者所有。',
    '2. 为向您提供存储、展示、点评、统计及备份服务，您授予我们在服务范围内非独占、免费的使用许可。'
        '该许可仅用于向您本人及您所在画室的老师、同学展示；如需将作品用于宣传推广，我们将另行征得您的同意。',
    '3. 发布到校圈的内容对您所在画室的成员可见。请勿上传抄袭他人的作品，不得冒用他人作品参与点评或排名，'
        '不得发布违法违规或侵犯他人合法权益的内容。',
    '4. 范画库中的作品仅供学习临摹，未经权利人许可，不得复制、传播或用于商业用途。',
  ]),
  _TermsSection('四、考试原卷与成绩数据', [
    '1. 原卷（考试答卷的扫描件或照片）及各科分数、档位、评语和排名，由您所在画室在阅卷系统中采集、评阅后同步至本应用。',
    '2. 学生本人可以查看自己的原卷与成绩；画室授权的任课老师、班主任和管理人员可以在其管理范围内查看；'
        '排名、均分等统计数据仅在画室内部展示。',
    '3. 成绩以所在画室最终公布的结果为准。如对分数有疑问，请联系任课老师或教务老师申请复核，我们会配合画室核查数据同步问题。',
    '4. 原卷与成绩数据仅用于教学评估和学情分析。未经您或监护人同意，我们不会向画室以外的第三方提供可识别到个人的原卷和成绩。',
  ]),
  _TermsSection('五、会员服务', [
    '1. 部分功能（如范画高清原图等）需要开通会员后使用，具体权益、开通方式与价格以正式页面为准。',
    '2. 会员兑换码需在有效期内兑换，兑换成功后不予退换，法律法规另有规定的除外。',
  ]),
  _TermsSection('六、小美同学使用说明', [
    '小美同学的回答由模型生成，仅供学习参考，不代表任课老师或阅卷老师的专业评价，也不构成考试结果或录取承诺。'
        '请勿在对话中输入身份证号、家庭住址等敏感个人信息。',
  ]),
  _TermsSection('七、行为规范', [
    '您应遵守法律法规和社会公序良俗，不得发布违法违规、低俗、广告或侵犯他人隐私的内容；不得干扰本应用的正常运行，'
        '不得批量抓取数据，不得对本应用进行反向工程、反编译或以其他方式尝试获取源代码。',
  ]),
  _TermsSection('八、协议的变更与终止', [
    '我们可能因业务调整或法律法规变化更新本协议，更新后将在应用内显著位置提示。您注销账号或严重违反本协议时，'
        '我们可以终止向您提供服务，并依法处理相关数据。',
  ]),
  _TermsSection(
    '绘画星球隐私政策',
    [
      '我们重视您的个人信息与隐私保护，遵循合法、正当、必要和诚信的原则处理个人信息。以下说明我们如何收集、使用、共享、'
          '存储和保护您的信息，以及您享有的权利。',
    ],
    major: true,
    anchor: TermsPage.privacyAnchor,
  ),
  _TermsSection('一、我们收集的信息', [
    '1. 账号信息：手机号、姓名或昵称、头像、性别、出生日期、所在地区、就读画室、专业方向和目标院校。',
    '2. 学习数据：您上传的作品照片及老师点评，考试原卷图片，各科成绩、档位、评语与排名，题库练习记录、笔记、收藏，'
        '以及您与小美同学的对话内容。',
    '3. 校园数据：在您所在画室开通智慧校园时，包括班级、课表、考勤签到记录和宿舍分配等。考勤签到如需使用位置或人脸信息，'
        '我们会另行取得您或监护人的单独同意。',
    '4. 设备信息：设备型号、操作系统版本、网络状态和消息推送标识，用于保障服务稳定和发送消息通知。',
    '5. 系统权限：相机和相册仅在您拍摄或选择作品、头像时调用；麦克风仅在您发送语音消息时调用；位置仅在考勤签到时调用。'
        '您可以随时在系统设置中关闭相关权限。',
  ]),
  _TermsSection('二、信息的使用', [
    '1. 提供成绩查询、原卷查看、作品点评、学习记录同步和消息通知。',
    '2. 生成成长曲线、薄弱科目统计和学习建议。',
    '3. 在去标识化的前提下进行统计分析，用于改进教学服务和产品体验。',
    '4. 我们不会出售您的个人信息，也不会将其用于与本服务无关的用途。',
  ]),
  _TermsSection('三、信息的共享', [
    '1. 与您所在画室共享：完成教学管理所必需的成绩、原卷、作品、考勤等信息，会提供给您所在画室的授权老师和管理人员。',
    '2. 第三方服务：消息推送、地图定位等功能由第三方服务提供，我们仅提供实现功能所必需的最少信息，并要求其履行数据保护义务。',
    '3. 法律法规规定或有权机关依法要求时，我们将依法提供。',
  ]),
  _TermsSection('四、信息的存储与保护', [
    '1. 您的个人信息存储在中华人民共和国境内。',
    '2. 作品照片与原卷图片在账号存续期间及所在画室要求的教学档案保存期限内保存，期满后删除或进行匿名化处理。',
    '3. 我们采取传输加密、访问控制和操作日志等措施保护数据安全。如发生个人信息安全事件，我们将按规定及时告知您并采取补救措施。',
  ]),
  _TermsSection('五、未成年人保护', [
    '本应用的主要用户可能是未满 18 周岁的学生。未满 14 周岁的儿童，需由监护人阅读并同意本政策后方可使用。'
        '我们仅在实现服务所必需的范围内处理未成年人的个人信息，监护人可以联系我们查询、更正或删除相关信息。',
  ]),
  _TermsSection('六、您的权利', [
    '您可以在「个人中心」查看和更正个人资料、修改密码，可以随时撤回已授予的系统权限，也可以申请注销账号，'
        '我们将在 7 个工作日内处理。注销后，您的个人资料与学习记录将被删除或匿名化处理，法律法规另有规定的除外。',
  ]),
  _TermsSection('七、联系我们', [
    '运营主体：$_operator',
    '如您对本协议或隐私政策有任何疑问、意见或投诉，可以通过「个人中心 - 意见反馈」或左侧导航的「意见反馈」与我们联系，'
        '我们将在 15 个工作日内答复。',
  ]),
];
