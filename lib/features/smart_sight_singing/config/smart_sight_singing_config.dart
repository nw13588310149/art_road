/// 智能视唱可调参数集中入口。
///
/// 这里收敛的是会影响识别、评分、MIDI 解析和练习体验的参数；颜色、圆角、
/// 字体等纯样式常量仍留在 UI 文件中，避免把主题配置和业务调参混在一起。
abstract final class SmartSightSingingImportConfig {
  /// 内置 demo MIDI 资源路径。
  /// 范围/约束：必须是 pubspec.yaml 中声明的 `.mid` / `.midi` 资源。
  /// 调整内容：点击“解析 demo”时使用的示例谱例。
  static const String demoMidiAssetPath = 'assets/audio/demo.mid';

  /// 内置 demo 展示名。
  /// 范围/约束：非空短文本。
  /// 调整内容：选轨页和状态文案中的曲目名称。
  static const String demoDisplayName = 'demo';

  /// 本地 MIDI 最大文件体积。
  /// 建议范围：1MB ~ 20MB；越大导入越宽松，但解析耗时和内存占用越高。
  /// 调整内容：本地 `.mid/.midi` 文件选择后的体积校验。
  static const int maxLocalMidiBytes = 8 * 1024 * 1024;

  /// 在线 MIDI 最大文件体积。
  /// 建议范围：1MB ~ 20MB；越大在线下载和解析等待越久。
  /// 调整内容：在线 MIDI 链接下载后的体积校验。
  static const int maxOnlineMidiBytes = 8 * 1024 * 1024;

  /// 在线 MIDI 连接超时。
  /// 建议范围：5s ~ 20s；网络慢时可适当调大。
  /// 调整内容：在线链接建立连接的等待时间。
  static const Duration onlineConnectTimeout = Duration(seconds: 12);

  /// 在线 MIDI 接收超时。
  /// 建议范围：15s ~ 90s；大文件或弱网时可适当调大。
  /// 调整内容：在线链接下载数据的等待时间。
  static const Duration onlineReceiveTimeout = Duration(seconds: 45);

  /// 本地 MusicXML 最大文件体积。
  static const int maxLocalMusicXmlBytes = 8 * 1024 * 1024;

  /// 本地 MusicXML 允许的扩展名（含压缩 .mxl）。
  static const List<String> musicXmlExtensions = <String>[
    'xml',
    'musicxml',
    'mxl',
  ];

  /// 根据文件名判断是否为支持的 MusicXML 扩展名。
  static bool isMusicXmlFileName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot >= name.length - 1) {
      return false;
    }
    final ext = name.substring(dot + 1).trim().toLowerCase();
    return musicXmlExtensions.contains(ext);
  }
}

abstract final class SmartSightSingingSessionConfig {
  /// 跟唱前倒计时秒数。
  /// 建议范围：1 ~ 5；越大给学生准备时间越长。
  /// 调整内容：点击“开始跟唱”后的准备倒计时。
  static const int countdownStartSeconds = 3;

  /// 用户音高轨迹保留点数。
  /// 建议范围：240 ~ 2000；越大拖尾越长但重绘成本越高。
  /// 调整内容：KTV 音高轨上保留的实时演唱轨迹长度。
  static const int userPitchPointCap = 720;
}

abstract final class SmartSightSingingScoringConfig {
  /// 麦克风链路延迟补偿。
  /// 建议范围：0ms ~ 300ms；iPad 外放/录音链路变慢时调大。
  /// 调整内容：评分时把用户声音往前对齐参考音符的量。
  static const int micLatencyMs = 120;

  /// 音符开始前允许提前演唱窗口。
  /// 建议范围：0ms ~ 300ms；越大越宽容抢拍。
  /// 调整内容：用户稍早进入音符时是否仍计入该音符评分。
  static const int earlySingMs = 150;

  /// 音符结束后的尾音窗口。
  /// 建议范围：0ms ~ 400ms；越大越宽容拖拍或尾音。
  /// 调整内容：用户稍晚离开音符时是否仍计入该音符评分。
  static const int lateSingMs = 180;

  /// 默认命中/Good 音准容差，单位 cents。
  /// 建议范围：60 ~ 120；专业考试可用 60~90，普通课堂可用 90~120。
  /// 调整内容：偏离标准音多少 cents 内算命中。
  static const double defaultStandardCents = 90;

  /// 命中容差最小值。
  /// 建议范围：20 ~ 60；过小会导致麦克风抖动时评分过严。
  /// 调整内容：代码或后台配置传入评分容差时的下限保护。
  static const double minStandardCents = 30;

