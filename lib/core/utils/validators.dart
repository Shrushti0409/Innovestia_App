class Validators {
  static String? required(String? value, [String label = 'This field']) =>
      value == null || value.trim().isEmpty ? '$label is required.' : null;
  static String? email(String? value) {
    if (required(value, 'Email') != null) return 'Email is required.';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())
        ? null
        : 'Please enter a valid email address.';
  }

  static String? password(String? value) {
    if (value == null || value.length < 8) return 'Use at least 8 characters.';
    return RegExp(r'[A-Za-z]').hasMatch(value) && RegExp(r'\d').hasMatch(value)
        ? null
        : 'Include at least one letter and one number.';
  }
}
