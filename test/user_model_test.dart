import 'package:flutter_test/flutter_test.dart';
import 'package:vasco/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('toMap includes core fields and omits null optional fields', () {
      final user = UserModel(
        id: 'user-1',
        email: 'ana@example.com',
        displayName: 'Ana',
        photoUrl: '',
      );

      expect(user.toMap(), {
        'id': 'user-1',
        'email': 'ana@example.com',
        'displayName': 'Ana',
        'photoUrl': '',
      });
    });

    test('age returns 0 when birth date is missing', () {
      final user = UserModel(id: 'user-1', email: 'ana@example.com');

      expect(user.age, 0);
    });
  });
}
