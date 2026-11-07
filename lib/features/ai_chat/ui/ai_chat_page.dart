import 'dart:async';

import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/widgets/app_text_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../../../core/widgets/pdf/app_pdf_view.dart';
import '../data/ai_chat_attachment_picker.dart';
import '../../shell/state/shell_controller.dart';
import '../state/ai_chat_controller.dart';
import '../state/ai_chat_state.dart';

const _border = AppColors.lineSoft;
const _panelFill = Color(0xFFF4F4FF);
const _textPrimary = AppColors.ink;
const _textSecondary = Color(0xFF707790);
const _textHint = AppColors.textPlaceholder;
const _purple = AppColors.brand;

const _historyPaneWidth = 200.0;
const _historyItemHorizontalPadding = 12.0;
const _historyPaneBottomPadding = 12.0;
const _conversationHeaderHeight = 56.0;
const _mainHorizontalPadding = 64.0;
const _mainBottomPadding = 12.0;
const _landingBottomPadding = 41.0;
const _conversationBottomInset = 8.0;

const _theoryPrompts = <_AiPromptQuestion>[
  _AiPromptQuestion('1', '素描起形总是不准怎么办？'),
  _AiPromptQuestion('2', '明暗五大调子分别是什么？'),
  _AiPromptQuestion('3', '色彩画面发灰怎么调整？'),
  _AiPromptQuestion('4', '速写人体比例和动态怎么抓？'),
  _AiPromptQuestion('5', '联考评分 A–E 档怎么划分？'),
  _AiPromptQuestion('6', '静物构图有哪些常用法则？'),
];

