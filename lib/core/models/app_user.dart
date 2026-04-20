import 'app_role.dart';
import 'role_application.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phoneNumber,
    this.avatarUrl,
    this.approvedRoles = const [AppRole.customer],
    this.ownerApplicationStatus = RoleApplicationStatus.notApplied,
    this.riderApplicationStatus = RoleApplicationStatus.notApplied,
    this.ownerApplicationData = const {},
    this.riderApplicationData = const {},
  });

  final String id;
  final String name;
  final String email;
  final AppRole role;
  final String? phoneNumber;
  final String? avatarUrl;
  final List<AppRole> approvedRoles;
  final RoleApplicationStatus ownerApplicationStatus;
  final RoleApplicationStatus riderApplicationStatus;
  final Map<String, dynamic> ownerApplicationData;
  final Map<String, dynamic> riderApplicationData;

  bool get canSwitchRoles => approvedRoles.length > 1;

  bool hasApprovedRole(AppRole candidate) {
    return approvedRoles.contains(candidate);
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    AppRole? role,
    String? phoneNumber,
    String? avatarUrl,
    List<AppRole>? approvedRoles,
    RoleApplicationStatus? ownerApplicationStatus,
    RoleApplicationStatus? riderApplicationStatus,
    Map<String, dynamic>? ownerApplicationData,
    Map<String, dynamic>? riderApplicationData,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      approvedRoles: approvedRoles ?? this.approvedRoles,
      ownerApplicationStatus:
          ownerApplicationStatus ?? this.ownerApplicationStatus,
      riderApplicationStatus:
          riderApplicationStatus ?? this.riderApplicationStatus,
      ownerApplicationData:
          ownerApplicationData ?? this.ownerApplicationData,
      riderApplicationData:
          riderApplicationData ?? this.riderApplicationData,
    );
  }
}
