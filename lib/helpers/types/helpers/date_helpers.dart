import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:intl/intl.dart';

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  if (value is DateTime) return value;
  return null;
}

String buildDate(DateTime? dateTime) {
  if (dateTime == null || dateTime.millisecondsSinceEpoch == 0) return "";
  String time = ss.settings.use24HrFormat.value
      ? DateFormat.Hm().format(dateTime)
      : DateFormat.jm().format(dateTime);
  String date;
  if (dateTime.isToday()) {
    date = time;
  } else if (dateTime.isYesterday()) {
    date = "Yesterday";
  } else if (DateTime.now().difference(dateTime.toLocal()).inDays <= 7) {
    date = DateFormat(ss.settings.skin.value != Skins.iOS ? "EEE" : "EEEE").format(dateTime);
  } else if (ss.settings.skin.value == Skins.Material && DateTime.now().difference(dateTime.toLocal()).inDays <= 365) {
    date = DateFormat.MMMd().format(dateTime);
  } else if (ss.settings.skin.value == Skins.Samsung && DateTime.now().year == dateTime.toLocal().year) {
    date = DateFormat.MMMd().format(dateTime);
  } else if (ss.settings.skin.value == Skins.Samsung && DateTime.now().year != dateTime.toLocal().year) {
    date = DateFormat.yMMMd().format(dateTime);
  } else {
    date = DateFormat.yMd().format(dateTime);
  }
  return date;
}

String buildSeparatorDateSamsung(DateTime dateTime) {
  return DateFormat.yMMMMEEEEd().format(dateTime);
}

String buildTime(DateTime? dateTime) {
  if (dateTime == null || dateTime.millisecondsSinceEpoch == 0) return "";
  String time = ss.settings.use24HrFormat.value
      ? DateFormat.Hm().format(dateTime)
      : DateFormat.jm().format(dateTime);
  return time;
}

String buildFullDate(DateTime time) {
  return DateFormat.yMd().add_jm().format(time);
}
