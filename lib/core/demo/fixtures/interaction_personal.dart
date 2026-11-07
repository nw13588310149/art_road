import '../demo_backend.dart';
import '../demo_store.dart';
import 'interaction_common.dart';
import 'interaction_qr.dart';
import 'platform_core_fixtures.dart' show demoUserInfo;

/// 演示兑换码：大小写、首尾空格不敏感，可在同一账号重复兑换。
const _redeemCodes = <String, ({String plan, int days})>{
  'ART2026': (plan: '年卡 365 天', days: 365),
  'ARTQ90': (plan: '季卡 90 天', days: 90),
  'ARTM30': (plan: '月卡 30 天', days: 30),
};

/// 会员权益只写已上线的功能；正式价格未定，套餐不下发金额。
const _vipBenefits = <String>[
  '范画库高清原图浏览与下载',
  '视频中心全部专项课程',
  '题库全部题目与错题本',
  '作品档案云端存储',
];

/// 个人中心：会员套餐、我的二维码、会员兑换。
void registerPersonalCenterFixtures(DemoRouter r) {
  r.any('/app/user/vipList', (req) {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'vip-year',
        'name': '年卡 365 天',
        'description': '覆盖一整个备考周期',
        'days': 365,
        'benefits': _vipBenefits,
      },
      <String, dynamic>{
        'id': 'vip-quarter',
        'name': '季卡 90 天',
        'description': '适合集训阶段使用',
        'days': 90,
        'benefits': _vipBenefits,
      },
      <String, dynamic>{
        'id': 'vip-month',
        'name': '月卡 30 天',
        'description': '含高清范画与视频课程',
        'days': 30,
        'benefits': _vipBenefits.take(2).toList(),
      },
    ];
  });

  r.any('/app/user/myQrcode', (req) {
    return demoQrPngDataUri(
      'https://yyzl0931.com/?invite=${req.account.userId}',
    );
  });

  r.any('/app/user/vipCardRedeem', (req) {
    final code = req.str('cardNumber').replaceAll(' ', '').toUpperCase();
    if (code.isEmpty) {
      throw const DemoApiException('请输入兑换码');
    }
    final card = _redeemCodes[code];
    if (card == null) {
      throw const DemoApiException('兑换码无效或已过期，请核对后重试');
    }
    final profile = demoProfileOf(req.account);
    DateTime? parse(Object? value) => DateTime.tryParse('${value ?? ''}');
    final start = <DateTime?>[
      DateTime.now(),
      parse(profile['vipExpireDate']),
      parse(demoUserInfo(req.account)['vipExpireDate']),
    ].whereType<DateTime>().reduce((a, b) => a.isAfter(b) ? a : b);
    final expire = start.add(Duration(days: card.days));
    final expireText = demoTimeText(
      DateTime(expire.year, expire.month, expire.day, 23, 59, 59),
    );
    profile['vipExpireDate'] = expireText;
    DemoStore.save('profile:${req.account.userId}');
    return <String, dynamic>{
      'cardNumber': code,
      'vipName': card.plan,
      'days': card.days,
      'vipExpireDate': expireText,
    };
  });
}