const _toolShortcuts = <_AiToolShortcut>[
  _AiToolShortcut(
    title: '报考院校梳理',
    subtitle: '按成绩梳理可报院校',
    prompt: '请根据我的成绩帮我梳理适合我的报考院校',
    kind: _AiToolKind.school,
  ),
  _AiToolShortcut(
    title: '练习建议',
    subtitle: '按薄弱科目安排练习',
    prompt: '请结合我的成绩，帮我安排一份素描、色彩、速写的练习建议。',
    kind: _AiToolKind.practice,
  ),
  _AiToolShortcut(
    title: '备考计划',
    subtitle: '生成分阶段备考计划',
    prompt: '请帮我制定一份美术联考备考计划，分阶段说明每日练习重点。',
    kind: _AiToolKind.plan,
  ),
];

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  String _messageSignature = '';

  /// 「贴底滚动」级联里下一帧的 timer。每次新触发滚动时先 cancel 上一个，
  /// 避免短时间内多次 selectSession / 流式推送堆叠出几十个 jumpTo —— 这会
  /// 在用户尝试滑动时把他的拖拽 activity 反复打断（表现为「需要划两次」）。
  Timer? _bottomScrollTimer;

  /// 用户手指当前是否压在消息列表上。压着的时候我们绝对不再触发任何
  /// `jumpTo` / `animateTo`，否则会把用户的 DragScrollActivity 替换成
  /// DrivenScrollActivity，第一次滑动直接被吃掉。
  bool _userTouchingList = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = ref.read(shellControllerProvider).user.id;
      ref
          .read(aiChatControllerProvider.notifier)
          .syncSessionsWithCurrentUser(userId);
    });
  }

  @override
  void dispose() {
    _bottomScrollTimer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(
      shellControllerProvider.select((state) => state.user.id),
      (_, next) {
        ref
            .read(aiChatControllerProvider.notifier)
            .syncSessionsWithCurrentUser(next);
      },
    );
    final state = ref.watch(aiChatControllerProvider);
    final controller = ref.read(aiChatControllerProvider.notifier);
    _scheduleScrollIfNeeded(state);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: AppRadius.br16,
        color: state.isNewConversation ? null : AppColors.surface,
        gradient: state.isNewConversation
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEFEEFD),
                  AppColors.surface,
                  AppColors.surface,
                ],
                stops: [0, 0.34, 1],
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.br16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _historyPaneWidth,
              child: _buildHistoryPane(state, controller),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final mainWidth =
                      constraints.maxWidth - _mainHorizontalPadding * 2;
                  final composerWidth = mainWidth > 0
                      ? mainWidth
                      : constraints.maxWidth;
                  final userBubbleWidth = (mainWidth * 0.62)
                      .clamp(220.0, 420.0)
                      .toDouble();
                  // AI 回复气泡占满对话主列宽度（最小 320 兜底）。
                  final aiBubbleWidth = mainWidth > 320 ? mainWidth : 320.0;

                  if (state.isNewConversation) {
                    return _buildLanding(
                      state: state,
                      controller: controller,
                      composerWidth: composerWidth,
                    );
                  }
                  return _buildConversation(
                    state: state,
                    controller: controller,
                    composerWidth: composerWidth,
                    userBubbleMaxWidth: userBubbleWidth,
                    aiBubbleMaxWidth: aiBubbleWidth,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryPane(AiChatState state, AiChatController controller) {
    final groups = groupSessionsByTime(state.sessions);

    void startNew() {
      controller.startNewChat();
      _inputCtrl.clear();
      setState(() {});
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: _border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          24,
          16,
          _historyPaneBottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPressable(
              onTap: startNew,
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _panelFill,
                  borderRadius: AppRadius.brPill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppAssetGraphic(
                      AppAssets.aiChatNew,
                      width: 16,
                      height: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '开启新对话',
                      style: AppText.body14Strong.copyWith(color: _purple),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('全部', style: AppText.body14Strong),
                const Spacer(),
                const AppAssetGraphic(
                  AppAssets.aiChatHistoryFilter,
                  width: 16,
                  height: 16,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Text(
                    '历史对话',
                    style: AppText.caption12Strong.copyWith(color: _textHint),
                  ),
                  const SizedBox(height: 6),
                  if (state.sessionsLoading && state.sessions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('加载中…', style: AppText.caption12),
                    )
                  else ...[
                    if (state.isNewConversation)
                      _historyTile(title: '新对话', active: true, onTap: startNew),
                    for (final group in groups) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _historyItemHorizontalPadding,
                        ),
                        child: Text(
                          group.label,
                          style: AppText.caption12Strong,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (var i = 0; i < group.items.length; i++) ...[
                        if (i > 0) const SizedBox(height: 2),
                        _historyTile(
                          title: group.items[i].title,
                          active:
                              !state.isNewConversation &&
                              state.activeSessionId == group.items[i].id,
                          onTap: () async {
                            final error = await controller.selectSession(
                              group.items[i].id,
                            );
                            if (error != null && mounted) _showInfo(error);
                          },
                          onMoreTap: (anchor) => _showSessionMoreMenu(
                            anchor,
                            controller,
                            group.items[i],
                          ),
                        ),
                      ],
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyTile({
    required String title,
    required bool active,
    required VoidCallback onTap,
    ValueChanged<BuildContext>? onMoreTap,
  }) {
    const more = SizedBox(
      width: 28,
      height: 32,
      child: Center(
        child: AppAssetGraphic(AppAssets.aiChatMore, width: 14, height: 4),
      ),
    );
    return AppPressable(
      onTap: onTap,
      selected: active,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(
          horizontal: _historyItemHorizontalPadding,
        ),
        decoration: BoxDecoration(
          color: active ? _panelFill : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body14.copyWith(height: 20 / 14),
              ),
            ),
            if (active)
              if (onMoreTap == null)
                more
              else
                Builder(
                  builder: (anchor) => AppPressable(
                    semanticLabel: '对话操作',
                    onTap: () => onMoreTap(anchor),
                    child: more,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  double _composerHeight(AiChatState state) =>
      state.pendingAttachments.isEmpty ? 124.0 : 154.0;

  Widget _buildLanding({
    required AiChatState state,
    required AiChatController controller,
    required double composerWidth,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 600;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            _mainHorizontalPadding,
            compact ? 16 : 94,
            _mainHorizontalPadding,
            compact ? 12 : _landingBottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeSection(),
                      const SizedBox(height: 11),
                      SizedBox(
                        height: 265,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _buildTheoryCard()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildToolCard()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildComposer(state, controller, composerWidth),
              const SizedBox(height: 13),
              _buildDisclaimer(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeSection() {
    return SizedBox(
      height: 76,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: 52,
            child: OverflowBox(
              maxWidth: 90,
              maxHeight: 90,
              child: Image.asset(AppAssets.aiChatMascot, width: 90, height: 90),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  '我是小美同学，很高兴见到你！',
                  style: AppText.title20.copyWith(fontWeight: AppFont.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  '可以和我聊素描、色彩、速写和备考安排，回答仅供参考。',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body13.copyWith(
                    color: _textSecondary,
                    height: 22 / 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTheoryCard() {
    return AppCard(
      color: _panelFill,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      bordered: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '常见问题',
            style: AppText.title16.copyWith(
              fontWeight: AppFont.w500,
              height: 22 / 16,
            ),
          ),
          Text('点一下直接提问', style: AppText.caption12.copyWith(height: 22 / 12)),
          const SizedBox(height: 19),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _theoryPrompts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _theoryPrompts[index];
                final numberColor = switch (index) {
                  0 || 1 => const Color(0xFFEB2F2F),
                  2 => const Color(0xFFFE7B3F),
                  _ => const Color(0xFFCECED1),
                };
                return AppPressable(
                  onTap: () => _handlePromptTap(item.text),
                  child: Row(
                    children: [
                      Text(
                        item.indexLabel,
                        style:
                            AppText.displayNumber(
                              size: 16,
                              color: numberColor,
                            ).copyWith(
                              fontStyle: FontStyle.italic,
                              height: 22 / 16,
                            ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption12.copyWith(
                            color: _textPrimary,
                            height: 22 / 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard() {
    return AppCard(
      color: _panelFill,
      backgroundImage: const DecorationImage(
        image: AssetImage(AppAssets.aiChatToolBg),
        fit: BoxFit.cover,
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      bordered: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '备考助手',
            style: AppText.title16.copyWith(
              fontWeight: AppFont.w500,
              height: 22 / 16,
            ),
          ),
          Text('点一下直接提问', style: AppText.caption12.copyWith(height: 22 / 12)),
          const SizedBox(height: 19),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _toolShortcuts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final tool = _toolShortcuts[index];
                return AppPressable(
                  onTap: () => _handlePromptTap(tool.prompt),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.br8,
                    ),
                    child: Row(
                      children: [
                        _buildToolIcon(tool.kind),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tool.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption12Strong.copyWith(
                                  color: _textPrimary,
                                ),
                              ),
                              Text(
                                tool.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption12,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolIcon(_AiToolKind kind) {
    return switch (kind) {
      _AiToolKind.practice => const AppAssetGraphic(
        AppAssets.aiChatSuggest,
        width: 30,
        height: 30,
      ),
      _AiToolKind.school => const _AiToolBadge(
        colors: [AppColors.brandSoft, AppColors.brandDeep],
        child: Icon(
          Icons.insights_outlined,
          color: AppColors.onBrand,
          size: 19,
        ),
      ),
      _AiToolKind.plan => const _AiToolBadge(
        colors: [Color(0xFFFFBEE9), Color(0xFFFF73D0)],
        child: Stack(
          children: [
            AppAssetGraphic(AppAssets.aiChatPlanBook, width: 14, height: 14),
            Positioned(
              right: 1,
              top: 1,
              child: AppAssetGraphic(
                AppAssets.aiChatPlanMark,
                width: 10,
                height: 10,
              ),
            ),
          ],
        ),
      ),
    };
  }

  Widget _buildConversation({
    required AiChatState state,
    required AiChatController controller,
    required double composerWidth,
    required double userBubbleMaxWidth,
    required double aiBubbleMaxWidth,
  }) {
    final showWaitingAssistant =
        state.waitingAssistant &&
        !state.messages.any(
          (item) => item.type == AiChatMessageType.ai && item.streaming,
        );
    return PageInitLoadingShell(
      loading: state.messagesLoading && state.messages.isEmpty,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            height: _conversationHeaderHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Text(
              _activeTitle(state),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.title16.copyWith(fontWeight: AppFont.w500),
            ),
          ),
          Expanded(
            child: state.messagesLoading && state.messages.isEmpty
                ? const SizedBox.shrink()
                : Listener(
                    // 用户手指压下 / 抬起时同步 _userTouchingList。压下后立刻把
                    // 还没执行完的「贴底滚动」级联取消，避免它在用户拖拽过程中
                    // 抢走 ScrollPosition 的 activity。
                    onPointerDown: (_) {
                      _userTouchingList = true;
                      _bottomScrollTimer?.cancel();
                    },
                    onPointerUp: (_) => _userTouchingList = false,
                    onPointerCancel: (_) => _userTouchingList = false,
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(
                        _mainHorizontalPadding,
                        28,
                        _mainHorizontalPadding,
                        20,
                      ),
                      itemCount:
                          state.messages.length +
                          (showWaitingAssistant ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == state.messages.length) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              '小美同学正在思考…',
                              style: AppText.body13.copyWith(color: _textHint),
                            ),
                          );
                        }
                        final message = state.messages[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: message.type == AiChatMessageType.user
                              ? _buildUserMessage(
                                  message: message,
                                  controller: controller,
                                  maxWidth: userBubbleMaxWidth,
                                )
                              : _buildAiMessage(
                                  message: message,
                                  controller: controller,
                                  maxWidth: aiBubbleMaxWidth,
                                ),
                        );
                      },
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _mainHorizontalPadding,
              0,
              _mainHorizontalPadding,
              _mainBottomPadding,
            ),
            child: _buildComposer(state, controller, composerWidth),
          ),
          _buildDisclaimer(),
          SizedBox(height: _conversationBottomInset),
        ],
      ),
    );
  }

  Widget _buildUserMessage({
    required AiChatMessage message,
    required AiChatController controller,
    required double maxWidth,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                color: _panelFill,
                borderRadius: AppRadius.br12,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s16,
                  vertical: AppSpace.s8,
                ),
                child: Text(message.text, style: AppText.body14),
              ),
            ),
            if (message.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final attachment in message.attachments)
                    _AttachmentChip(
                      attachment: attachment,
                      compact: true,
                      onTap: () => _previewAttachment(attachment),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpace.s4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionIcon(
                  asset: AppAssets.aiChatCopy,
                  label: '复制',
                  onTap: () => _copyText(message.text),
                ),
                _actionIcon(
                  asset: AppAssets.aiChatEdit,
                  label: '重新编辑',
                  onTap: () => _reuseText(message.text),
                ),
                if (message.status == AiChatMessageStatus.failed)
                  _actionIcon(
                    icon: Icons.refresh_rounded,
                    label: '重新发送',
                    color: AppColors.warning,
                    onTap: () async {
                      final error = await controller.resendMessage(message);
                      if (error != null && mounted) {
                        _showInfo(error);
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiMessage({
    required AiChatMessage message,
    required AiChatController controller,
    required double maxWidth,
  }) {
    final showAnswer = message.text.isNotEmpty || !message.reasoningStreaming;
    final answerStreaming = message.streaming && !message.reasoningStreaming;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.reasoning.isNotEmpty || message.reasoningStreaming) ...[
              AppPressable(
                onTap: () => controller.toggleReasoningExpanded(message.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppAssetGraphic(
                        AppAssets.aiChatThinkSelected,
                        width: 25,
                        height: 25,
                      ),
                      const SizedBox(width: AppSpace.s4),
                      Text(
                        message.reasoningStreaming
                            ? '深度思考中'
                            : message.reasoningExpanded
                            ? '思考过程（点击收起）'
                            : '思考过程（点击展开）',
                        style: AppText.body13.copyWith(
                          color: message.reasoningStreaming
                              ? _purple
                              : _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (message.reasoningExpanded) ...[
                const SizedBox(height: AppSpace.s4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: AppRadius.br12,
                    border: Border.all(
                      color: message.reasoningStreaming
                          ? AppColors.brandTint
                          : _border,
                    ),
                  ),
                  child: _MessageText(
                    message.reasoning,
                    streaming: message.reasoningStreaming,
                    placeholder: '正在思考',
                    muted: true,
                  ),
                ),
                const SizedBox(height: AppSpace.s8),
              ],
            ],
            if (showAnswer)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.br12,
                  border: Border.all(
                    color: answerStreaming ? AppColors.brandTint : _border,
                  ),
                ),
                child: _MessageText(
                  message.text,
                  streaming: answerStreaming,
                  placeholder: '正在回复',
                ),
              ),
            const SizedBox(height: AppSpace.s4),
            if (message.text.isNotEmpty && !message.streaming)
              _actionIcon(
                asset: AppAssets.aiChatCopy,
                label: '复制',
                onTap: () => _copyText(message.text),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon({
    IconData? icon,
    String? asset,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.textTertiary,
  }) {
    return AppPressable(
      semanticLabel: label,
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: asset == null
              ? Icon(icon, size: 16, color: color)
              : AppAssetGraphic(asset, width: 16, height: 16),
        ),
      ),
    );
  }

  Widget _buildComposer(
    AiChatState state,
    AiChatController controller,
    double width,
  ) {
    final canSend =
        !state.sending &&
        !state.uploadingAttachment &&
        (_inputCtrl.text.trim().isNotEmpty ||
            state.pendingAttachments.isNotEmpty);
    final hasAttachments = state.pendingAttachments.isNotEmpty;
    final inputInset = hasAttachments ? 4.0 : 8.0;
    return SizedBox(
      width: width,
      height: _composerHeight(state),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br12,
          border: Border.all(color: _border),
          boxShadow: const [
            BoxShadow(color: Color(0x050B081A), blurRadius: 1),
            BoxShadow(
              color: Color(0x0F0B081A),
              blurRadius: 40,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.br12,
          child: Column(
            children: [
              if (hasAttachments)
                SizedBox(
                  height: 50,
                  child: _buildAttachmentTray(state, controller),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: inputInset,
                  ),
                  child: AppTextField(
                    controller: _inputCtrl,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    cursorColor: _purple,
                    cursorWidth: 1.5,
                    cursorHeight: 16,
                    style: AppText.body14.copyWith(height: 1.6),
                    decoration: InputDecoration.collapsed(
                      hintText: '石膏头像的明暗交界线怎么画才有体积感？',
                      hintStyle: AppText.body14.copyWith(
                        color: _textHint,
                        height: 1.6,
                      ),
                    ),
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildModelSelector(state, controller),
                            const SizedBox(width: 8),
                            _AiFeatureButton(
                              label: '深度思考',
                              asset: state.isDeepThinking
                                  ? AppAssets.aiChatThinkSelected
                                  : AppAssets.aiChatThink,
                              selected: state.isDeepThinking,
                              onTap: state.selectedModel.supportsDeepThinking
                                  ? controller.toggleDeepThinking
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            _AiFeatureButton(
                              label: '联网搜索',
                              asset: state.isWebSearching
                                  ? AppAssets.aiChatSearchSelected
                                  : AppAssets.aiChatSearch,
                              iconSize: 15,
                              selected: state.isWebSearching,
                              onTap: state.selectedModel.supportsWebSearch
                                  ? controller.toggleWebSearching
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppPressable(
                      semanticLabel: '添加附件',
                      onTap: state.uploadingAttachment
                          ? null
                          : () => _pickAndUploadAttachment(controller),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border.all(color: _border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: state.uploadingAttachment
                            ? const AppLoadingIndicator(size: 18)
                            : const AppAssetGraphic(
                                AppAssets.aiChatAttach,
                                width: 20,
                                height: 20,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppPressable(
                      semanticLabel: '发送',
                      onTap: canSend ? () => _handleSend(controller) : null,
                      child: canSend
                          ? Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.brand,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const AppAssetGraphic(
                                AppAssets.aiChatSendArrow,
                                width: 12,
                                height: 12,
                              ),
                            )
                          : const AppAssetGraphic(
                              AppAssets.aiChatSendDisabled,
                              width: 32,
                              height: 32,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelSelector(AiChatState state, AiChatController controller) {
    return Builder(
      builder: (anchor) => AppPressable(
        semanticLabel: '切换模型，当前 ${state.selectedModel.label}',
        onTap: state.sending
            ? null
            : () async {
                final model = await showAppMenu<AiChatModel>(
                  context: anchor,
                  width: 132,
                  items: [
                    for (final model in AiChatModel.values)
                      AppMenuItem(
                        value: model,
                        label: model.label,
                        icon: model == state.selectedModel
                            ? Icons.check_rounded
                            : null,
                      ),
                  ],
                );
                if (!mounted || model == null) return;
                final error = await controller.selectModel(model);
                if (error != null && mounted) _showInfo(error);
              },
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: AppRadius.br8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.selectedModel.label,
                style: AppText.caption12Strong.copyWith(color: _textPrimary),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 17,
                color: _textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentTray(AiChatState state, AiChatController controller) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      scrollDirection: Axis.horizontal,
      itemCount: state.pendingAttachments.length,
      separatorBuilder: (context, index) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final attachment = state.pendingAttachments[index];
        return _AttachmentChip(
          attachment: attachment,
          onTap: () => _previewAttachment(attachment),
          onRemove: () => controller.removePendingAttachment(attachment),
        );
      },
    );
  }

  Widget _buildDisclaimer() {
    return Center(
      child: Text(
        '内容由模型生成，仅供参考；作品评价请以任课老师的意见为准',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.caption12,
      ),
    );
  }

  String _activeTitle(AiChatState state) {
    if (state.isNewConversation) {
      return '新对话';
    }
    final active = state.sessions
        .where((item) => item.id == state.activeSessionId)
        .firstOrNull;
    if (active == null || active.title.trim().isEmpty) {
      return '对话';
    }
    return active.title.trim();
  }

  void _handlePromptTap(String prompt) {
    _inputCtrl.text = prompt;
    _inputCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputCtrl.text.length),
    );
    setState(() {});
  }

  Future<void> _handleSend(AiChatController controller) async {
    final text = _inputCtrl.text.trim();
    final state = ref.read(aiChatControllerProvider);
    if (text.isEmpty && state.pendingAttachments.isEmpty) {
      return;
    }
    _inputCtrl.clear();
    setState(() {});

    final error = await controller.sendMessage(text);
    if (error != null && mounted) {
      _showInfo(error);
    }
  }

  Future<void> _pickAndUploadAttachment(AiChatController controller) async {
    final picked = await pickAiChatAttachmentFile();
    if (!mounted || picked == null) {
      return;
    }
    final error = await controller.uploadAttachment(
      bytes: picked.bytes,
      filename: picked.filename,
      size: picked.size,
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      _showInfo(error);
    }
  }

  void _previewAttachment(AiChatAttachment attachment) {
    if (attachment.url.trim().isEmpty) {
      _showInfo('附件地址为空');
      return;
    }
    if (_isImageAttachment(attachment)) {
      showImageGallery(
        context,
        images: [attachment.url],
        heroTagPrefix: 'ai_chat_attachment',
      );
      return;
    }

    final token = ref.read(appStorageProvider).token;
    showAppDialog<void>(
      context: context,
      builder: (context) =>
          _AttachmentPreviewDialog(attachment: attachment, authToken: token),
    );
  }

  bool _isImageAttachment(AiChatAttachment attachment) {
    final ext = _attachmentExtension(attachment);
    return const <String>{
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
    }.contains(ext);
  }

  String _attachmentExtension(AiChatAttachment attachment) {
    final source = attachment.name.trim().isNotEmpty
        ? attachment.name
        : Uri.tryParse(attachment.url)?.path ?? attachment.url;
    final normalized = source.split('?').first.split('#').first;
    final dot = normalized.lastIndexOf('.');
    if (dot < 0 || dot == normalized.length - 1) {
      return '';
    }
    return normalized.substring(dot + 1).toLowerCase();
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    _showInfo('已复制');
  }

  void _reuseText(String text) {
    _inputCtrl.text = text;
    _inputCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputCtrl.text.length),
    );
    setState(() {});
  }

  Future<void> _showSessionMoreMenu(
    BuildContext anchor,
    AiChatController controller,
    AiChatSession session,
  ) async {
    final action = await showAppMenu<String>(
      context: anchor,
      width: 142,
      items: const [
        AppMenuItem(
          value: 'delete',
          label: '删除',
          iconAsset: AppAssets.coursewareActionDelete,
          danger: true,
        ),
      ],
    );
    if (!mounted || action != 'delete') return;
    final confirmed = await showAppConfirm(
      context: context,
      title: '删除对话',
      message: '「${session.title}」的全部消息会被删除，且不可恢复。',
      danger: true,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final error = await controller.deleteSession(session);
    if (error != null && mounted) {
      _showInfo(error);
    }
  }

  void _showInfo(String message) {
    AppToast.show(context, message);
  }

  void _scheduleScrollIfNeeded(AiChatState state) {
    final latest = state.messages.isEmpty
        ? ''
        : '${state.messages.last.id}-${state.messages.last.status.name}'
              '-${state.messages.last.text.length}'
              '-${state.messages.last.reasoning.length}'
              '-${state.messages.last.streaming}';
    final signature =
        '${state.activeSessionId}-${state.messages.length}'
        '-${state.waitingAssistant}-${state.messagesLoading}-$latest';
    if (_messageSignature == signature) {
      return;
    }
    _messageSignature = signature;

    _scheduleBottomScroll();
  }

  void _scheduleBottomScroll({int attempt = 0}) {
    // 新一轮调度先把上一轮排队的 timer 干掉：原实现是 5 个递归 callback
    // 各自独立 schedule，会在 ~280ms 内连续触发 1 次 jumpTo + 4 次 animateTo。
    // 切换会话或流式推送时，这串「贴底动画」会接管 ScrollPosition，把用户
    // 第一次滑动产生的 DragScrollActivity 直接替换成 DrivenScrollActivity，
    // 表现就是「切换会话后第一次上滑没反应、得划第二次」。
    if (attempt == 0) {
      _bottomScrollTimer?.cancel();
      _bottomScrollTimer = null;
    }

    // 用户手指压在列表上时，绝不再驱动滚动，把 ScrollPosition 留给手势。
    if (_userTouchingList) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients || _userTouchingList) {
        return;
      }
      final max = _scrollCtrl.position.maxScrollExtent;
      // 后续几次「补偿性滚动」也用 jumpTo：它是同步设值、不会留下持续运行的
      // DrivenScrollActivity，所以即使紧接着用户开始滑动也不会被打断。
      _scrollCtrl.jumpTo(max);

      if (attempt < 3) {
        // 一共 4 次（初始 + 3 次补偿），覆盖图片/PDF/HTML 异步布局完成后
        // maxScrollExtent 增长的情况；间隔比原来更短一些以更快收敛。
        _bottomScrollTimer = Timer(
          Duration(milliseconds: attempt == 0 ? 32 : 64),
          () => _scheduleBottomScroll(attempt: attempt + 1),
        );
      } else {
        _bottomScrollTimer = null;
      }
    });
  }
}

class _AiPromptQuestion {
  const _AiPromptQuestion(this.indexLabel, this.text);

  final String indexLabel;
  final String text;
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.attachment,
    this.onTap,
    this.onRemove,
    this.compact = false,
  });

  final AiChatAttachment attachment;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final remove = onRemove;
    return AppPressable(
      onTap: onTap,
      semanticLabel: '预览附件 ${attachment.name}',
      child: Container(
        constraints: BoxConstraints(maxWidth: compact ? 220 : 260),
        padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
        decoration: BoxDecoration(
          color: compact ? AppColors.surface : const Color(0xFFF8F7FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.brandTint),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 11,
              backgroundColor: AppColors.brandTint,
              child: Icon(
                Icons.insert_drive_file_outlined,
                size: 14,
                color: _purple,
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption12Strong.copyWith(
                      color: _textPrimary,
                    ),
                  ),
                  if (!compact && attachment.size > 0)
                    Text(
                      _formatFileSize(attachment.size),
                      maxLines: 1,
                      style: AppText.caption12,
                    ),
                ],
              ),
            ),
            if (remove != null)
              AppPressable(
                semanticLabel: '移除附件',
                onTap: remove,
                child: const SizedBox.square(
                  dimension: 26,
                  child: Icon(Icons.close_rounded, size: 14, color: _textHint),
                ),
              )
            else
              const SizedBox(width: AppSpace.s4),
          ],
        ),
      ),
    );
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  }
}

class _AttachmentPreviewDialog extends StatelessWidget {
  const _AttachmentPreviewDialog({
    required this.attachment,
    required this.authToken,
  });

  final AiChatAttachment attachment;
  final String authToken;

  @override
  Widget build(BuildContext context) {
    final ext = _extension(attachment);
    final canPreviewPdf = ext == 'pdf';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 760,
            maxHeight: 620,
            minHeight: 420,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.all(Radius.circular(14)),
                boxShadow: AppShadow.overlay,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.brandTint,
                          child: Icon(
                            canPreviewPdf
                                ? Icons.picture_as_pdf_outlined
                                : Icons.insert_drive_file_outlined,
                            color: _purple,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                attachment.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body14.copyWith(
                                  fontWeight: AppFont.w600,
                                ),
                              ),
                              if (attachment.size > 0)
                                Text(
                                  _AttachmentChip._formatFileSize(
                                    attachment.size,
                                  ),
                                  style: AppText.caption12,
                                ),
                            ],
                          ),
                        ),
                        AppIconButton(
                          icon: Icons.close_rounded,
                          semanticLabel: '关闭',
                          size: AppButtonSize.sm,
                          filled: false,
                          color: _textSecondary,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: _border),
                  Expanded(
                    child: canPreviewPdf
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(14),
                            ),
                            child: AppPdfView(
                              url: attachment.url,
                              authToken: authToken,
                            ),
                          )
                        : _UnsupportedAttachmentPreview(attachment: attachment),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _extension(AiChatAttachment attachment) {
    final source = attachment.name.trim().isNotEmpty
        ? attachment.name
        : Uri.tryParse(attachment.url)?.path ?? attachment.url;
    final normalized = source.split('?').first.split('#').first;
    final dot = normalized.lastIndexOf('.');
    if (dot < 0 || dot == normalized.length - 1) {
      return '';
    }
    return normalized.substring(dot + 1).toLowerCase();
  }
}

class _UnsupportedAttachmentPreview extends StatelessWidget {
  const _UnsupportedAttachmentPreview({required this.attachment});

  final AiChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7FF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.brandTint),
              ),
              child: const Icon(
                Icons.insert_drive_file_outlined,
                color: _purple,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              attachment.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.body14Strong,
            ),
            const SizedBox(height: 8),
            Text('当前文件类型暂不支持在线预览', style: AppText.body13),
            const SizedBox(height: 14),
            SelectableText(
              attachment.url,
              textAlign: TextAlign.center,
              style: AppText.caption12.copyWith(color: _purple),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: '复制文件地址',
              icon: Icons.content_copy_outlined,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.sm,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: attachment.url));
                if (context.mounted) AppToast.showSuccess(context, '已复制文件地址');
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _AiToolKind { school, practice, plan }

class _AiToolShortcut {
  const _AiToolShortcut({
    required this.title,
    required this.subtitle,
    required this.prompt,
    required this.kind,
  });

  final String title;
  final String subtitle;
  final String prompt;
  final _AiToolKind kind;
}

class _AiToolBadge extends StatelessWidget {
  const _AiToolBadge({required this.colors, required this.child});

  final List<Color> colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: colors,
        ),
      ),
      child: child,
    );
  }
}

class _AiFeatureButton extends StatelessWidget {
  const _AiFeatureButton({
    required this.label,
    required this.asset,
    required this.selected,
    required this.onTap,
    this.iconSize = 20,
  });

  final String label;
  final String asset;
  final bool selected;
  final VoidCallback? onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      enabled: onTap != null,
      selected: selected,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandWash : AppColors.surface,
          border: Border.all(color: _border),
          borderRadius: AppRadius.br8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAssetGraphic(asset, width: iconSize, height: iconSize),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppText.caption12Strong.copyWith(
                color: selected ? _purple : _textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MessageBlockKind { paragraph, heading, list, quote }

class _MessageBlock {
  const _MessageBlock._({
    required this.kind,
    this.text = '',
    this.items = const [],
  });

  const _MessageBlock.paragraph(String text)
    : this._(kind: _MessageBlockKind.paragraph, text: text);

  const _MessageBlock.heading(String text)
    : this._(kind: _MessageBlockKind.heading, text: text);

  const _MessageBlock.list(List<_MessageListItem> items)
    : this._(kind: _MessageBlockKind.list, items: items);

  const _MessageBlock.quote(String text)
    : this._(kind: _MessageBlockKind.quote, text: text);

  final _MessageBlockKind kind;
  final String text;
  final List<_MessageListItem> items;
}

class _MessageListItem {
  const _MessageListItem({required this.marker, required this.text});

  final String marker;
  final String text;
}

class _MessageText extends StatelessWidget {
  const _MessageText(
    this.text, {
    this.streaming = false,
    this.placeholder = '正在回复',
    this.muted = false,
  });

  final String text;
  final bool streaming;
  final String placeholder;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);
    final baseStyle = AppText.body14.copyWith(
      color: muted ? _textSecondary : _textPrimary,
      height: 1.7,
    );

    if (blocks.isEmpty) {
      if (!streaming) {
        return const SizedBox.shrink();
      }
      return _TypingPlaceholder(label: placeholder, muted: muted);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < blocks.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == blocks.length - 1 ? 0 : 8,
            ),
            child: _buildBlock(
              blocks[index],
              baseStyle,
              streaming && index == blocks.length - 1,
            ),
          ),
      ],
    );
  }

  Widget _buildBlock(
    _MessageBlock block,
    TextStyle baseStyle,
    bool showCursor,
  ) {
    switch (block.kind) {
      case _MessageBlockKind.heading:
        return _InlineMessageText(
          block.text,
          style: AppText.title16.copyWith(
            color: muted ? _textSecondary : _textPrimary,
          ),
          streaming: showCursor,
        );
      case _MessageBlockKind.list:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < block.items.length; index++)
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        block.items[index].marker,
                        style: baseStyle.copyWith(color: _textSecondary),
                      ),
                    ),
                    Expanded(
                      child: _InlineMessageText(
                        block.items[index].text,
                        style: baseStyle,
                        streaming:
                            showCursor && index == block.items.length - 1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case _MessageBlockKind.quote:
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.brandTint, width: 3),
            ),
          ),
          child: _InlineMessageText(
            block.text,
            style: baseStyle.copyWith(color: _textSecondary),
            streaming: showCursor,
          ),
        );
      case _MessageBlockKind.paragraph:
        return _InlineMessageText(
          block.text,
          style: baseStyle,
          streaming: showCursor,
        );
    }
  }

  List<_MessageBlock> _parseBlocks(String source) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final blocks = <_MessageBlock>[];
    final paragraph = <String>[];
    final listItems = <_MessageListItem>[];
    final listRegExp = RegExp(r'^((?:[-*•])|(?:\d+[.)]))\s+(.+)$');
    final headingRegExp = RegExp(r'^(#{1,3})\s+(.+)$');

    void flushParagraph() {
      if (paragraph.isEmpty) {
        return;
      }
      final text = paragraph.join('\n').trim();
      if (text.isNotEmpty) {
        blocks.add(_MessageBlock.paragraph(text));
      }
      paragraph.clear();
    }

    void flushList() {
      if (listItems.isEmpty) {
        return;
      }
      blocks.add(_MessageBlock.list(List<_MessageListItem>.from(listItems)));
      listItems.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flushParagraph();
        flushList();
        continue;
      }

      final heading = headingRegExp.firstMatch(trimmed);
      if (heading != null) {
        flushParagraph();
        flushList();
        blocks.add(_MessageBlock.heading((heading.group(2) ?? '').trim()));
        continue;
      }

      final list = listRegExp.firstMatch(trimmed);
      if (list != null) {
        flushParagraph();
        final marker = list.group(1) ?? '•';
        final body = (list.group(2) ?? '').trim();
        listItems.add(
          _MessageListItem(
            marker: marker == '-' || marker == '*' ? '•' : marker,
            text: body,
          ),
        );
        continue;
      }

      if (trimmed.startsWith('>')) {
        flushParagraph();
        flushList();
        blocks.add(_MessageBlock.quote(trimmed.substring(1).trim()));
        continue;
      }

      flushList();
      paragraph.add(line.trimLeft());
    }

    flushParagraph();
    flushList();
    return blocks;
  }
}

class _InlineMessageText extends StatelessWidget {
  const _InlineMessageText(
    this.text, {
    required this.style,
    this.streaming = false,
  });

  final String text;
  final TextStyle style;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          ..._buildInlineSpans(text),
          if (streaming)
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(left: 3),
                child: _StreamingCursor(),
              ),
            ),
        ],
      ),
      softWrap: true,
      style: style,
    );
  }

  List<InlineSpan> _buildInlineSpans(String source) {
    final spans = <InlineSpan>[];
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final matches = RegExp(r'\*\*(.*?)\*\*').allMatches(line).toList();
      if (matches.isEmpty) {
        spans.add(TextSpan(text: line));
      } else {
        var cursor = 0;
        for (final match in matches) {
          if (match.start > cursor) {
            spans.add(TextSpan(text: line.substring(cursor, match.start)));
          }
          final boldText = match.group(1) ?? '';
          spans.add(
            TextSpan(
              text: boldText,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          );
          cursor = match.end;
        }
        if (cursor < line.length) {
          spans.add(TextSpan(text: line.substring(cursor)));
        }
      }
      if (lineIndex != lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    return spans;
  }
}

class _TypingPlaceholder extends StatelessWidget {
  const _TypingPlaceholder({required this.label, required this.muted});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppText.body14.copyWith(
            color: muted ? _textSecondary : _textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        const _TypingDots(),
      ],
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 3; index++)
              Opacity(
                opacity: _dotOpacity(value, index),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 1.5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _purple,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 4, height: 4),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  double _dotOpacity(double value, int index) {
    final shifted = (value + index * 0.18) % 1;
    if (shifted < 0.3) {
      return 0.35 + shifted / 0.3 * 0.65;
    }
    if (shifted < 0.6) {
      return 1 - (shifted - 0.3) / 0.3 * 0.55;
    }
    return 0.45;
  }
}

class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.35,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: 2,
        height: 17,
        decoration: BoxDecoration(
          color: _purple,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