  /// 命中容差最大值。
  /// 建议范围：120 ~ 240；过大会弱化音准评价。
  /// 调整内容：代码或后台配置传入评分容差时的上限保护。
  static const double maxStandardCents = 200;

  /// 默认 Perfect 阈值，单位 cents。
  /// 建议范围：30 ~ 60；越小越难拿满分。
  /// 调整内容：默认容差下 Perfect 的音准要求。
  static const double perfectCentsAtDefault = 45;

  /// 默认 OK 阈值，单位 cents。
  /// 建议范围：110 ~ 180；越大越容易获得部分分。
  /// 调整内容：默认容差下 OK 的音准要求。
  static const double okCentsAtDefault = 130;

  /// Perfect / Good / OK 分值。
  /// 建议范围：0 ~ 100；Good 建议保持 >=80，避免命中率和分数割裂。
  /// 调整内容：每个音符结算后的分数。
  static const int perfectPoints = 100;
  static const int goodPoints = 80;
  static const int okPoints = 55;

  /// 音符条参考采样提前窗口。
  /// 建议范围：0ms ~ 200ms；越大 UI/评分参考音更容易吸附到临近音符。
  /// 调整内容：当前时刻查找参考音高时，向前兼容的范围。
  static const int referenceSampleEarlyMs = 120;

  /// 音符条参考采样滞后窗口。
  /// 建议范围：0ms ~ 200ms；越大 UI/评分参考音更容易吸附到临近音符。
  /// 调整内容：当前时刻查找参考音高时，向后兼容的范围。
  static const int referenceSampleLateMs = 120;

  /// 原始音高帧搜索半窗。
  /// 建议范围：20ms ~ 120ms；越大越容易找到附近音高帧，也可能变钝。
  /// 调整内容：无音符条时，查找临近有效 pitch frame 的范围。
  static const int referenceFrameSearchHalfWindowMs = 60;

  static double normalizeStandardCents(double cents) {
    if (!cents.isFinite) return defaultStandardCents;
    return cents.clamp(minStandardCents, maxStandardCents).toDouble();
  }
}

abstract final class SmartSightSingingMidiConfig {
  /// General MIDI 打击乐通道。
  /// 范围/约束：0-based MIDI channel，通常为 9。
  /// 调整内容：构建播放事件时过滤鼓组音符。
  static const int percussionChannel = 9;

  /// 主旋律推荐的人声 MIDI 下限/上限。
  /// 建议范围：男声约 48~72，女声/童声约 55~84。
  /// 调整内容：选轨页“推荐”轨道的启发式判断。
  static const int melodyMidiMin = 55;
  static const int melodyMidiMax = 84;

  /// 低音惩罚阈值。
  /// 建议范围：40 ~ 55；越高越不容易推荐低音/伴奏轨。
  /// 调整内容：主旋律推荐时对低音音符数量的惩罚。
  static const int lowPitchPenaltyBelowMidi = 50;

  /// 推荐主旋律的理想音符数量。
  /// 建议范围：60 ~ 300；短曲调小，长曲调大。
  /// 调整内容：主旋律推荐时偏好“像旋律线”的音符密度。
  static const int idealMelodyNoteCount = 180;

  /// 推荐主旋律的权重。
  /// 建议范围：vocal 1~4，lowPenalty 0~3，noteCountPenalty 0~0.2。
  /// 调整内容：轨道推荐算法中人声音区、低音惩罚、音符数量偏离的权重。
  static const double vocalPitchWeight = 2.0;
  static const double lowPitchPenaltyWeight = 1.5;
  static const double noteCountDistancePenalty = 0.08;

  /// MIDI 参考轨默认帧步长。
  /// 建议范围：10ms ~ 50ms；仅作为 PitchTrack 元数据。
  /// 调整内容：MIDI 构建的参考轨 frameStepMs。
  static const int referenceFrameStepMs = 23;

  /// MIDI 音符最短有效时长。
  /// 建议范围：20ms ~ 120ms；越大越能过滤极短装饰/误触。
  /// 调整内容：MIDI 音符转参考音符条时的最小时长兜底。
  static const int minMidiNoteMs = 40;

  /// MusicXML 跟唱前标准音 MIDI 音高（A4 = 69）。
  /// 调整内容：预备拍开始前播放的参考音高。
  static const int musicXmlReferencePitchMidi = 69;

  /// MusicXML 标准音开始时间（毫秒，相对跟唱起点）。
  static const int musicXmlReferencePitchStartMs = 500;

