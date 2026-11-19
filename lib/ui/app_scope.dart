import 'package:flutter/material.dart';

import '../core/settings.dart';
import '../core/zikr.dart';

/// Uygulama genelindeki durum nesnelerine erişim.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.settings,
    required this.zikr,
    required super.child,
  });

  final AppSettings settings;
  final ZikrCounter zikr;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) =>
      settings != old.settings || zikr != old.zikr;
}

extension AppScopeX on BuildContext {
  AppSettings get settings => AppScope.of(this).settings;
  ZikrCounter get zikr => AppScope.of(this).zikr;

  /// initState gibi yerlerde bağımlılık kurmadan okuma.
  AppSettings get settingsRead =>
      getInheritedWidgetOfExactType<AppScope>()!.settings;
}
