import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

enum MediaPermissionType { camera, gallery }

class MediaPermission {
  const MediaPermission._();

  static Future<bool> request(
    BuildContext context,
    MediaPermissionType type,
  ) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return true;

    final permission = type == MediaPermissionType.camera
        ? Permission.camera
        : Permission.photos;
    var status = await permission.status;
    if (status.isGranted || status.isLimited) return true;

    if (!context.mounted) return false;
    if (status.isPermanentlyDenied || status.isRestricted) {
      await _showSettingsDialog(context, type);
      return false;
    }

    final proceed = await _showRationaleDialog(context, type);
    if (proceed != true || !context.mounted) return false;

    status = await permission.request();
    if (status.isGranted || status.isLimited) return true;

    if (!context.mounted) return false;
    if (status.isPermanentlyDenied) {
      await _showSettingsDialog(context, type);
    } else {
      await _showDeniedDialog(context, type);
    }
    return false;
  }

  static Future<bool?> _showRationaleDialog(
    BuildContext context,
    MediaPermissionType type,
  ) {
    final camera = type == MediaPermissionType.camera;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(camera ? '需要相机权限' : '需要相册权限'),
        content: Text(
          camera
              ? '为了拍摄训练打卡照片，需要访问你的相机。我们只会在你主动拍照时使用相机，不会在后台开启或上传画面。'
              : '为了导入训练照片或主题背景，需要访问你的相册。我们只会读取你主动选择的图片，不会扫描或上传你的相册。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('暂不'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(camera ? '允许使用相机' : '允许访问相册'),
          ),
        ],
      ),
    );
  }

  static Future<void> _showDeniedDialog(
    BuildContext context,
    MediaPermissionType type,
  ) {
    final camera = type == MediaPermissionType.camera;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(camera ? '未获得相机权限' : '未获得相册权限'),
        content: Text(
          camera
              ? '没有相机权限，暂时无法拍照。你可以稍后重新尝试并允许权限。'
              : '没有相册权限，暂时无法导入图片。你可以稍后重新尝试并允许权限。',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  static Future<void> _showSettingsDialog(
    BuildContext context,
    MediaPermissionType type,
  ) {
    final camera = type == MediaPermissionType.camera;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(camera ? '相机权限已被关闭' : '相册权限已被关闭'),
        content: Text(
          camera
              ? '你之前拒绝了相机权限。请前往系统设置，在「权限」中允许本应用使用相机后重试。'
              : '你之前拒绝了相册权限。请前往系统设置，在「权限」中允许本应用访问照片后重试。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }
}