  /// MusicXML 节拍器开始时间（毫秒，相对跟唱起点；与标准音开始时间独立）。
  static const int musicXmlMetronomeStartMs = 3000;

  /// 最后一个播放事件之后的尾音留白（毫秒），避免调度器提前结束。
  static const int playbackTailMs = 400;
}

abstract final class SmartSightSingingPitchRangeConfig {
  /// 默认显示音域。
  /// 建议范围：覆盖常用人声区；无有效音符/音高帧时使用。
  /// 调整内容：音高轨和谱例视图纵向范围兜底。
  static const double defaultMinMidi = 48;
  static const double defaultMaxMidi = 72;

  /// 音域上下留白。
  /// 建议范围：1 ~ 6 半音；越大视觉空间越宽。
  /// 调整内容：根据曲目自动计算纵轴范围时的上下边距。
  static const double rangePaddingSemitones = 2;

  /// 显示音域硬边界。
  /// 建议范围：24 ~ 100；覆盖钢琴 C1 到 E7 左右即可。
  /// 调整内容：自动音域不会超出的上下限。
  static const double hardMinMidi = 24;
  static const double hardMaxMidi = 100;

  /// 最小显示音域。
  /// 建议范围：6 ~ 18 半音；越大纵向变化越不夸张。
  /// 调整内容：单音或窄音域曲目的纵轴最小跨度。
  static const double minDisplayedRangeSemitones = 6;
}

abstract final class SmartSightSingingKtvGuideConfig {
  /// 离线音高帧合并成音符条时的最短音符。
  /// 建议范围：80ms ~ 250ms；越大越容易过滤碎音。
  /// 调整内容：YIN/mp3 旧链路生成 KTV 音符条的最小持续时间。
  static const int minNoteMs = 140;

  /// 同音合并允许的断裂间隔。
  /// 建议范围：60ms ~ 250ms；越大越容易把断续同音合成一条。
  /// 调整内容：离线音高帧整理音符条时的同音合并。
  static const int mergeGapMs = 160;

  /// 离线音高帧最低置信度。
  /// 建议范围：0.35 ~ 0.75；越高越严格、越少误检。
  /// 调整内容：YIN/mp3 旧链路中哪些 pitch frame 可进入音符条。
  static const double minConfidence = 0.52;

  /// 同音判定半音容差。
  /// 建议范围：0.25 ~ 0.75；越大越容易合并相近音。
  /// 调整内容：离线音高帧量化后是否属于同一个音。
  static const double sameNoteToleranceSemitones = 0.5;

  /// 八度连续性候选。
  /// 范围/约束：半音偏移列表；通常保持 ±12、±24。
  /// 调整内容：离线音高量化时修正八度跳变的候选集合。
  static const List<double> octaveContinuityCandidates = <double>[
    -24,
    -12,
    0,
    12,
    24,
  ];

  /// 毛刺音最小跳进。
  /// 建议范围：3 ~ 8 半音；越小越容易删除极短跳音。
  /// 调整内容：离线音符条清理时，短音与前后都相差多大视为毛刺。
  static const double spuriousBlipJumpSemitones = 4;

  /// 清理后保留音符最短时长。
  /// 建议范围：50ms ~ 150ms；越大越少短装饰音。
  /// 调整内容：离线音符条最终保留门槛。
  static const int minCleanedSegmentMs = 80;
}

abstract final class SmartSightSingingVoiceGateConfig {
  /// 无声跟唱最低人声响度。
  /// 建议范围：0.005 ~ 0.03；越高越抗噪，但轻声更容易无效。
  /// 调整内容：无伴奏时，多大麦克风响度才进入评分。
  static const double visualOnlyMinAmplitude = 0.012;

  /// 有伴奏跟唱最低人声响度。
  /// 建议范围：0.01 ~ 0.05；越高越能抗外放串音。
  /// 调整内容：有扬声器伴奏时，多大麦克风响度才进入评分。
  static const double accompanimentMinAmplitude = 0.018;

  /// 被判为扬声器串音的最大响度。
  /// 建议范围：0.04 ~ 0.12；越高越容易过滤外放，也可能误杀轻声。
  /// 调整内容：与当前伴奏音高相同且响度低于该值时，视为串音。
  static const double bleedMatchMaxAmplitude = 0.075;

  /// 串音音高匹配窗口。
  /// 建议范围：5 ~ 25 cents；越大越容易过滤接近伴奏的声音。
  /// 调整内容：麦克风音高与伴奏音高多接近时进入串音判断。
  static const double bleedMatchMaxCents = 10;

