import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/ui/ui_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/widgets/components/circle_progress_bar.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/attachment_downloader_widget.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/media_file.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/media_players/contact_widget.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/media_players/image_widget.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/media_players/regular_file_opener.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/media_players/video_widget.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'media_players/desktop_video_widget.dart';

class MessageAttachment extends StatefulWidget {
  MessageAttachment({
    Key? key,
    required this.attachment,
    required this.updateAttachment,
    required this.isFromMe,
  }) : super(key: key);
  final Attachment attachment;
  final Function() updateAttachment;
  final bool isFromMe;

  @override
  MessageAttachmentState createState() => MessageAttachmentState();
}

class MessageAttachmentState extends State<MessageAttachment> with AutomaticKeepAliveClientMixin {
  Widget? attachmentWidget;
  dynamic content;

  @override
  void initState() {
    super.initState();
    updateContent();

    ever(attachmentDownloader.downloaders, (List<String> downloaders) {
      if (downloaders.contains(widget.attachment.guid)) {
        if (mounted) setState(() {});
      }
    });
  }

  void updateContent() async {
    // Ge the current attachment content (status)
    content = as.getContent(widget.attachment,
        path: widget.attachment.guid == "redacted-mode-demo-attachment" ||
                widget.attachment.guid!.contains("theme-selector")
            ? widget.attachment.transferName
            : null);

    // If we can download it, do so
    if (await as.canAutoDownload() && content is Attachment) {
      if (mounted) {
        setState(() {
          content = attachmentDownloader.startDownload(content);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    updateContent();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: ns.width(context) * 0.5,
          maxHeight: context.height * 0.6,
        ),
        child: _buildAttachmentWidget(),
      ),
    );
  }

  Widget _buildAttachmentWidget() {
    // If it's a file, it's already been downlaoded, so just display it
    if (content is PlatformFile) {
      String? mimeType = widget.attachment.mimeType;
      if (mimeType != null) mimeType = mimeType.substring(0, mimeType.indexOf("/"));
      if (mimeType == "image") {
        return MediaFile(
          attachment: widget.attachment,
          child: ImageWidget(
            file: content,
            attachment: widget.attachment,
          ),
        );
      } else if (mimeType == "video") {
        if (kIsDesktop) {
          return MediaFile(
            attachment: widget.attachment,
            child: RegularFileOpener(
              file: content,
              attachment: widget.attachment,
            ),
          );
        }
        return MediaFile(
          attachment: widget.attachment,
          child: kIsDesktop
              ? DesktopVideoWidget(
                  attachment: widget.attachment,
                  file: content,
                )
              : VideoWidget(
                  attachment: widget.attachment,
                  file: content,
                ),
        );
      } else if (mimeType == "audio" && !widget.attachment.mimeType!.contains("caf")) {
        return MediaFile(
          attachment: widget.attachment,
          child: AudioPlayerWidget(
              file: content, context: context, width: kIsDesktop ? null : 250, isFromMe: widget.isFromMe),
        );
      } else if (widget.attachment.mimeType == "text/x-vlocation" || widget.attachment.uti == 'public.vlocation') {
        /*return MediaFile(
          attachment: widget.attachment,
          child: UrlPreviewWidget(
            linkPreviews: [],
            mess
          ),
        );*/
        return const SizedBox.shrink();
      } else if (widget.attachment.mimeType == "text/vcard") {
        return MediaFile(
          attachment: widget.attachment,
          child: ContactWidget(
            file: content,
            attachment: widget.attachment,
          ),
        );
      } else if (widget.attachment.mimeType == null) {
        return Container();
      } else {
        return MediaFile(
          attachment: widget.attachment,
          child: RegularFileOpener(
            file: content,
            attachment: widget.attachment,
          ),
        );
      }

      // If it's an attachment, then it needs to be manually downloaded
    } else if (content is Attachment) {
      return AttachmentDownloaderWidget(
        onPressed: () {
          content = attachmentDownloader.startDownload(content);
          if (mounted) setState(() {});
        },
        attachment: content,
        placeHolder: buildPlaceHolder(widget),
      );

      // If it's an AttachmentDownloader, it is currently being downloaded
    } else if (content is AttachmentDownloadController) {
      if (widget.attachment.mimeType == null) return Container();
      return Obx(() {
        // If there is an error, return an error text
        if (content.error.value) {
          content = widget.attachment;
          return AttachmentDownloaderWidget(
            onPressed: () {
              content = attachmentDownloader.startDownload(content);
              if (mounted) setState(() {});
            },
            attachment: content,
            placeHolder: buildPlaceHolder(widget),
          );
        }

        // If the snapshot data is a file, we have finished downloading
        if (content.file.value != null) {
          content = content.file.value;
          return _buildAttachmentWidget();
        }

        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            buildPlaceHolder(widget),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Center(
                      child: Container(
                        height: 40,
                        width: 40,
                        child: CircleProgressBar(
                          value: content.progress.value?.toDouble() ?? 0,
                          backgroundColor: context.theme.colorScheme.outline,
                          foregroundColor: context.theme.colorScheme.properOnSurface,
                        ),
                      ),
                    ),
                    ((content as AttachmentDownloadController).attachment.mimeType != null)
                        ? Container(height: 5.0)
                        : Container(),
                    (content.attachment.mimeType != null)
                        ? Container(
                            height: 50,
                            alignment: Alignment.center,
                            child: Text(
                              content.attachment.mimeType,
                              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        : Container()
                  ],
                ),
              ],
            ),
          ],
        );
      });
    } else {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          "Error loading",
          style: context.theme.textTheme.bodyLarge,
        ),
      );
      //     return Container();
    }
  }

  Widget buildPlaceHolder(MessageAttachment parent) {
    return buildImagePlaceholder(context, widget.attachment, Container());
  }

  @override
  bool get wantKeepAlive => true;
}