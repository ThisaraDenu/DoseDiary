import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppPermissionType {
  contacts,
  location,
  media,
  camera,
  calendar,
}

class AppPermissionItem {
  final AppPermissionType type;
  final String title;
  final String description;
  final IconData icon;
  final bool isGranted;

  const AppPermissionItem({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    this.isGranted = false,
  });

  AppPermissionItem copyWith({bool? isGranted}) {
    return AppPermissionItem(
      type: type,
      title: title,
      description: description,
      icon: icon,
      isGranted: isGranted ?? this.isGranted,
    );
  }
}

class PermissionService {
  static const String keyPermissionsPrompted = 'permissions_prompted';

  /// Whether the initial permissions primer has been shown on first login
  static bool hasPrompted(SharedPreferences prefs) {
    return prefs.getBool(keyPermissionsPrompted) ?? false;
  }

  /// Mark permissions primer completed
  static Future<void> markPrompted(SharedPreferences prefs) async {
    await prefs.setBool(keyPermissionsPrompted, true);
  }

  /// Map AppPermissionType to underlying permission_handler Permissions
  static List<Permission> _getPermissionsForType(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.contacts:
        return [Permission.contacts];
      case AppPermissionType.location:
        return [Permission.locationWhenInUse, Permission.location];
      case AppPermissionType.camera:
        return [Permission.camera];
      case AppPermissionType.media:
        return [Permission.photos, Permission.storage];
      case AppPermissionType.calendar:
        return [Permission.calendarFullAccess, Permission.calendar];
    }
  }

  /// Check if a specific permission is currently granted
  static Future<bool> isGranted(AppPermissionType type) async {
    try {
      final permissions = _getPermissionsForType(type);
      for (final p in permissions) {
        final status = await p.status;
        if (status.isGranted || status.isLimited) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Request a specific permission
  static Future<bool> request(AppPermissionType type) async {
    try {
      final permissions = _getPermissionsForType(type);
      bool anyGranted = false;
      for (final p in permissions) {
        final status = await p.request();
        if (status.isGranted || status.isLimited) {
          anyGranted = true;
          break;
        }
      }
      return anyGranted;
    } catch (_) {
      return false;
    }
  }

  /// Request all 5 app permissions in sequence
  static Future<Map<AppPermissionType, bool>> requestAll() async {
    final results = <AppPermissionType, bool>{};
    for (final type in AppPermissionType.values) {
      results[type] = await request(type);
    }
    return results;
  }

  /// Check current status of all 5 permissions
  static Future<Map<AppPermissionType, bool>> checkAll() async {
    final results = <AppPermissionType, bool>{};
    for (final type in AppPermissionType.values) {
      results[type] = await isGranted(type);
    }
    return results;
  }
}

class PermissionsState {
  final bool isLoading;
  final bool isRequestingAll;
  final Map<AppPermissionType, bool> statuses;

  const PermissionsState({
    this.isLoading = false,
    this.isRequestingAll = false,
    this.statuses = const {
      AppPermissionType.contacts: false,
      AppPermissionType.location: false,
      AppPermissionType.media: false,
      AppPermissionType.camera: false,
      AppPermissionType.calendar: false,
    },
  });

  bool get allGranted => statuses.values.every((s) => s == true);

  PermissionsState copyWith({
    bool? isLoading,
    bool? isRequestingAll,
    Map<AppPermissionType, bool>? statuses,
  }) {
    return PermissionsState(
      isLoading: isLoading ?? this.isLoading,
      isRequestingAll: isRequestingAll ?? this.isRequestingAll,
      statuses: statuses ?? this.statuses,
    );
  }
}

class PermissionsController extends StateNotifier<PermissionsState> {
  PermissionsController([Map<AppPermissionType, bool>? initialStatuses])
      : super(PermissionsState(
          statuses: initialStatuses ??
              const {
                AppPermissionType.contacts: false,
                AppPermissionType.location: false,
                AppPermissionType.media: false,
                AppPermissionType.camera: false,
                AppPermissionType.calendar: false,
              },
          isLoading: initialStatuses == null,
        )) {
    if (initialStatuses == null) {
      checkStatuses();
    }
  }

  Future<void> checkStatuses() async {
    state = state.copyWith(isLoading: true);
    final statuses = await PermissionService.checkAll();
    state = state.copyWith(statuses: statuses, isLoading: false);
  }

  Future<void> requestSingle(AppPermissionType type) async {
    final granted = await PermissionService.request(type);
    final updated = Map<AppPermissionType, bool>.from(state.statuses);
    updated[type] = granted;
    state = state.copyWith(statuses: updated);
  }

  Future<void> requestAll() async {
    state = state.copyWith(isRequestingAll: true);
    final results = await PermissionService.requestAll();
    state = state.copyWith(statuses: results, isRequestingAll: false);
  }
}

final permissionsControllerProvider =
    StateNotifierProvider<PermissionsController, PermissionsState>((ref) {
  return PermissionsController();
});