  /// 强人声额外响度。
  /// 建议范围：0.02 ~ 0.08；越小越容易把与伴奏同音的用户声音放行。
  /// 调整内容：即使音高等于伴奏，响度明显更大时仍视为用户发声。
  static const double strongVoiceExtraAmplitude = 0.045;
}

abstract final class SmartSightSingingRealtimePitchConfig {
  /// 实时录音采样率。
  /// 建议范围：44100 或 48000；改变后会影响 buffer 时间长度。
  /// 调整内容：iPad 实时麦克风采样质量和延迟。
  static const int sampleRate = 44100;

  /// 实时音高检测 buffer。
  /// 建议范围：2048 ~ 8192；越小延迟低但稳定性差，越大更稳但更慢。
  /// 调整内容：实时 YIN/自相关检测每帧采样数。
  static const int bufferSize = 2048;

  /// 实时检测最低 RMS。
  /// 建议范围：80 ~ 500；越高越抗噪，越低越灵敏。
  /// 调整内容：实时麦克风响度低于多少直接判为无音高。
  static const double minRms = 120;

  /// PitchFrame 最低置信度。
  /// 建议范围：0.25 ~ 0.7；越高越不容易显示/使用低置信度音高。
  /// 调整内容：PitchFrame.pitched 的真假判断。
  static const double frameMinConfidence = 0.4;

  /// 人声可检测频率范围。
  /// 建议范围：min 50~90Hz，max 1000~1600Hz。
  /// 调整内容：实时 YIN/自相关接受的音高频率上下限。
  static const double minFrequencyHz = 65;
  static const double maxFrequencyHz = 1400;

  /// 自相关搜索最高频率。
  /// 建议范围：800 ~ 1600Hz；越高越能识别高音但更易误检。
  /// 调整内容：自相关候选 lag 的最小值。
  static const double autocorrelationMaxFrequencyHz = 1200;

  /// 自相关最低可信度。
  /// 建议范围：0.2 ~ 0.6；越高越严格。
  /// 调整内容：YIN 失败后，自相关结果是否可用。
  static const double autocorrelationMinCorrelation = 0.24;

  /// 稳定音高连续帧相对差。
  /// 建议范围：0.04 ~ 0.12；越大越容易认为音高稳定。
  /// 调整内容：实时音高平滑时判断相邻帧是否同一稳定音。
  static const double stableFrequencyDiffRatio = 0.08;

  /// 进入稳定平滑所需帧数。
  /// 建议范围：1 ~ 4；越大越稳但响应更慢。
  /// 调整内容：实时音高跳动时使用稳定值的门槛。
  static const int stableFrameCount = 2;

  /// 平滑后最低置信度。
  /// 建议范围：0.45 ~ 0.75。
  /// 调整内容：使用稳定值补偿时给出的置信度下限。
  static const double smoothedConfidenceFloor = 0.55;

  /// YIN 结果优先差值。
  /// 建议范围：0.03 ~ 0.15；越大越不容易切换检测来源。
  /// 调整内容：两个检测结果置信度差多少时选择更高者。
  static const double sourceSwitchConfidenceMargin = 0.08;

  /// PCM 转 UI 响度时的峰值权重。
  /// 建议范围：0.3 ~ 0.8；越大瞬态声音显示越明显。
  /// 调整内容：实时麦克风响度归一化。
  static const double amplitudePeakWeight = 0.55;

  /// PCM RMS 归一化除数。
  /// 建议范围：500 ~ 2000；越小 UI 响度越容易打满。
  /// 调整内容：实时麦克风响度归一化。
  static const double amplitudeRmsDivisor = 900;
}

abstract final class SmartSightSingingOfflineAnalysisConfig {
  /// 旧 mp3/YIN 离线分析采样率。
  /// 建议范围：16000 ~ 44100；越高越精细但更耗时。
  /// 调整内容： legacy 音频分析链路的目标采样率。
  static const int analysisSampleRate = 22050;

  /// 旧 mp3/YIN buffer/hop。
  /// 建议范围：buffer 512~4096，hop 通常为 buffer 的 1/2。
  /// 调整内容：legacy 离线音高分析的时间分辨率和稳定性。
  static const int yinBufferSize = 1024;
  static const int yinHopSize = 512;

  /// 离线分析最长时长。
  /// 建议范围：180s ~ 900s；越大越支持长音频但耗时越高。
  /// 调整内容：legacy 离线音频读取/分析上限。
  static const int maxAnalysisSeconds = 480;
  static const int webMaxAnalysisSeconds = 360;

