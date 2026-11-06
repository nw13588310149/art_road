import '../demo_backend.dart';
import 'content_cloud_drive.dart';
import 'content_favorites.dart';
import 'content_home.dart';
import 'content_news.dart';
import 'content_notes.dart';
import 'content_school_site.dart';
import 'content_videos.dart';

/// 内容类演示接口：首页轮播 / 课程提醒、资讯、视频中心、校园课件、微校、
/// 我的云盘、我的收藏、我的笔记。
void registerContentFixtures(DemoRouter platform) {
  registerContentHomeFixtures(platform);
  registerContentNewsFixtures(platform);
  registerContentVideoFixtures(platform);
  registerContentSchoolSiteFixtures(platform);
  registerContentCloudDriveFixtures(platform);
  registerContentFavoriteFixtures(platform);
  registerContentNoteFixtures(platform);
}
