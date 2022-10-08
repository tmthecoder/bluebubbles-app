import 'package:bluebubbles/helpers/network/network_tasks.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/services/backend/sync/sync_service.dart';
import 'package:get/get.dart';

SetupService setup = Get.isRegistered<SetupService>() ? Get.find<SetupService>() : Get.put(SetupService());

class SetupService extends GetxService {
  Future<void> startSetup(int numberOfMessagesPerPage, bool skipEmptyChats, bool saveToDownloads) async {
    sync.numberOfMessagesPerPage = numberOfMessagesPerPage;
    sync.skipEmptyChats = skipEmptyChats;
    sync.saveToDownloads = saveToDownloads;
    await sync.startFullSync();
    await _finishSetup();
  }

  Future<void> _finishSetup() async {
    SettingsManager().settings.finishedSetup.value = true;
    await SettingsManager().saveSettings();
    await NetworkTasks.onConnect();
  }
}