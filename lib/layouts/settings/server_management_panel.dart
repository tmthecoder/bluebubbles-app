import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/layouts/setup/qr_code_scanner.dart';
import 'package:bluebubbles/layouts/setup/qr_scan/text_input_url.dart';
import 'package:bluebubbles/managers/firebase/fcm_manager.dart';
import 'package:bluebubbles/managers/message/message_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:firebase_dart/firebase_dart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import 'package:version/version.dart';

class ServerManagementPanelController extends GetxController {
  final RxnInt latency = RxnInt();
  final RxnString fetchStatus = RxnString();
  final RxnString serverVersion = RxnString();
  final RxnString macOSVersion = RxnString();
  final RxnString iCloudAccount = RxnString();
  final RxnInt serverVersionCode = RxnInt();
  final RxBool privateAPIStatus = RxBool(false);
  final RxBool helperBundleStatus = RxBool(false);
  final RxnString proxyService = RxnString();
  final RxMap<String, dynamic> stats = RxMap({});

  // Restart trackers
  int? lastRestart;
  int? lastRestartMessages;
  int? lastRestartPrivateAPI;
  final RxBool isRestarting = false.obs;
  final RxBool isRestartingMessages = false.obs;
  final RxBool isRestartingPrivateAPI = false.obs;
  final RxDouble opacity = 1.0.obs;

  late Settings _settingsCopy;
  FCMData? _fcmDataCopy;

  @override
  void onInit() {
    _settingsCopy = SettingsManager().settings;
    _fcmDataCopy = SettingsManager().fcmData;
    if (SocketManager().state.value == SocketState.CONNECTED) {
      getServerStats();
    }
    super.onInit();
  }

  void getServerStats() {
    int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    api.serverInfo().then((response) {
      int later = DateTime.now().toUtc().millisecondsSinceEpoch;
      latency.value = later - now;
      macOSVersion.value = response.data['data']['os_version'];
      serverVersion.value = response.data['data']['server_version'];
      Version version = Version.parse(serverVersion.value!);
      serverVersionCode.value = version.major * 100 + version.minor * 21 + version.patch;
      privateAPIStatus.value = response.data['data']['private_api'] ?? false;
      helperBundleStatus.value = response.data['data']['helper_connected'] ?? false;
      proxyService.value = response.data['data']['proxy_service'];
      iCloudAccount.value = response.data['data']['detected_icloud'];

      api.serverStatTotals().then((response) {
        if (response.data['status'] == 200) {
          stats.addAll(response.data['data'] ?? {});
          api.serverStatMedia().then((response) {
            if (response.data['status'] == 200) {
              stats.addAll(response.data['data'] ?? {});
            }
          });
        }
        opacity.value = 1.0;
      }).catchError((_) {
        showSnackbar("Error", "Failed to load server statistics!");
        opacity.value = 1.0;
      });
    }).catchError((_) {
      showSnackbar("Error", "Failed to load server details!");
    });
  }

  void saveSettings() async {
    await SettingsManager().saveSettings(_settingsCopy);
  }

  @override
  void dispose() {
    saveSettings();
    super.dispose();
  }
}

class ServerManagementPanel extends StatelessWidget {
  final controller = Get.put(ServerManagementPanelController());

  @override
  Widget build(BuildContext context) {
    final iosSubtitle =
    context.theme.textTheme.labelLarge?.copyWith(color: ThemeManager().inDarkMode(context) ? context.theme.colorScheme.onBackground : context.theme.colorScheme.properOnSurface, fontWeight: FontWeight.w300);
    final materialSubtitle = context.theme
        .textTheme
        .labelLarge
        ?.copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold);
    // Samsung theme should always use the background color as the "header" color
    Color headerColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.background : context.theme.colorScheme.properSurface;
    Color tileColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background;
    
    // reverse material color mapping to be more accurate
    if (SettingsManager().settings.skin.value == Skins.Material && ThemeManager().inDarkMode(context)) {
      final temp = headerColor;
      headerColor = tileColor;
      tileColor = temp;
    }

