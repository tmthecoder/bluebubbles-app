import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Map<String, IconData> iconMap = {
  'com.apple.Handwriting.HandwritingProvider': ss.settings.skin.value == Skins.iOS ? CupertinoIcons.square_pencil : Icons.brush,
  'com.apple.DigitalTouchBalloonProvider': ss.settings.skin.value == Skins.iOS ? CupertinoIcons.app_badge : Icons.touch_app
};

class BalloonBundleWidget extends StatefulWidget {
  BalloonBundleWidget({
    Key? key,
    required this.message,
  }) : super(key: key);
  final Message? message;

  @override
  State<BalloonBundleWidget> createState() => _BalloonBubbleState();
}

class _BalloonBubbleState extends State<BalloonBundleWidget> {
  late String bundleName;
  late IconData bundleIcon;

  @override
  void initState() {
    super.initState();

    bundleName = MessageHelper.getInteractiveText(widget.message!);
    bundleIcon = getIcon();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
      bundleName = MessageHelper.getInteractiveText(widget.message!);
      bundleIcon = getIcon();
    });
  }

  IconData getIcon() {
    if (widget.message!.balloonBundleId == null) return Icons.device_unknown;
    if (nameMap.containsKey(widget.message!.balloonBundleId)) {
      return iconMap[widget.message!.balloonBundleId!]!;
    }

    String val = widget.message!.balloonBundleId!.toLowerCase();
    if (val.contains("gamepigeon")) {
      return ss.settings.skin.value == Skins.iOS ? CupertinoIcons.gamecontroller : Icons.games;
    } else if (val.contains("contextoptional")) {
      return ss.settings.skin.value == Skins.iOS ? CupertinoIcons.device_phone_portrait : Icons.phone_android;
    } else if (val.contains("mobileslideshow")) {
      return ss.settings.skin.value == Skins.iOS ? CupertinoIcons.play_rectangle : Icons.slideshow;
    } else if (val.contains("peerpayment")) {
      return ss.settings.skin.value == Skins.iOS ? CupertinoIcons.money_dollar_circle : Icons.monetization_on;
    }

    return ss.settings.skin.value == Skins.iOS ? CupertinoIcons.square_grid_3x2 : Icons.apps;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 13.0, right: widget.message!.isFromMe! ? 0 : 13, left: widget.message!.isFromMe! ? 13 : 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
            constraints: BoxConstraints(
              maxWidth: ns.width(context) * 3 / 4,
            ),
            child: Container(
              width: 200,
              color: context.theme.colorScheme.properSurface,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(bundleName,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.titleLarge),
                    Text("Interactive Message",
                        textAlign: TextAlign.center, maxLines: 1, style: context.theme.textTheme.bodyMedium),
                    Container(height: 10.0),
                    Icon(bundleIcon, color: context.theme.colorScheme.properOnSurface, size: 48),
                    Container(height: 10.0),
                    Text("(Cannot open on Android)",
                        textAlign: TextAlign.center, maxLines: 1, style: context.theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            )),
      ),
    );
  }
}