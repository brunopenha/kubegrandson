import 'package:flutter/material.dart';
import 'package:flutter_json_view/flutter_json_view.dart';

import '../../providers/theme/app_colors.dart';

class JsonTreeWidget extends StatelessWidget {
  final Map<String, dynamic> jsonData;

  const JsonTreeWidget({
    super.key,
    required this.jsonData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: JsonView.map(
        jsonData,
        theme: JsonViewTheme(
          backgroundColor: AppColors.backgroundDark,
          defaultTextStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontFamily: 'RobotoMono',
          ),
          keyStyle: const TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          stringStyle: const TextStyle(
            color: AppColors.success,
          ),
          // numberStyle: const TextStyle(
          //   color: AppColors.warning,
          // ),
          boolStyle: const TextStyle(
            color: AppColors.info,
          ),
          // nullStyle: const TextStyle(
          // ),
        ),
      ),
    );
  }
}