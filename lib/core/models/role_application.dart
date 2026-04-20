import 'app_role.dart';

enum RoleApplicationStatus {
  notApplied,
  pending,
  approved,
  rejected,
  suspended,
}

extension RoleApplicationStatusX on RoleApplicationStatus {
  String get storageValue {
    return switch (this) {
      RoleApplicationStatus.notApplied => 'not_applied',
      RoleApplicationStatus.pending => 'pending',
      RoleApplicationStatus.approved => 'approved',
      RoleApplicationStatus.rejected => 'rejected',
      RoleApplicationStatus.suspended => 'suspended',
    };
  }

  String get label {
    return switch (this) {
      RoleApplicationStatus.notApplied => 'Not applied',
      RoleApplicationStatus.pending => 'Pending review',
      RoleApplicationStatus.approved => 'Approved',
      RoleApplicationStatus.rejected => 'Rejected',
      RoleApplicationStatus.suspended => 'Suspended',
    };
  }

  String helperCopy(AppRole role) {
    return switch (this) {
      RoleApplicationStatus.notApplied =>
        'You have not applied for ${role.label.toLowerCase()} access yet.',
      RoleApplicationStatus.pending =>
        'Your ${role.label.toLowerCase()} application is under review.',
      RoleApplicationStatus.approved =>
        'Your ${role.label.toLowerCase()} access is active.',
      RoleApplicationStatus.rejected =>
        'Your ${role.label.toLowerCase()} application needs attention before access can be approved.',
      RoleApplicationStatus.suspended =>
        'Your ${role.label.toLowerCase()} access is temporarily suspended.',
    };
  }
}

RoleApplicationStatus roleApplicationStatusFromStorage(String? value) {
  return switch (value) {
    'pending' => RoleApplicationStatus.pending,
    'approved' => RoleApplicationStatus.approved,
    'rejected' => RoleApplicationStatus.rejected,
    'suspended' => RoleApplicationStatus.suspended,
    _ => RoleApplicationStatus.notApplied,
  };
}
