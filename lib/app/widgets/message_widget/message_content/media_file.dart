import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MediaFile extends StatefulWidget {
  MediaFile({
    Key? key,
    required this.child,
    required this.attachment,
  }) : super(key: key);
  final Widget child;
  final Attachment attachment;

  @override
  State<MediaFile> createState() => _MediaFileState();
}

class _MediaFileState extends State<MediaFile> {
  @override
  void initState() {
    super.initState();
    /*socket.attachmentSenderCompleter.listen((event) {
      if (event == widget.attachment.guid && mounted) {
        setState(() {});
      }
    });*/
  }

  @override
  Widget build(BuildContext context) {
    final bool hideAttachments = ss.settings.redactedMode.value && ss.settings.hideAttachments.value;
    final bool hideAttachmentTypes =
        ss.settings.redactedMode.value && ss.settings.hideAttachmentTypes.value;

    /*if (socket.attachmentSenders.containsKey(widget.attachment.guid)) {
      return Stack(
        alignment: Alignment.center,
        children: <Widget>[
          widget.child,
          Obx(() {
            Tuple2<num?, bool> data = socket.attachmentSenders[widget.attachment.guid]!.attachmentData.value;
            if (data.item2) {
              return Text(
                "Unable to send",
                style: context.theme.textTheme.bodyLarge,
              );
            }

            return Container(
                height: 40,
                width: 40,
                child: CircleProgressBar(
                    backgroundColor: context.theme.colorScheme.outline,
                    foregroundColor: context.theme.colorScheme.properOnSurface,
                    value: data.item1?.toDouble() ?? 0));
          }),
        ],
      );
    } else {*/
      return Stack(alignment: Alignment.center, children: [
        widget.child,
        if (widget.attachment.originalROWID == null)
          Container(
            child: ss.settings.skin.value == Skins.iOS ? Theme(
              data: ThemeData(
                cupertinoOverrideTheme: CupertinoThemeData(brightness: Brightness.dark),
              ),
              child: CupertinoActivityIndicator(
                radius: 10,
              ),
            ) : Container(height: 20, width: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2,))),
            height: 45,
            width: 45,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(10)), color: Colors.black.withOpacity(0.5)),
          ),
        if (hideAttachments)
          Positioned.fill(
            child: Container(
              color: context.theme.colorScheme.properSurface,
            ),
          ),
        if (hideAttachments && !hideAttachmentTypes)
          Positioned.fill(
            child: Container(
              alignment: Alignment.center,
              child: Text(
                widget.attachment.mimeType!,
                textAlign: TextAlign.center,
                style: context.theme.textTheme.bodyLarge,
              ),
            ),
          ),
      ]);
   /* }*/
  }
}