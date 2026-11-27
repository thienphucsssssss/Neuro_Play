import 'dart:convert';

final _username = RegExp(r'^[a-zA-Z0-9_]{3,32}$');
final _email = RegExp(
  r'^[^\s@\p{Cc}\p{Cs}]+@[^\s@\p{Cc}\p{Cs}]+\.[^\s@\p{Cc}\p{Cs}]+$',
  unicode: true,
);

String? validateUsername(String? value) =>
    _username.hasMatch((value ?? '').trim())
    ? null
    : 'Dùng 3–32 ký tự gồm chữ, số hoặc dấu gạch dưới.';

String? validateEmail(String? value) {
  final email = (value ?? '').trim().toLowerCase();
  return email.runes.length <= 254 && _email.hasMatch(email)
      ? null
      : 'Nhập địa chỉ email hợp lệ.';
}

String? validateIdentifier(String? value) {
  final identifier = (value ?? '').trim();
  if (identifier.isEmpty) return 'Nhập email hoặc username.';
  return identifier.contains('@')
      ? validateEmail(identifier)
      : validateUsername(identifier);
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.runes.length < 15) return 'Mật khẩu cần ít nhất 15 ký tự.';
  if (utf8.encode(password).length > 72) {
    return 'Mật khẩu vượt quá 72 byte UTF-8.';
  }
  return null;
}

String? validateDisplayName(String? value) =>
    (value ?? '').trim().runes.length > 80
    ? 'Tên hiển thị tối đa 80 ký tự.'
    : null;
