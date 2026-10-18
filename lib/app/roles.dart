import 'package:flutter/material.dart';

import '../data/models.dart';

/// Per-role label, icon and colours. The background colour tints every screen
/// after sign-in so staff can tell roles apart at a glance.
extension RoleStyle on Role {
  String get label => switch (this) {
    Role.presenter => 'Presenter',
    Role.attendee => 'Attendee',
    Role.speaker => 'Speaker',
    Role.vip => 'VIP',
    Role.organiser => 'Organiser',
    Role.volunteer => 'Volunteer',
  };

  IconData get icon => switch (this) {
    Role.presenter => Icons.co_present_outlined,
    Role.attendee => Icons.person_outline,
    Role.speaker => Icons.mic_none,
    Role.vip => Icons.workspace_premium_outlined,
    Role.organiser => Icons.admin_panel_settings_outlined,
    Role.volunteer => Icons.volunteer_activism_outlined,
  };

  /// Screen background.
  Color get background => switch (this) {
    Role.presenter => const Color(0xFFE6F5F2),
    Role.attendee => const Color(0xFFE9F0FB),
    Role.speaker => const Color(0xFFF0EAFB),
    Role.vip => const Color(0xFFFBF2DC),
    Role.organiser => const Color(0xFFE6F4E8),
    Role.volunteer => const Color(0xFFFCEBE1),
  };

  /// Badge and highlight colour.
  Color get accent => switch (this) {
    Role.presenter => const Color(0xFF0E9F8E),
    Role.attendee => const Color(0xFF2F6FDB),
    Role.speaker => const Color(0xFF6E44C9),
    Role.vip => const Color(0xFFA87A00),
    Role.organiser => const Color(0xFF2E8B3E),
    Role.volunteer => const Color(0xFFD0582A),
  };
}
