import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:waste_classification/core/theme/app_theme.dart';
import 'package:waste_classification/features/auth/auth_guard.dart';
import 'package:waste_classification/features/navigation/app_shell.dart';

class WasteClassificationApp extends StatelessWidget {
  const WasteClassificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'app_name'.tr(),
      theme: AppTheme.light,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      home: const AuthGuard(authenticatedChild: AppShell()),
    );
  }
}
