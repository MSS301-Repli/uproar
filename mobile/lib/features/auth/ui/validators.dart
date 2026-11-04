/// Same rules as identity-service (RegisterRequest), so users see errors before calling the API.
class Validators {
  Validators._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _username = RegExp(r'^[a-zA-Z0-9_.]{3,30}$');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_email.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? username(String? value) {
    if (value == null || !_username.hasMatch(value.trim())) {
      return "3-30 characters: letters, digits, '_' or '.'";
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.length < 8) return 'At least 8 characters';
    if (value.length > 72) return 'At most 72 characters';
    return null;
  }
}
