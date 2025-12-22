class UserRoleHolder {
  static String currentRole = 'client'; // fallback

  static void setRole(String role) {
    currentRole = role;
  }
}
