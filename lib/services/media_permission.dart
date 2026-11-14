import 'package:flutter/material.dart';

enum MediaPermissionType { camera, gallery }

class MediaPermission {
  const MediaPermission._();

  /// `image_picker` 通过系统相机应用和系统照片选择器完成拍摄与选择，
  /// 系统只会把本次结果以一次性 URI 授权给本应用。
  ///
  /// 因此不需要申请相机或媒体库权限：
  /// - 不会再出现“使用选中的照片/允许全部照片”这种对实际选择没有影响的选项；
  /// - 也不会出现相机“仅本次允许”之后被系统长期记住的情况。
  static Future<bool> request(
    BuildContext context,
    MediaPermissionType type,
  ) async {
    return true;
  }
}