    // These Rx variables are only needed in widgets not contained in settings_widgets.dart
    final Rx<Color> _headerColor = (SettingsManager().settings.windowEffect.value == WindowEffect.disabled ? headerColor : Colors.transparent).obs;
    final Rx<Color> _tileColor = (SettingsManager().settings.windowEffect.value == WindowEffect.disabled ? tileColor : Colors.transparent).obs;

    if (kIsDesktop) {
      SettingsManager().settings.windowEffect.listen((WindowEffect effect) {
        _headerColor.value = effect != WindowEffect.disabled ? Colors.transparent : headerColor;
        _tileColor.value = effect != WindowEffect.disabled ? Colors.transparent : tileColor;
      });
    }

    return SettingsScaffold(
      title: "Connection & Server Management",
      initialHeader: "Connection & Server Details",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            <Widget>[
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(() {
                    bool redact = SettingsManager().settings.redactedMode.value;
                    return Container(
                        color: _tileColor.value,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                          child: AnimatedOpacity(
                            duration: Duration(milliseconds: 300),
                            opacity: controller.opacity.value,
                            child: SelectableText.rich(
                              TextSpan(
                                  children: [
                                    TextSpan(text: "Connection Status: "),
                                    TextSpan(text: describeEnum(SocketManager().state.value), style: TextStyle(color: getIndicatorColor(SocketManager().state.value))),
                                    TextSpan(text: "\n\n"),
                                    if ((controller.serverVersionCode.value ?? 0) >= 42)
                                      TextSpan(text: "Private API Status: "),
                                    if ((controller.serverVersionCode.value ?? 0) >= 42)
                                      TextSpan(text: controller.privateAPIStatus.value ? "ENABLED" : "DISABLED", style: TextStyle(color: getIndicatorColor(controller.privateAPIStatus.value
                                          ? SocketState.CONNECTED
                                          : SocketState.DISCONNECTED))),
                                    if ((controller.serverVersionCode.value ?? 0) >= 42)
                                      TextSpan(text: "\n\n"),
                                    if ((controller.serverVersionCode.value ?? 0) >= 42)
                                      TextSpan(text: "Private API Helper Bundle Status: "),
                                    if ((controller.serverVersionCode.value ?? 0) >= 42)
                                      TextSpan(text: controller.helperBundleStatus.value ? "CONNECTED" : "DISCONNECTED", style: TextStyle(color: getIndicatorColor(controller.helperBundleStatus.value
                                          ? SocketState.CONNECTED
                                          : SocketState.DISCONNECTED))),
                                    if ((controller.serverVersionCode.value ?? 0) >= 42)
                                      TextSpan(text: "\n\n"),
                                    TextSpan(text: "Server URL: ${redact ? "Redacted" : controller._settingsCopy.serverAddress.value}", recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        Clipboard.setData(ClipboardData(text: controller._settingsCopy.serverAddress.value));
                                        showSnackbar('Copied', "Address copied to clipboard");
                                      }),
                                    TextSpan(text: "\n\n"),
                                    TextSpan(text: "Latency: ${redact ? "Redacted" : ("${controller.latency.value ?? "N/A"} ms")}"),
                                    TextSpan(text: "\n\n"),
                                    TextSpan(text: "Server Version: ${redact ? "Redacted" : (controller.serverVersion.value ?? "N/A")}"),
                                    TextSpan(text: "\n\n"),
                                    TextSpan(text: "macOS Version: ${redact ? "Redacted" : (controller.macOSVersion.value ?? "N/A")}"),
                                    if (controller.iCloudAccount.value != null)
                                      TextSpan(text: "\n\n"),
                                    if (controller.iCloudAccount.value != null)
                                      TextSpan(text: "iCloud Account: ${redact ? "Redacted" : controller.iCloudAccount.value}"),
                                    TextSpan(text: "\n\n"),
                                    TextSpan(text: "Tap to update values...", style: TextStyle(fontStyle: FontStyle.italic)),
                                  ]
                              ),
                              onTap: () {
                                if (SocketManager().state.value != SocketState.CONNECTED) return;
                                controller.opacity.value = 0.0;
                                controller.getServerStats();
                              },
                            ),
                          ),
                        )
                    );
                  }),
                  Obx(() => (controller.serverVersionCode.value ?? 0) >= 42  && controller.stats.isNotEmpty ? SettingsTile(
                    title: "Show Stats",
                    subtitle: "Show iMessage statistics",
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.chart_bar_square,
                      materialIcon: Icons.stacked_bar_chart,
                    ),
                    onTap: () {
                      showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: context.theme.colorScheme.properSurface,
                            content: Padding(
                              padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                              child: SelectableText.rich(
                                TextSpan(
                                    children: controller.stats.entries.map((e) => TextSpan(text: "${e.key.capitalizeFirst!.replaceAll("Handles", "iMessage Numbers")}: ${e.value}${controller.stats.keys.last != e.key ? "\n\n" : ""}")).toList()
                                ),
                                style: context.theme.textTheme.bodyLarge,
                              ),
                            ),
                            title: Text("Stats", style: context.theme.textTheme.titleLarge),
                            actions: <Widget>[
                              TextButton(
                                child: Text("Dismiss", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          )
                      );
                    },
                  ) : SizedBox.shrink()),
                  Obx(() => (controller.serverVersionCode.value ?? 0) >= 42
                      && controller.stats.isNotEmpty
                      && SettingsManager().fcmData != null ? Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ) : SizedBox.shrink()),
                  if (SettingsManager().fcmData != null)
                    SettingsTile(
                      title: "Show QR Code",
                      subtitle: "Generate QR Code to screenshot or sync other devices",
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.qrcode,
                        materialIcon: Icons.qr_code,
                      ),
                      onTap: () {
                        List<dynamic> json = [
                          SettingsManager().settings.guidAuthKey.value,
                          SettingsManager().settings.serverAddress.value,
                          SettingsManager().fcmData!.projectID,
                          SettingsManager().fcmData!.storageBucket,
                          SettingsManager().fcmData!.apiKey,
                          SettingsManager().fcmData!.firebaseURL,
                          SettingsManager().fcmData!.clientID,
                          SettingsManager().fcmData!.applicationID,
                        ];
                        String qrtext = jsonEncode(json);
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: context.theme.colorScheme.properSurface,
                              content: Container(
                                height: 320,
                                width: 320,
                                child: QrImageView(
                                  data: qrtext,
                                  version: QrVersions.auto,
                                  size: 320,
                                  gapless: true,
                                  backgroundColor: context.theme.colorScheme.properSurface,
                                  foregroundColor: context.theme.colorScheme.properOnSurface,
                                ),
                              ),
                              title: Text("QR Code", style: context.theme.textTheme.titleLarge),
                              actions: <Widget>[
                                TextButton(
                                  child: Text("Dismiss", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            )
                        );
                      },
                    ),
                ],
              ),
              SettingsHeader(
                  headerColor: headerColor,
                  tileColor: tileColor,
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "Connection & Sync"
              ),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  /*Obx(() {
                    if (controller.proxyService.value != null && SettingsManager().settings.skin.value == Skins.iOS)
                      return Container(
                        decoration: BoxDecoration(
                          color: tileColor,
                        ),
                        padding: EdgeInsets.only(left: 15, top: 5),
                        child: Text("Select Proxy Service"),
                      );
                    else return SizedBox.shrink();
                  }),
                  Obx(() => controller.proxyService.value != null ? SettingsOptions<String>(
                    title: "Proxy Service",
                    options: ["Ngrok", "LocalTunnel", "Dynamic DNS"],
                    initial: controller.proxyService.value!,
                    capitalize: false,
                    textProcessing: (val) => val,
                    onChanged: (val) async {
                      String? url;
                      if (val == "Dynamic DNS") {
                        TextEditingController controller = TextEditingController();
                        await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              actions: [
                                TextButton(
                                  child: Text("OK"),
                                  onPressed: () async {
                                    if (!controller.text.isURL) {
                                      showSnackbar("Error", "Please enter a valid URL");
                                      return;
                                    }
                                    url = controller.text;
                                    Get.back();
                                  },
                                ),
                                TextButton(
                                  child: Text("Cancel"),
                                  onPressed: () {
                                    Get.back();
                                  },
                                )
                              ],
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: controller,
                                    decoration: InputDecoration(
                                      labelText: "Server Address",
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ),
                              title: Text("Enter Server Address"),
                            )
                        );
                        if (url == null) return;
                      }
                      var res = await SocketManager().sendMessage("change-proxy-service", {"service": val}, (_) {});
                      if (res['status'] == 200) {
                        controller.proxyService.value = val;
                        await Future.delayed(Duration(seconds: 2));
                        await SocketManager().refreshConnection();
                        controller.opacity.value = 0.0;
                        int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                        SocketManager().sendMessage("get-server-metadata", {}, (Map<String, dynamic> res) {
                          int later = DateTime.now().toUtc().millisecondsSinceEpoch;
                          controller.latency.value = later - now;
                          controller.macOSVersion.value = res['data']['os_version'];
                          controller.serverVersion.value = res['data']['server_version'];
                          controller.privateAPIStatus.value = res['data']['private_api'];
                          controller.helperBundleStatus.value = res['data']['helper_connected'];
                          controller.proxyService.value = res['data']['proxy_service'];
                          controller.opacity.value = 1.0;
                        });
                      }
                    },
                    backgroundColor: tileColor,
                    secondaryColor: headerColor,
                  ) : SizedBox.shrink()),
                  Obx(() => controller.proxyService.value != null && !kIsWeb ? Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ) : SizedBox.shrink()),*/
                  SettingsTile(
                    title: "Re-configure with BlueBubbles Server",
                    subtitle: kIsWeb || kIsDesktop ? "Click for manual entry" : "Tap to scan QR code\nLong press for manual entry",
                    isThreeLine: kIsWeb || kIsDesktop ? false : true,
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.gear,
                      materialIcon: Icons.room_preferences,
                    ),
                    onLongPress: kIsWeb || kIsDesktop ? null : () {
                      showDialog(
                        context: context,
                        builder: (connectContext) => TextInputURL(
                          onConnect: () {
                            Get.back();
                            fcm.registerDevice();
                            SocketManager()
                                .startSocketIO(forceNewConnection: true);
                          },
                          onClose: () {
                            Get.back();
                          },
                        ),
                      );
                    },
                    onTap: kIsWeb || kIsDesktop ? () {
                      showDialog(
                        context: context,
                        builder: (connectContext) => TextInputURL(
                          onConnect: () {
                            Get.back();
                            fcm.registerDevice();
                            SocketManager()
                                .startSocketIO(forceNewConnection: true);
                          },
                          onClose: () {
                            Get.back();
                          },
                        ),
                      );
                    } : () async {
                      List<dynamic>? fcmData;
                      try {
                        fcmData = jsonDecode(
                          await Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (BuildContext context) {
                                return QRCodeScanner();
                              },
                            ),
                          ),
                        );
                      } catch (e) {
                        return;
                      }
                      if (fcmData != null && fcmData[0] != null && sanitizeServerAddress(address: fcmData[1]) != null) {
                        controller._fcmDataCopy = FCMData(
                          projectID: fcmData[2],
                          storageBucket: fcmData[3],
                          apiKey: fcmData[4],
                          firebaseURL: fcmData[5],
                          clientID: fcmData[6],
                          applicationID: fcmData[7],
                        );
                        controller._settingsCopy.guidAuthKey.value = fcmData[0];
                        controller._settingsCopy.serverAddress.value = sanitizeServerAddress(address: fcmData[1])!;

                        SettingsManager().saveSettings(controller._settingsCopy);
                        SettingsManager().saveFCMData(controller._fcmDataCopy!);
                        fcm.registerDevice();
                      }
                    },
                  ),
                  if (!kIsWeb)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb)
                    Obx(() {
                      String subtitle;

                      switch (SocketManager().state.value) {
                        case SocketState.CONNECTED:
                          subtitle = "Tap to sync messages";
                          break;
                        default:
                          subtitle = "Disconnected, cannot sync";
                      }

                      return SettingsTile(
                          title: "Manually Sync Messages",
                          subtitle: subtitle,
                          leading: SettingsLeadingIcon(
                            iosIcon: CupertinoIcons.arrow_2_circlepath,
                            materialIcon: Icons.sync,
                          ),
                          onTap: () async {
                            showDialog(
                              context: context,
                              builder: (context) => SyncDialog(),
                            );
                          });
                    }),
                ]
              ),
              SettingsHeader(
                  headerColor: headerColor,
                  tileColor: tileColor,
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "Server Actions"
              ),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(() => SettingsTile(
                    title: "Fetch${kIsWeb || kIsDesktop ? "" : " & Share"} Server Logs",
                    subtitle: controller.fetchStatus.value
                        ?? (SocketManager().state.value == SocketState.CONNECTED ? "Tap to fetch logs" : "Disconnected, cannot fetch logs"),
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.doc_plaintext,
                      materialIcon: Icons.article,
                    ),
                    onTap: () {
                      if (![SocketState.CONNECTED].contains(SocketManager().state.value)) return;

                      controller.fetchStatus.value = "Fetching logs, please wait...";

                      api.serverLogs().then((response) async {
                        if (kIsDesktop) {
                          String downloadsPath = (await getDownloadsDirectory())!.path;
                          File(join(downloadsPath, "main.log")).writeAsStringSync(response.data['data']);
                          return showSnackbar('Success', 'Saved logs to $downloadsPath!');
                        }

                        if (kIsWeb) {
                          final bytes = utf8.encode(response.data['data']);
                          final content = base64.encode(bytes);
                          html.AnchorElement(
                              href: "data:application/octet-stream;charset=utf-16le;base64,$content")
                            ..setAttribute("download", "main.log")
                            ..click();
                          return;
                        }

                        String appDocPath = SettingsManager().appDocDir.path;
                        File logFile = File("$appDocPath/attachments/main.log");

                        if (logFile.existsSync()) {
                          logFile.deleteSync();
                        }

                        logFile.writeAsStringSync(response.data['data']);

                        try {
                          Share.file("BlueBubbles Server Log", logFile.absolute.path);
                          controller.fetchStatus.value = null;
                        } catch (ex) {
                          controller.fetchStatus.value = "Failed to share file! ${ex.toString()}";
                        }
                      }).catchError((_) {
                        controller.fetchStatus.value = "Failed to fetch logs!";
                      });
                    },
                  )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ),
                  Obx(() => SettingsTile(
                      title: "Restart iMessage",
                      subtitle: controller.isRestartingMessages.value && SocketManager().state.value == SocketState.CONNECTED
                          ? "Restart in progress..." : SocketManager().state.value == SocketState.CONNECTED ? "Restart the iMessage app" : "Disconnected, cannot restart",
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.chat_bubble,
                        materialIcon: Icons.sms,
                      ),
                      onTap: () async {
                        if (SocketManager().state.value != SocketState.CONNECTED || controller.isRestartingMessages.value) return;

                        controller.isRestartingMessages.value = true;

                        // Prevent restarting more than once every 30 seconds
                        int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                        if (controller.lastRestartMessages != null && now - controller.lastRestartMessages! < 1000 * 30) return;

                        // Save the last time we restarted
                        controller.lastRestartMessages = now;

                        // Execute the restart
                        api.restartImessage().then((_) {
                          controller.isRestartingMessages.value = false;
                        }).catchError((_) {
                          controller.isRestartingMessages.value = false;
                        });
                      },
                      trailing: Obx(() => (!controller.isRestartingMessages.value)
                          ? Icon(Icons.refresh, color: context.theme.colorScheme.outline)
                          : Container(
                          constraints: BoxConstraints(
                            maxHeight: 20,
                            maxWidth: 20,
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                          ))))),
                  Obx(() {
                    if (SettingsManager().settings.enablePrivateAPI.value) {
                      return Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                        ),
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
                  Obx(() {
                    if (SettingsManager().settings.enablePrivateAPI.value
                        && (controller.serverVersionCode.value ?? 0) >= 41) {
                      return SettingsTile(
                          title: "Restart Private API & Services",
                          subtitle: controller.isRestartingPrivateAPI.value && SocketManager().state.value == SocketState.CONNECTED
                              ? "Restart in progress..." : SocketManager().state.value == SocketState.CONNECTED ? "Restart the Private API" : "Disconnected, cannot restart",
                          leading: SettingsLeadingIcon(
                            iosIcon: CupertinoIcons.exclamationmark_shield,
                            materialIcon: Icons.gpp_maybe,
                          ),
                          onTap: () async {
                            if (SocketManager().state.value != SocketState.CONNECTED || controller.isRestartingPrivateAPI.value) return;

                            controller.isRestartingPrivateAPI.value = true;

                            // Prevent restarting more than once every 30 seconds
                            int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                            if (controller.lastRestartPrivateAPI != null && now - controller.lastRestartPrivateAPI! < 1000 * 30) return;

                            // Save the last time we restarted
                            controller.lastRestartPrivateAPI = now;

                            // Execute the restart
                            api.softRestart().then((_) {
                              controller.isRestartingPrivateAPI.value = false;
                            }).catchError((_) {
                              controller.isRestartingPrivateAPI.value = false;
                            });
                          },
                          trailing: (!controller.isRestartingPrivateAPI.value)
                              ? Icon(Icons.refresh, color: context.theme.colorScheme.outline)
                              : Container(
                              constraints: BoxConstraints(
                                maxHeight: 20,
                                maxWidth: 20,
                              ),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                              )));
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ),
                  Obx(() => SettingsTile(
                      title: "Restart BlueBubbles Server",
                      subtitle: (controller.isRestarting.value)
                          ? "Restart in progress..."
                          : "This will briefly disconnect you",
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.desktopcomputer,
                        materialIcon: Icons.dvr,
                      ),
                      onTap: () async {
                        if (controller.isRestarting.value) return;

                        controller.isRestarting.value = true;

                        // Prevent restarting more than once every 30 seconds
                        int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                        if (controller.lastRestart != null && now - controller.lastRestart! < 1000 * 30) return;

                        // Save the last time we restarted
                        controller.lastRestart = now;

                        void stopRestarting() {
                          controller.isRestarting.value = false;
                        }

                        // Perform the restart
                        try {
                          if (kIsDesktop || kIsWeb) {
                            var db = FirebaseDatabase(databaseURL: SettingsManager().fcmData?.firebaseURL);
                            var ref = db.reference().child('config').child('nextRestart');
                            await ref.set(DateTime
                                .now()
                                .toUtc()
                                .millisecondsSinceEpoch);
                          } else {
                            await MethodChannelInterface().invokeMethod(
                                "set-next-restart", {"value": DateTime
                                .now()
                                .toUtc()
                                .millisecondsSinceEpoch});
                          }
                        } finally {
                          stopRestarting();
                        }

                        // After 5 seconds, remove the restarting message
                        Future.delayed(Duration(seconds: 5), () {
                          stopRestarting();
                        });
                      },
                      trailing: (!controller.isRestarting.value)
                          ? Icon(Icons.refresh, color: context.theme.colorScheme.outline)
                          : Container(
                          constraints: BoxConstraints(
                            maxHeight: 20,
                            maxWidth: 20,
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                          )))),

                  Obx(() => (controller.serverVersionCode.value ?? 0) >= 42 ? Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ) : SizedBox.shrink()),
                  Obx(() => (controller.serverVersionCode.value ?? 0) >= 42 ? SettingsTile(
                    title: "Check for Server Updates",
                    subtitle: "Check for new BlueBubbles Server updates",
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.desktopcomputer,
                      materialIcon: Icons.dvr,
                    ),
                    onTap: () async {
                      final response = await api.checkUpdate();
                      if (response.statusCode == 200) {
                        bool available = response.data['data']['available'] ?? false;
                        Map<String, dynamic> metadata = response.data['data']['metadata'] ?? {};
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: context.theme.colorScheme.properSurface,
                            title: Text("Update Check", style: context.theme.textTheme.titleLarge),
                            content: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  SizedBox(
                                    height: 15.0,
                                  ),
                                  Text(available ? "Updates available:" : "Your server is up-to-date!", style: context.theme.textTheme.bodyLarge),
                                  SizedBox(
                                    height: 15.0,
                                  ),
                                  if (metadata.isNotEmpty)
                                    Text("Version: ${metadata['version'] ?? "Unknown"}\nRelease Date: ${metadata['release_date'] ?? "Unknown"}\nRelease Name: ${metadata['release_name'] ?? "Unknown"}", style: context.theme.textTheme.bodyLarge)
                                ]
                            ),
                            actions: [
                              TextButton(
                                  child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                  onPressed: () => Navigator.of(context).pop()
                              ),
                            ]
                          ),
                        );
                      } else {
                        showSnackbar("Error", "Failed to check for updates!");
                      }
                    },
                  ) : SizedBox.shrink()),
                ],
              ),
            ],
          ),
        ),
      ]
    );
  }
}

