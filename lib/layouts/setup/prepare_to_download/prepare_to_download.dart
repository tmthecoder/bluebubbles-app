import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class PrepareToDownload extends StatefulWidget {
  PrepareToDownload({Key? key, required this.controller}) : super(key: key);
  final PageController controller;

  @override
  State<PrepareToDownload> createState() => _PrepareToDownloadState();
}

class _PrepareToDownloadState extends State<PrepareToDownload> {
  double numberOfMessages = 25;
  bool downloadAttachments = false;
  bool skipEmptyChats = true;
  bool saveToDownloads = false;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Scaffold(
        backgroundColor: context.theme.colorScheme.background,
        body: LayoutBuilder(
          builder: (context, size) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 80.0, left: 20.0, right: 20.0, bottom: 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: context.width * 2 / 3,
                                child: Text(
                                    "Sync Messages",
                                    style: context.theme.textTheme.displayMedium!.apply(
                                      fontWeightDelta: 2,
                                    ).copyWith(height: 1.35, color: context.theme.colorScheme.onBackground),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  "We will now download the first ${numberOfMessages == 1 ? "message" : "${numberOfMessages.toString().split(".").first} messages"} for each of your chats.\nYou can see more messages by simply scrolling up in the chat.",
                                  style: context.theme.textTheme.bodyLarge!.apply(
                                    fontSizeDelta: 1.5,
                                    color: context.theme.colorScheme.outline,
                                  ).copyWith(height: 2),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  "Note: If the syncing gets stuck, try reducing the number of messages to sync to 1.",
                                  style: context.theme.textTheme.bodyLarge!.apply(
                                    color: context.theme.colorScheme.outline,
                                  ).copyWith(height: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          color: context.theme.colorScheme.properSurface,
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Sync Options",
                                style: context.theme.textTheme.titleLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Number of Messages to Sync Per Chat: $numberOfMessages",
                                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface).copyWith(height: 1.5),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 10),
                            Slider(
                              value: numberOfMessages,
                              onChanged: (double value) {
                                if (!mounted) return;

                                setState(() {
                                  numberOfMessages = value == 0 ? 1 : value;
                                });
                              },
                              label: numberOfMessages == 0 ? "1" : numberOfMessages.toString(),
                              divisions: 10,
                              min: 0,
                              max: 50,
                            ),
                            SizedBox(height: 10),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Text(
                                    "Skip empty chats",
                                    style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface).copyWith(height: 1.5),
                                    textAlign: TextAlign.center,
                                  ),
                                  Switch(
                                    value: skipEmptyChats,
                                    activeColor: context.theme.colorScheme.primary,
                                    activeTrackColor: context.theme.colorScheme.primaryContainer,
                                    inactiveTrackColor: context.theme.colorScheme.onSurfaceVariant,
                                    inactiveThumbColor: context.theme.colorScheme.onBackground,
                                    onChanged: (bool value) {
                                      if (!mounted) return;

                                      setState(() {
                                        skipEmptyChats = value;
                                      });
                                    },
                                  )
                                ],
                              ),
                            ),
                            if (!kIsWeb)
                              SizedBox(height: 10),
                            if (!kIsWeb)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 40.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Text(
                                      "Save sync log to downloads",
                                      style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface).copyWith(height: 1.5),
                                      textAlign: TextAlign.center,
                                    ),
                                    Switch(
                                      value: saveToDownloads,
                                      activeColor: context.theme.colorScheme.primary,
                                      activeTrackColor: context.theme.colorScheme.primaryContainer,
                                      inactiveTrackColor: context.theme.colorScheme.onSurfaceVariant,
                                      inactiveThumbColor: context.theme.colorScheme.onBackground,
                                      onChanged: (bool value) async {
                                        if (!mounted) return;

                                        if (value) {
                                          var hasPermissions = await Permission.storage.isGranted;
                                          var permDenied = await Permission.storage.isPermanentlyDenied;

                                          // If we don't have the permission, but it isn't permanently denied, prompt the user
                                          if (!hasPermissions && !permDenied) {
                                            PermissionStatus response = await Permission.storage.request();
                                            hasPermissions = response.isGranted;
                                            permDenied = response.isPermanentlyDenied;
                                          }

                                          // If we still don't have the permission or we are permanently denied, show the snackbar error
                                          if (!hasPermissions || permDenied) {
                                            return showSnackbar("Error", "BlueBubbles does not have the required permissions!");
                                          } else {
                                            setState(() {
                                              saveToDownloads = value;
                                            });
                                          }
                                        } else {
                                          setState(() {
                                            saveToDownloads = value;
                                          });
                                        }
                                      },
                                    )
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: LinearGradient(
                            begin: AlignmentDirectional.topStart,
                            colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
                          ),
                        ),
                        height: 40,
                        child: ElevatedButton(
                          style: ButtonStyle(
                            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                            ),
                            backgroundColor: MaterialStateProperty.all(Colors.transparent),
                            shadowColor: MaterialStateProperty.all(Colors.transparent),
                            maximumSize: MaterialStateProperty.all(Size(context.width * 2 / 3, 36)),
                            minimumSize: MaterialStateProperty.all(Size(context.width * 2 / 3, 36)),
                          ),
                          onPressed: () {
                            // Set the number of messages to sync
                            SocketManager().setup.numberOfMessagesPerPage = numberOfMessages;
                            SocketManager().setup.skipEmptyChats = skipEmptyChats;
                            SocketManager().setup.saveToDownloads = saveToDownloads;

                            // Start syncing
                            SocketManager().setup.startFullSync(SettingsManager().settings);
                            widget.controller.nextPage(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.cloud_download,
                                color: Colors.white,
                              ),
                              SizedBox(width: 10),
                              Text(
                                  "Start Sync",
                                  style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}
