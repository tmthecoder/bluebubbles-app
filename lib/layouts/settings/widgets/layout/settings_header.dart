import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SettingsHeader extends StatelessWidget {
  final Color headerColor;
  final Color tileColor;
  final TextStyle? iosSubtitle;
  final TextStyle? materialSubtitle;
  final String text;

  SettingsHeader(
      {required this.headerColor,
        required this.tileColor,
        required this.iosSubtitle,
        required this.materialSubtitle,
        required this.text});

  @override
  Widget build(BuildContext context) {
    if (settings.settings.skin.value == Skins.Samsung) return const SizedBox(height: 15);
    return Container(
      height: settings.settings.skin.value == Skins.iOS ? 60 : 40,
      alignment: Alignment.bottomLeft,
      color: settings.settings.skin.value == Skins.iOS ? headerColor : tileColor,
      child: Padding(
        padding: EdgeInsets.only(bottom: 8.0, left: settings.settings.skin.value == Skins.iOS ? 30 : 15),
        child: Text(text.psCapitalize,
            style: settings.settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle
        ),
      )
    );
  }
}