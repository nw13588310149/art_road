import 'package:flutter/material.dart';

/// 项目内 [TextField] / [EditableText] 统一的上下文菜单构建器。
///
/// - 去除 iOS「Scan Text / 扫描文本」(Live Text) 入口。
/// - 在支持系统菜单时仍使用 [SystemContextMenu]，但过滤 Live Text 项。
class AppEditableContextMenu {
  AppEditableContextMenu._();

  static Widget builder(BuildContext context, EditableTextState editableTextState) {
    if (SystemContextMenu.isSupportedByField(editableTextState)) {
      final items = SystemContextMenu.getDefaultItems(editableTextState)
          .where((item) => item is! IOSSystemContextMenuItemLiveText)
          .toList();
      return SystemContextMenu.editableText(
        editableTextState: editableTextState,
        items: items,
      );
    }

    final buttonItems = editableTextState.contextMenuButtonItems
        .where((item) => item.type != ContextMenuButtonType.liveTextInput)
        .toList();

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }
}
