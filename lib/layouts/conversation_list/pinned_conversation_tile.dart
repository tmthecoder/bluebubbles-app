import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/indicator.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_marker.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_peek_view.dart';
import 'package:bluebubbles/layouts/conversation_list/pinned_tile_text_bubble.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reactions_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/typing_indicator.dart';
import 'package:bluebubbles/managers/chat/chat_controller.dart';
import 'package:bluebubbles/managers/chat/chat_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/message/message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;

class PinnedConversationTile extends StatefulWidget {
  final Chat chat;
  final List<PlatformFile> existingAttachments;
  final String? existingText;

  PinnedConversationTile({
    Key? key,
    required this.chat,
    this.existingAttachments = const [],
    this.existingText,
  }) : super(key: key);

  @override
  State<PinnedConversationTile> createState() => _PinnedConversationTileState();
}

class _PinnedConversationTileState extends State<PinnedConversationTile> {
  // Typing indicator
  RxBool showTypingIndicator = false.obs;
  RxBool shouldHighlight = false.obs;
  RxBool shouldPartialHighlight = false.obs;
  RxBool hoverHighlight = false.obs;

  @override
  void initState() {
    super.initState();

    if (kIsDesktop || kIsWeb) {
      shouldHighlight.value = ChatManager().activeChat?.chat.guid == widget.chat.guid;
    }

    // Listen for changes in the group
    MessageManager().stream.listen((NewMessageEvent event) async {
      // Make sure we have the required data to qualify for this tile
      if (event.chatGuid != widget.chat.guid) return;
      if (!event.event.containsKey("message")) return;
      // Make sure the message is a group event
      Message message = event.event["message"];
      if (!message.isGroupEvent()) return;

      // If it's a group event, let's fetch the new information and save it
      try {
        await ChatManager().fetchChat(widget.chat.guid);
      } catch (ex) {
        Logger.error(ex.toString());
      }

      setNewChatData(forceUpdate: true);
    });

    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'update-highlight' && mounted) {
        if ((kIsDesktop || kIsWeb) && event['data'] == widget.chat.guid) {
          shouldHighlight.value = true;
        } else if (shouldHighlight.value = true) {
          shouldHighlight.value = false;
        }
      }
    });
  }

  void setNewChatData({forceUpdate = false}) {
    // Save the current participant list and get the latest
    List<Handle> ogParticipants = widget.chat.participants;
    widget.chat.getParticipants();

    // Save the current title and generate the new one
    String? ogTitle = widget.chat.title;
    widget.chat.getTitle();

    // If the original data is different, update the state
    if (ogTitle != widget.chat.title || ogParticipants.length != widget.chat.participants.length || forceUpdate) {
      if (mounted) setState(() {});
    }
  }

  void onTapUp(details) {
    CustomNavigator.pushAndRemoveUntil(
      context,
      ConversationView(
        chat: widget.chat,
        existingAttachments: widget.existingAttachments,
        existingText: widget.existingText,
      ),
      (route) => route.isFirst,
    );
  }

  void onTapUpBypass() {
    onTapUp(TapUpDetails(kind: PointerDeviceKind.touch));
  }

  Widget buildSubtitle() {
    final hideInfo = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideContactInfo.value;
    final generateNames =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeContactNames.value;

    TextStyle style = context.theme.textTheme.bodyMedium!.apply(
        color: shouldHighlight.value
            ? context.theme.colorScheme.onBubble(context, widget.chat.isIMessage)
            : context.theme.colorScheme.outline);
    if (widget.chat.title == null) widget.chat.getTitle();
    if (widget.chat.title == null || kIsWeb || kIsDesktop) widget.chat.getTitle();
    String title = widget.chat.title ?? "Fake Person";

    if (generateNames) {
      title = widget.chat.fakeNames.length == 1 ? widget.chat.fakeNames[0] : "Group Chat";
    } else if (hideInfo) {
      style = style.copyWith(color: Colors.transparent);
    }

    return SizedBox(
      height: style.height! * style.fontSize! * 2,
      child: Align(
        alignment: Alignment.center,
        child: Text(
          title,
          style: style,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
      ),
    );
  }

  void onTap() {
    CustomNavigator.pushAndRemoveUntil(
      context,
      ConversationView(
        chat: widget.chat,
        existingAttachments: widget.existingAttachments,
        existingText: widget.existingText,
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    late Offset _tapPosition;

    return Container(
      margin: EdgeInsets.only(left: 7, right: 7, top: 1, bottom: 3),
      child: MouseRegion(
        onEnter: (event) => hoverHighlight.value = true,
        onExit: (event) => hoverHighlight.value = false,
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (details) {
            _tapPosition = details.globalPosition;
          },
          onTap: onTapUpBypass,
          onLongPress: () async {
            if (kIsDesktop || kIsWeb) return;
            await peekChat(context, widget.chat, _tapPosition);
          },
          onSecondaryTapUp: (details) async {
            if (kIsWeb) {
              (await html.document.onContextMenu.first).preventDefault();
            }
            shouldPartialHighlight.value = true;
            await showConversationTileMenu(
              context,
              this,
              widget.chat,
              details.globalPosition,
              context.textTheme,
            );
            shouldPartialHighlight.value = false;
          },
          child: Obx(
            () => AnimatedContainer(
              duration: Duration(milliseconds: 100),
              clipBehavior: Clip.none,
              padding: EdgeInsets.only(
                top: 4,
                left: 8,
                right: 8,
                bottom: 2,
              ),
              decoration: BoxDecoration(
                color: shouldPartialHighlight.value
                    ? context.theme.colorScheme.properSurface.lightenOrDarken(10)
                    : shouldHighlight.value
                        ? context.theme.colorScheme.bubble(context, widget.chat.isIMessage)
                        : hoverHighlight.value
                            ? context.theme.colorScheme.properSurface
                            : null,
                borderRadius: BorderRadius.circular(
                    shouldPartialHighlight.value || shouldHighlight.value || hoverHighlight.value ? 8 : 0),
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return Obx(
                    () {
                      // Great math right here
                      double availableWidth = constraints.maxWidth;
                      int colCount = kIsDesktop
                          ? SettingsManager().settings.pinColumnsLandscape.value
                          : SettingsManager().settings.pinColumnsPortrait.value;
                      double spaceBetween = (colCount - 1) * 30;
                      double maxWidth = max(((availableWidth - spaceBetween) / colCount).floorToDouble(), 0);

                      MessageMarkers? markers = ChatManager().getChatController(widget.chat)?.messageMarkers;
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxWidth,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: <Widget>[
                            Column(
                              children: [
                                Stack(
                                  children: <Widget>[
                                    ContactAvatarGroupWidget(
                                      chat: widget.chat,
                                      size: maxWidth,
                                      editable: false,
                                      onTap: onTapUpBypass,
                                    ),
                                    if (widget.chat.muteType != "mute" && (widget.chat.hasUnreadMessage ?? false))
                                      Positioned(
                                        left: sqrt(maxWidth) - maxWidth * 0.05 * sqrt(2),
                                        top: sqrt(maxWidth) - maxWidth * 0.05 * sqrt(2),
                                        child: Container(
                                          width: maxWidth * 0.2,
                                          height: maxWidth * 0.2,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(maxWidth * 0.1),
                                            color: context.theme.colorScheme.primary,
                                          ),
                                          margin: EdgeInsets.only(right: 3),
                                        ),
                                      ),
                                    if (widget.chat.muteType == "mute")
                                      Positioned(
                                        left: sqrt(maxWidth) - maxWidth * 0.05 * sqrt(2),
                                        top: sqrt(maxWidth) - maxWidth * 0.05 * sqrt(2),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: <Widget>[
                                            Container(
                                              width: maxWidth * 0.2,
                                              height: maxWidth * 0.2,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(maxWidth * 0.1),
                                                color: (widget.chat.hasUnreadMessage ?? false)
                                                    ? context.theme.colorScheme.primaryContainer
                                                    : context.theme.colorScheme.tertiaryContainer,
                                              ),
                                            ),
                                            Icon(
                                              CupertinoIcons.bell_slash_fill,
                                              size: maxWidth * 0.14,
                                              color: (widget.chat.hasUnreadMessage ?? false)
                                                  ? context.theme.colorScheme.onPrimaryContainer
                                                  : context.theme.colorScheme.onTertiaryContainer,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    vertical: maxWidth * 0.075,
                                  ),
                                  child: buildSubtitle(),
                                ),
                              ],
                            ),
                            StreamBuilder<Map<String, dynamic>>(
                              stream:
                                  ChatManager().getChatController(widget.chat)?.stream as Stream<Map<String, dynamic>>?,
                              builder: (BuildContext context, AsyncSnapshot snapshot) {
                                if (snapshot.connectionState == ConnectionState.active &&
                                    snapshot.hasData &&
                                    snapshot.data["type"] == ChatControllerEvent.TypingStatus) {
                                  showTypingIndicator.value = snapshot.data["data"];
                                }
                                return Obx(() {
                                  if (showTypingIndicator.value) {
                                    return Positioned(
                                      top: -sqrt(maxWidth / 2),
                                      right: -sqrt(maxWidth / 2) - maxWidth * 0.25,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(maxHeight: 32),
                                        child: FittedBox(
                                          child: TypingIndicator(
                                            visible: true,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  if (SettingsManager().settings.statusIndicatorsOnChats.value &&
                                      !widget.chat.isGroup() &&
                                      shouldShow(widget.chat.latestMessageGetter, markers?.myLastMessage.value,
                                              markers?.lastReadMessage.value, markers?.lastDeliveredMessage.value) !=
                                          Indicator.NONE) {
                                    return Positioned(
                                      left: sqrt(maxWidth) - maxWidth * 0.05 * sqrt(2),
                                      top: maxWidth - maxWidth * 0.13 * 2,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: <Widget>[
                                          Container(
                                            width: maxWidth * 0.27,
                                            height: maxWidth * 0.27,
                                            decoration: BoxDecoration(
                                              border: Border.all(color: context.theme.colorScheme.background, width: 1),
                                              borderRadius: BorderRadius.circular(30),
                                              color: context.theme.colorScheme.tertiaryContainer,
                                            ),
                                          ),
                                          Transform.rotate(
                                            angle: shouldShow(
                                                        widget.chat.latestMessage,
                                                        markers?.myLastMessage.value,
                                                        markers?.lastReadMessage.value,
                                                        markers?.lastDeliveredMessage.value) !=
                                                    Indicator.SENT
                                                ? pi / 2
                                                : 0,
                                            child: Icon(
                                              shouldShow(
                                                          widget.chat.latestMessage,
                                                          markers?.myLastMessage.value,
                                                          markers?.lastReadMessage.value,
                                                          markers?.lastDeliveredMessage.value) ==
                                                      Indicator.DELIVERED
                                                  ? CupertinoIcons.location_north_fill
                                                  : shouldShow(
                                                              widget.chat.latestMessage,
                                                              markers?.myLastMessage.value,
                                                              markers?.lastReadMessage.value,
                                                              markers?.lastDeliveredMessage.value) ==
                                                          Indicator.READ
                                                      ? CupertinoIcons.location_north
                                                      : CupertinoIcons.location_fill,
                                              color: context.theme.colorScheme.onTertiaryContainer,
                                              size: maxWidth * 0.14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return Container();
                                });
                              },
                            ),
                            Builder(
                              builder: (BuildContext context) {
                                if (!(widget.chat.hasUnreadMessage ?? false)) return Container();
                                if (showTypingIndicator.value) return Container();
                                Message? message = widget.chat.latestMessageGetter;
                                if ([null, ""].contains(message?.associatedMessageGuid) ||
                                    (message?.isFromMe ?? false)) {
                                  return Container();
                                }

                                return Positioned(
                                  top: -sqrt(maxWidth / 2),
                                  right: -sqrt(maxWidth / 2) - maxWidth * 0.15,
                                  child: ReactionsWidget(
                                    associatedMessages: [message!],
                                    bigPin: true,
                                    size: maxWidth * 0.3,
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              bottom: context.textTheme.bodyMedium!.fontSize! * 3,
                              width: maxWidth,
                              child: PinnedTileTextBubble(
                                chat: widget.chat,
                                size: maxWidth,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
