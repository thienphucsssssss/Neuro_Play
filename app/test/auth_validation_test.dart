import 'package:flutter_test/flutter_test.dart';
import 'package:game_tri_tue/auth/auth_validation.dart';

void main() {
  test(
    'accepts email within the Unicode length limit and rejects controls',
    () {
      final name = List.filled(244, '😀').join();
      expect(validateEmail('$name@example.x'), isNull);
      expect(validateEmail('mail\u0000@example.test'), isNotNull);
    },
  );

  test('checks both password length and the bcrypt UTF-8 byte limit', () {
    expect(validatePassword('short'), isNotNull);
    expect(validatePassword(List.filled(18, '😀').join()), isNull);
    expect(validatePassword(List.filled(19, '😀').join()), isNotNull);
  });
}
