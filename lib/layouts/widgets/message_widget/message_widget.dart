import 'dart:io';
import 'dart:ui';

import 'package:bluebubble_messages/helpers/attachment_downloader.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/received_message.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/sent_message.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart';

import '../../../helpers/hex_color.dart';
import '../../../helpers/utils.dart';
import '../../../repository/models/message.dart';

class MessageWidget extends StatefulWidget {
  MessageWidget({
    Key key,
    this.fromSelf,
    this.message,
    this.olderMessage,
    this.newerMessage,
    this.reactions,
  }) : super(key: key);

  final fromSelf;
  final Message message;
  final Message newerMessage;
  final Message olderMessage;
  final List<Message> reactions;

  @override
  _MessageState createState() => _MessageState();
}

class _MessageState extends State<MessageWidget> {
  List<Attachment> attachments = <Attachment>[];
  String body;
  List chatAttachments = [];
  bool showTail = true;
  final String like = "like";
  final String love = "love";
  final String dislike = "dislike";
  final String question = "question";
  final String emphasize = "emphasize";
  final String laugh = "laugh";
  Map<String, List<Message>> reactions = new Map();
  Widget blurredImage;

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();

    reactions[like] = [];
    reactions[love] = [];
    reactions[dislike] = [];
    reactions[question] = [];
    reactions[emphasize] = [];
    reactions[laugh] = [];

    widget.reactions.forEach((reaction) {
      if (!reaction.isFromMe) {
        debugPrint(reaction.handle.toString());
      }
      reactions[reaction.associatedMessageType].add(reaction);
    });
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (widget.newerMessage != null) {
      showTail = withinTimeThreshold(widget.message, widget.newerMessage,
              threshold: 1) ||
          !sameSender(widget.message, widget.newerMessage);
    }