  /// 文件大小估算时每秒字节数。
  /// 建议范围：8000 ~ 32000；越大估算出的时长越短。
  /// 调整内容：无 durationHint 时 legacy 音频读取采样数估计。
  static const int estimatedBytesPerSecond = 16000;

  /// 离线分析最低 RMS。
  /// 建议范围：150 ~ 800；越高越能过滤背景噪声。
  /// 调整内容：legacy YIN 分析中低响度帧是否跳过。
  static const double minRms = 350;

  /// 离线分析频率范围。
  /// 建议范围：min 50~90Hz，max 1000~1600Hz。
  /// 调整内容：legacy YIN 分析接受的音高频率上下限。
  static const double minFrequencyHz = 60;
  static const double maxFrequencyHz = 1400;

  /// 根据样本数和时长反推采样率时的钳制范围。
  /// 建议范围：8000 ~ 48000。
  /// 调整内容：legacy 分析输入音频采样率异常时的保护。
  static const double minDerivedSampleRate = 8000;
  static const double maxDerivedSampleRate = 48000;

  /// 中值平滑窗口和跳变阈值。
  /// 建议范围：radius 1~4，minPitched 2~5，jump 0.3~1.2 半音。
  /// 调整内容：legacy 音高帧平滑时如何抑制突发跳音。
  static const int medianSmoothRadius = 2;
  static const int medianSmoothMinPitched = 3;
  static const double medianSmoothJumpSemitones = 0.6;
}

abstract final class SmartSightSingingViewConfig {
  /// KTV 音高轨 Now 线横向位置。
  /// 建议范围：0.25 ~ 0.5；越小预读区域越多。
  /// 调整内容：KTV 音高轨中当前时刻竖线的位置。
  static const double karaokeNowLineFraction = 0.32;

  /// KTV 音高轨时间窗。
  /// 建议范围：4000ms ~ 10000ms；越大看得更远，局部精度更低。
  /// 调整内容：KTV 音高轨横向显示的时间范围。
  static const int karaokeWindowMs = 6000;

  /// Now 竖线附近不重复绘制历史拖尾点的时间半径（毫秒）。
  /// 避免与实时检测光晕叠成两个圆点。
  static const int karaokeNowLineSkipTrailMs = 50;

  /// 未识别音高时 Now 线光晕的默认纵向位置（距画布顶部的逻辑像素）。
  static const double karaokeIdleGlowCenterY = 48;

  /// 无谱视唱拖尾点半径范围（随响度在区间内变化）。
  static const double karaokeTrailMinRadius = 3.0;
  static const double karaokeTrailMaxRadius = 6.0;

  /// 拖尾点透明度下限（对应原版 alpha 40/255）。
  static const double karaokeTrailMinAlpha = 0.16;

  /// 谱例视唱 Now 线横向位置。
  /// 建议范围：0.25 ~ 0.5；越小右侧可预读谱例越多。
  /// 调整内容：五线谱视图中当前时刻竖线的位置。
  static const double scoreNowLineFraction = 0.30;

  /// 谱例视唱时间窗。
  /// 建议范围：6000ms ~ 14000ms；越大越接近看谱预读体验。
  /// 调整内容：五线谱视图横向显示的时间范围。
  static const int scoreWindowMs = 8000;

  /// 谱例视图五线谱行距占高度比例。
  /// 建议范围：0.08 ~ 0.14；越大谱面更松，超出音域更容易加线。
  /// 调整内容：五线谱在画布中的纵向大小。
  static const double scoreLineSpacingHeightFraction = 0.11;

  /// 麦克风活动指示最低响度。
  /// 建议范围：0.005 ~ 0.03；越低越容易显示“拾音中”。
  /// 调整内容：未识别出音高但有响度时，UI 是否显示拾音活动。
  static const double micActivityIndicatorMinAmplitude = 0.01;

  /// 记分板“拾音中”最低响度。
  /// 建议范围：0.005 ~ 0.03；通常与无声跟唱最低响度接近。
  /// 调整内容：顶部记分板“你的音”何时显示拾音中。
  static const double pickupLabelMinAmplitude = 0.012;

  /// 谱例视图五线谱参考步进。
  /// 范围/约束：E4=30、F5=38 对应高音谱表五线。
  /// 调整内容：五线谱垂直定位，通常不需要改。
  static const int trebleStaffBottomStep = 30;
  static const int trebleStaffTopStep = 38;
}
