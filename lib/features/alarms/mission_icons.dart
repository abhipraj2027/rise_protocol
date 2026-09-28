import 'package:flutter/material.dart';

import '../../data/alarm.dart';

/// The icon shown for each [MissionType] — shared by the mission picker in
/// the editor and the small badge on each alarm card.
extension MissionTypeIcon on MissionType {
  IconData get icon => switch (this) {
        MissionType.none => Icons.touch_app_outlined,
        MissionType.math => Icons.calculate_outlined,
        MissionType.shake => Icons.vibration,
        MissionType.photo => Icons.photo_camera_outlined,
        MissionType.barcode => Icons.qr_code_scanner,
        MissionType.qna => Icons.quiz_outlined,
      };
}
