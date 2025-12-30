class UserRoleHolder {
  /// Roles esperados: 'client', 'provider', 'admin', 'unknown'
  static String currentRole = 'unknown';

  static void setRole(String role) {
    currentRole = role;
  }

  static void clear() {
    currentRole = 'unknown';
  }
}