    // if (widget.message.hasAttachments) {
    Message.getAttachments(widget.message).then((data) {
      attachments = data;
      body = "";
      if (attachments.length > 0) {
        for (int i = 0; i < attachments.length; i++) {
          String appDocPath = SettingsManager().appDocDir.path;
          String pathName =
              "$appDocPath/${attachments[i].guid}/${attachments[i].transferName}";

          /**
           * Case 1: If the file exists (we can get the type), add the file to the chat's attachments
           * Case 2: If the attachment is currently being downloaded, get the AttachmentDownloader object and add it to the chat's attachments
           * Case 3: Otherwise, add the attachment, as is, meaning it needs to be downloaded
           */

          if (FileSystemEntity.typeSync(pathName) !=
              FileSystemEntityType.notFound) {
            chatAttachments.add(File(pathName));
          } else if (SocketManager()
              .attachmentDownloaders
              .containsKey(attachments[i].guid)) {
            chatAttachments.add(
                SocketManager().attachmentDownloaders[attachments[i].guid]);
          } else {
            chatAttachments.add(attachments[i]);
          }
        }
        if (this.mounted) setState(() {});
      }
    });
  }

  bool withinTimeThreshold(Message first, Message second, {threshold: 5}) {
    if (first == null || second == null) return false;
    return first.dateCreated.difference(second.dateCreated).inMinutes >
        threshold;
  }

  List<Widget> _buildContent() {
    List<Widget> content = <Widget>[];
    for (int i = 0; i < chatAttachments.length; i++) {
      // Pull the blurhash from the attachment, based on the class type
      String blurhash =
          chatAttachments[i] is Attachment ? chatAttachments[i].blurhash : null;
      blurhash = chatAttachments[i] is AttachmentDownloader
          ? chatAttachments[i].attachment.blurhash
          : null;

      // Convert the placeholder to a Widget
      Widget placeholder = (blurhash == null)
          ? Container()
          : FutureBuilder(
              future: blurHashDecode(blurhash),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.memory(
                      snapshot.data,
                      width: 300,
                      // height: 300,
                      fit: BoxFit.fitWidth,
                    ),
                  );
                } else {
                  return Container();
                }
              },
            );

      // If it's a file, it's already been downlaoded, so just display it
      if (chatAttachments[i] is File) {
        debugPrint(
            "mimetype " + mime(basename((chatAttachments[i] as File).path)));

        content.add(Stack(
          children: <Widget>[
            // TODO: This will not always be an image. need to check mimetype
            ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.file(chatAttachments[i])),

            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {},
                ),
              ),
            ),
          ],
        ));

        // If it's an attachment, then it needs to be manually downloaded
      } else if (chatAttachments[i] is Attachment) {
        content.add(
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              placeholder,
              RaisedButton(
                onPressed: () {
                  chatAttachments[i] =
                      new AttachmentDownloader(chatAttachments[i]);
                  setState(() {});
                },
                color: HexColor('26262a').withAlpha(100),
                child: Text(
                  "Download",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );

        // If it's an AttachmentDownloader, it is currently being downloaded
      } else if (chatAttachments[i] is AttachmentDownloader) {
        content.add(
          StreamBuilder(
            stream: chatAttachments[i].stream,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.hasError) {
                return Text(
                  "Error loading",
                  style: TextStyle(color: Colors.white),
                );
              }
              if (snapshot.data is File) {
                return InkWell(
                    onTap: () {
                      debugPrint("tap");
                    },
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.file(snapshot.data)));
              } else {
                double progress = 0.0;
                if (snapshot.hasData) {
                  progress = snapshot.data["Progress"];
                } else {
                  progress = chatAttachments[i].progress;
                }

                return Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    placeholder,
                    CircularProgressIndicator(
                      value: progress,
                    ),
                  ],
                );
              }
            },
          ),
        );
      } else {
        content.add(
          Text(
            "Error loading",
            style: TextStyle(color: Colors.white),
          ),
        );
      }
    }
    if (widget.message.text != null &&
        widget.message.text.length > 0 &&
        widget.message.text.substring(attachments.length).length > 0) {
      content.add(
        Text(
          widget.message.text.substring(attachments.length),
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      );
    }
    return content;
  }

  Widget _buildTimeStamp() {
    if (widget.olderMessage != null &&
        withinTimeThreshold(widget.message, widget.olderMessage,
            threshold: 30)) {
      DateTime timeOfolderMessage = widget.olderMessage.dateCreated;
      String time = new DateFormat.jm().format(timeOfolderMessage);
      String date;
      if (widget.olderMessage.dateCreated.isToday()) {
        date = "Today";
      } else if (widget.olderMessage.dateCreated.isYesterday()) {
        date = "Yesterday";
      } else {
        date =
            "${timeOfolderMessage.month.toString()}/${timeOfolderMessage.day.toString()}/${timeOfolderMessage.year.toString()}";
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "$date, $time",
              style: TextStyle(
                color: Colors.white,
              ),
            )
          ],
        ),
      );
    }
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fromSelf) {
      return SentMessage(
        content: _buildContent(),
        deliveredReceipt: _buildDelieveredReceipt(),
        message: widget.message,
        olderMessage: widget.olderMessage,
        overlayEntry: _createOverlayEntry(),
        showTail: showTail,
      );
    } else {
      return ReceivedMessage(
        timeStamp: _buildTimeStamp(),
        reactions: _buildReactions(),
        content: _buildContent(),
        showTail: showTail,
        olderMessage: widget.olderMessage,
        message: widget.message,
        overlayEntry: _createOverlayEntry(),
      );
    }
  }

  Widget _buildDelieveredReceipt() {
    if (!showTail) return Container();
    if (widget.message.dateRead != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              "Read",
              style: TextStyle(
                color: Colors.white,
              ),
            )
          ],
        ),
      );
    } else if (widget.message.dateDelivered != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              "Delivered",
              style: TextStyle(
                color: Colors.white,
              ),
            )
          ],
        ),
      );
    } else {
      return Container();
    }
  }

  Widget _buildReactions() {
    if (widget.reactions.length == 0) return Container();
    List<Widget> reactionIcon = <Widget>[];
    reactions.keys.forEach((String key) {
      if (reactions[key].length != 0) {
        reactionIcon.add(
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SvgPicture.asset(
              'assets/reactions/$key-black.svg',
              color: key == love ? Colors.pink : Colors.white,
            ),
          ),
        );
      }
    });
    return Stack(
      alignment: widget.message.isFromMe
          ? Alignment.bottomRight
          : Alignment.bottomLeft,
      children: <Widget>[
        for (int i = 0; i < reactionIcon.length; i++)
          Padding(
            padding: EdgeInsets.fromLTRB(i.toDouble() * 20.0, 0, 0, 0),
            child: Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: HexColor('26262a'),
                  boxShadow: [
                    new BoxShadow(
                      blurRadius: 5.0,
                      offset:
                          Offset(3.0 * (widget.message.isFromMe ? 1 : -1), 0.0),
                      color: Colors.black,
                    )
                  ]),
              child: reactionIcon[i],
            ),
          ),
      ],
    );
  }

  OverlayEntry _createOverlayEntry() {
    debugPrint(widget.message.hasAttachments.toString());
    List<Widget> reactioners = <Widget>[];
    reactions.keys.forEach(
      (element) {
        reactions[element].forEach(
          (reaction) async {
            if (reaction.handle != null) {
              reactioners.add(
                Text(
                  getContactTitle(
                      ContactManager().contacts, reaction.handle.address),
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              );
            }
          },
        );
      },
    );

    OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  debugPrint("remove entry");
                  entry.remove();
                },
                child: Container(
                  color: Colors.black.withAlpha(200),
                  child: Column(
                    children: <Widget>[
                      Spacer(
                        flex: 3,
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            height: 120,
                            width: MediaQuery.of(context).size.width * 9 / 5,
                            color: HexColor('26262a').withAlpha(200),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: reactioners,
                            ),
                          ),
                        ),
                      ),
                      Spacer(
                        flex: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return entry;
  }
}