class SyncDialog extends StatefulWidget {
  SyncDialog({Key? key}) : super(key: key);

  @override
  State<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  String? errorCode;
  bool finished = false;
  String? message;
  double? progress;
  Duration? lookback;
  int page = 0;

  void syncMessages() async {
    if (lookback == null) return;

    DateTime now = DateTime.now().toUtc().subtract(lookback!);
    MessageManager().getMessages(withChats: true, withAttachments: true, withHandles: true, after: now.millisecondsSinceEpoch, limit: 100).then((dynamic messages) {
      if (mounted) {
        setState(() {
          message = "Adding ${messages.length} messages...";
        });
      }

      MessageHelper.bulkAddMessages(null, messages, onProgress: (int progress, int length) {
        if (progress == 0 || length == 0) {
          this.progress = null;
        } else {
          this.progress = progress / length;
        }

        if (mounted) {
          setState(() {
            message = "Adding $progress of $length (${((this.progress ?? 0) * 100).floor().toInt()}%)";
          });
        }
      }).then((List<Message> items) {
        onFinish(true, items.length);
      });
    }).catchError((_) {
      onFinish(false, 0);
    });
  }

  void onFinish([bool success = true, int? total]) {
    if (!mounted) return;

    progress = 100;
    message = "Finished adding $total messages!";
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    String title = errorCode != null ? "Error!" : message ?? "";
    Widget content = Container();
    if (errorCode != null) {
      content = Text(errorCode!);
    } else {
      content = Container(
        height: 5,
        child: Center(
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: context.theme.colorScheme.outline,
            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
          ),
        ),
      );
    }

    List<Widget> actions = [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: Text(
          "OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary),
        ),
      )
    ];

    if (page == 0) {
      title = "How far back would you like to go?";
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              "Days: ${lookback?.inDays ?? "1"}",
              style: context.theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Slider(
              value: lookback?.inDays.toDouble() ?? 1.0,
              onChanged: (double value) {
                if (!mounted) return;

                setState(() {
                  lookback = Duration(days: value.toInt());
                });
              },
              label: lookback?.inDays.toString() ?? "1",
              divisions: 29,
              min: 1,
              max: 30,
            ),
          )
        ],
      );

      actions = [
        TextButton(
          onPressed: () {
            if (!mounted) return;
            lookback ??= Duration(days: 1);
            page = 1;
            message = "Fetching messages...";
            setState(() {});
            syncMessages();
          },
          child: Text(
            "Sync",
            style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary),
          ),
        )
      ];
    }

    return AlertDialog(
      backgroundColor: context.theme.colorScheme.properSurface,
      title: Text(title, style: context.theme.textTheme.titleLarge),
      content: content,
      actions: actions,
    );
  }
}
