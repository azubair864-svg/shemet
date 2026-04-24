class StringUtils {
  /// Masks an email address like "example@gmail.com" to "e***e@gmail.com" or "e***@gmail.com"
  static String maskEmail(String email) {
    if (email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final name = parts[0];
    final domain = parts[1];

    if (name.length <= 2) {
      return '${name[0]}***@$domain';
    } else {
      return '${name[0]}***${name[name.length - 1]}@$domain';
    }
  }

  /// Masks a phone number like "+94771234567" to "+947***567"
  static String maskPhone(String phone) {
    if (phone.length <= 6) return phone;
    return '${phone.substring(0, 5)}***${phone.substring(phone.length - 3)}';
  }

  /// Validates a TRC20 address (starts with T, length 34, alphanumeric)
  static bool isValidTRC20(String address) {
    final trc20Regex = RegExp(r'^T[a-zA-Z0-9]{33}$');
    return trc20Regex.hasMatch(address);
  }
}
