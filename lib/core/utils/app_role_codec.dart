import '../models/app_role.dart';

extension AppRoleCodec on AppRole {
  String get storageValue => name;
}

AppRole appRoleFromStorage(String? value) {
  return AppRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => AppRole.customer,
  );
}
