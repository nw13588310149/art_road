import '../demo_backend.dart';
import 'content_common.dart';

const _teachers = <(String, String, String, String)>[
  ('李静', '素描主讲', '擅长石膏像与素描头像教学，注重结构与明暗的系统训练。', '#715EFE'),
  ('张明远', '素描教师', '负责几何体与静物素描，带领新生建立扎实的造型基础。', '#4A74D6'),
  ('刘芳', '色彩主讲', '长期带队风景写生，擅长色调统一与环境色教学。', '#DE7A34'),
  ('王海波', '色彩教师 · 班主任', '负责色彩静物与月考讲评，关注每位学员的分数变化。', '#D64A62'),
  ('赵雪', '速写主讲 · 班主任', '人物动态与组合速写教学经验丰富，主抓晚自习速写训练。', '#3B9A6E'),
  ('周强', '速写教师 · 班主任', '负责场景速写与校考提高班，擅长画面组织与构图。', '#1F8FA8'),
  ('吴雨桐', '创作 · 美术常识', '负责命题创作、设计基础与美术史常识课程。', '#B9770F'),
];

String _schoolHomeHtml() {
  String img(String ref) => ContentDemo.url(ref);
  final teacherCards = StringBuffer();
  for (final t in _teachers) {
    teacherCards.write(
      '<div class="teacher"><div class="avatar" style="background:${t.$4}">'
      '${t.$1.substring(t.$1.length - 1)}</div><h3>${t.$1}</h3>'
      '<div class="role">${t.$2}</div><p>${t.$3}</p></div>',
    );
  }
  final works = <String>[
    ContentDemo.art('sketch-bust-1'),
    ContentDemo.art('color-still-2'),
    ContentDemo.art('speed-group-1'),
    ContentDemo.art('sketch-still-1'),
    ContentDemo.art('color-landscape-1'),
    ContentDemo.art('speed-figure-1'),
    ContentDemo.art('sketch-portrait-1'),
    ContentDemo.art('color-flower-1'),
  ];
  final gallery = works.map((w) => '<img src="${img(w)}">').join();

  return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>示范画室</title>
<style>
:root { --brand: #715EFE; --ink: #0B081A; --ink2: #6D6B75; --bg: #F7F7FB; }
body { margin: 0; background: var(--bg); color: var(--ink);
  font-family: -apple-system, "PingFang SC", "Helvetica Neue", "Microsoft YaHei", sans-serif; }
.hero { position: relative; height: 320px; background: url("${img(ContentDemo.scene('studio-wall'))}") center / cover no-repeat; }
.hero::after { content: ""; position: absolute; inset: 0;
  background: linear-gradient(90deg, rgba(11, 8, 26, 0.82) 0%, rgba(11, 8, 26, 0.35) 55%, rgba(11, 8, 26, 0.05) 100%); }
.hero-inner { position: absolute; left: 40px; bottom: 40px; z-index: 1; color: #fff; }
.hero .logo { width: 60px; height: 60px; border-radius: 16px; background: #fff; padding: 6px; box-sizing: border-box; display: block; margin-bottom: 16px; }
.hero h1 { margin: 0 0 8px; font-size: 34px; letter-spacing: 2px; }
.hero p { margin: 0; font-size: 15px; opacity: 0.9; }
.hero .tags { margin-top: 14px; }
.hero .tags span { display: inline-block; margin-right: 8px; padding: 4px 10px; border-radius: 8px; background: rgba(255, 255, 255, 0.16); font-size: 12px; }
.section { padding: 28px 40px 4px; }
.section h2 { margin: 0; font-size: 20px; }
.section .sub { margin: 4px 0 16px; color: #B6B5BB; font-size: 12px; letter-spacing: 2px; }
.card { background: #fff; border-radius: 16px; padding: 20px 22px; font-size: 14px; line-height: 1.9; color: #2B2838; }
.stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; margin-top: 14px; }
.stat { background: #fff; border-radius: 14px; padding: 18px; }
.stat b { display: block; font-size: 28px; color: var(--brand); }
.stat span { font-size: 12px; color: var(--ink2); }
.courses { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; }
.course { background: #fff; border-radius: 16px; overflow: hidden; }
.course img { display: block; width: 100%; height: 150px; object-fit: cover; }
.course div { padding: 14px 16px 16px; }
.course h3 { margin: 0 0 6px; font-size: 16px; }
.course p { margin: 0; font-size: 13px; line-height: 1.7; color: var(--ink2); }
.teachers { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; }
.teacher { background: #fff; border-radius: 16px; padding: 20px 16px; text-align: center; }
.avatar { width: 64px; height: 64px; margin: 0 auto 10px; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #fff; font-size: 24px; font-weight: 600; }
.teacher h3 { margin: 0; font-size: 15px; }
.teacher .role { margin: 4px 0 8px; font-size: 12px; color: var(--brand); }
.teacher p { margin: 0; font-size: 12px; line-height: 1.6; color: var(--ink2); }
.honors { margin: 0; padding-left: 20px; }
.honors li { margin: 6px 0; }
.env { display: grid; grid-template-columns: 2fr 1fr; gap: 12px; }
.env img { display: block; width: 100%; height: 100%; min-height: 150px; object-fit: cover; border-radius: 14px; }
.env .col { display: grid; gap: 12px; }
.gallery { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; }
.gallery img { display: block; width: 100%; height: 170px; object-fit: cover; border-radius: 12px; }
.campus { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; }
.campus h3 { margin: 0 0 6px; font-size: 15px; }
.campus p { margin: 0; font-size: 13px; line-height: 1.8; color: var(--ink2); }
.note { margin-top: 10px; font-size: 12px; color: #8F86A8; }
.footer { padding: 28px 40px 40px; text-align: center; font-size: 12px; color: #B6B5BB; }
</style>
</head>
<body>
<div class="hero">
  <div class="hero-inner">
    <img class="logo" src="${img(ContentDemo.schoolLogo)}">
    <h1>示范画室</h1>
    <p>专注美术联考与校考 · 素描、色彩、速写全科教学</p>
    <div class="tags"><span>城东校区</span><span>城西校区</span><span>安宁校区</span></div>
  </div>
</div>

<div class="section">
  <h2>画室简介</h2>
  <div class="sub">ABOUT US</div>
  <div class="card">
    示范画室专注美术联考与校考培训，覆盖素描、色彩、速写全科教学。画室坚持“结构先行、色彩统一、速写日日练”的教学理念，
    通过阶段测评、原卷复盘与专项训练，持续记录每一位学员的成长轨迹。三个校区统一教研、统一月考、统一阅卷，
    学员可以在“美术之路”中查看每次月考的原卷、评分与老师点评。
  </div>
  <div class="stats">
    <div class="stat"><b>3</b><span>教学校区</span></div>
    <div class="stat"><b>8</b><span>任课教师</span></div>
    <div class="stat"><b>7</b><span>年度月考场次</span></div>
    <div class="stat"><b>40</b><span>2027 届在读学员（示例）</span></div>
  </div>
</div>

<div class="section">
  <h2>课程体系</h2>
  <div class="sub">COURSES</div>
  <div class="courses">
    <div class="course"><img src="${img(ContentDemo.art('sketch-geometry-1'))}"><div><h3>基础班</h3><p>几何体、静物与石膏五官，建立结构观察与明暗表现的基础。</p></div></div>
    <div class="course"><img src="${img(ContentDemo.art('sketch-portrait-1'))}"><div><h3>联考冲刺班</h3><p>素描头像、色彩静物、人物速写三科联动，每周限时模拟与讲评。</p></div></div>
    <div class="course"><img src="${img(ContentDemo.art('speed-group-1'))}"><div><h3>校考提高班</h3><p>命题创作、组合速写与院校考题分析，针对目标院校专项提升。</p></div></div>
  </div>
</div>

<div class="section">
  <h2>师资团队</h2>
  <div class="sub">TEACHERS</div>
  <div class="teachers">$teacherCards</div>
</div>

<div class="section">
  <h2>教学成果</h2>
  <div class="sub">ACHIEVEMENTS</div>
  <div class="card">
    <ul class="honors">
      <li>2026 年 4–10 月共组织 7 场三校区统一月考，全部采用多位老师独立评阅。</li>
      <li>秋季写生周完成色彩作品 300 余张、速写 800 余张，优秀作品在画室作品墙长期展出。</li>
      <li>多名学员在月考中实现单科 15 分以上的提升，详细成长曲线可在学情中心查看。</li>
    </ul>
    <div class="note">以上为演示数据，仅用于功能展示。</div>
  </div>
</div>

<div class="section">
  <h2>画室环境</h2>
  <div class="sub">ENVIRONMENT</div>
  <div class="env">
    <img src="${img(ContentDemo.scene('studio-wall'))}">
    <div class="col">
      <img src="${img(ContentDemo.scene('exam-hall'))}">
      <img src="${img(ContentDemo.art('sketch-still-2'))}">
    </div>
  </div>
</div>

<div class="section">
  <h2>学员作品</h2>
  <div class="sub">WORKS</div>
  <div class="gallery">$gallery</div>
</div>

<div class="section">
  <h2>校区与联系方式</h2>
  <div class="sub">CONTACT</div>
  <div class="campus">
    <div class="card"><h3>城东校区</h3><p>联考冲刺 1 班<br>兰州市城关区（示例地址）</p></div>
    <div class="card"><h3>城西校区</h3><p>联考冲刺 2 班<br>兰州市七里河区（示例地址）</p></div>
    <div class="card"><h3>安宁校区</h3><p>校考提高班<br>兰州市安宁区（示例地址）</p></div>
  </div>
  <div class="card" style="margin-top:14px">咨询电话：0931-8888666　·　开放时间：周一至周六 08:00–21:30</div>
</div>

<div class="footer">© 示范画室 · 本页内容为演示数据</div>
</body>
</html>
''';
}

void registerContentSchoolSiteFixtures(DemoRouter r) {
  r.any('/app/school/v2/user/homePage', (req) {
    return <String, dynamic>{
      'schoolId': req.str('schoolId', '1'),
      'title': '示范画室微校',
      'html': _schoolHomeHtml(),
      'updateTime': '2026-11-01 09:00:00',
    };
  });
}
