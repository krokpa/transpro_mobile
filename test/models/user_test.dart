import 'package:flutter_test/flutter_test.dart';
import 'package:transpro_mobile/core/models/models.dart';

void main() {
  group('User.fromJson', () {
    test('parses flat user without stations', () {
      final json = {
        'id': 'u1',
        'firstName': 'Koffi',
        'lastName': 'Yao',
        'email': 'koffi@test.ci',
        'phone': '+225 07 00 00 00',
        'role': 'PASSENGER',
        'tenantId': null,
      };
      final user = User.fromJson(json);
      expect(user.id, 'u1');
      expect(user.fullName, 'Koffi Yao');
      expect(user.isPassenger, isTrue);
      expect(user.isAgent, isFalse);
      expect(user.isOwner, isFalse);
      expect(user.stationId, isNull);
    });

    test('picks primary station from userStations', () {
      final json = {
        'id': 'u2',
        'firstName': 'Awa',
        'lastName': 'Diallo',
        'email': 'awa@test.ci',
        'phone': null,
        'role': 'COMPANY_AGENT',
        'tenantId': 't1',
        'userStations': [
          {
            'isPrimary': false,
            'stationId': 's1',
            'station': {'id': 's1', 'name': 'Adjamé'},
          },
          {
            'isPrimary': true,
            'stationId': 's2',
            'station': {'id': 's2', 'name': 'Yopougon'},
          },
        ],
      };
      final user = User.fromJson(json);
      expect(user.isAgent, isTrue);
      expect(user.stationId, 's2');
      expect(user.stationName, 'Yopougon');
    });

    test('falls back to first station when none is primary', () {
      final json = {
        'id': 'u3',
        'firstName': 'Marc',
        'lastName': 'Brou',
        'email': 'm@test.ci',
        'phone': null,
        'role': 'COMPANY_OWNER',
        'tenantId': 't2',
        'userStations': [
          {
            'isPrimary': false,
            'stationId': 's3',
            'station': {'id': 's3', 'name': 'Plateau'},
          },
        ],
      };
      final user = User.fromJson(json);
      expect(user.isOwner, isTrue);
      expect(user.stationId, 's3');
    });

    test('COMPANY_ADMIN is recognised as owner', () {
      final json = {
        'id': 'u4',
        'firstName': 'A',
        'lastName': 'B',
        'email': 'a@b.ci',
        'phone': null,
        'role': 'COMPANY_ADMIN',
        'tenantId': 't3',
      };
      expect(User.fromJson(json).isOwner, isTrue);
    });

    test('SUPER_ADMIN flag', () {
      final json = {
        'id': 'u5',
        'firstName': 'S',
        'lastName': 'A',
        'email': 's@a.ci',
        'phone': null,
        'role': 'SUPER_ADMIN',
      };
      final user = User.fromJson(json);
      expect(user.isSuperAdmin, isTrue);
      expect(user.isOwner, isFalse);
    });
  });

  group('User.toJson round-trip', () {
    test('toJson preserves all scalar fields', () {
      final json = {
        'id': 'u1',
        'firstName': 'K',
        'lastName': 'Y',
        'email': 'k@y.ci',
        'phone': '+225 01',
        'role': 'PASSENGER',
        'tenantId': null,
      };
      final user = User.fromJson(json);
      final out = user.toJson();
      expect(out['id'], 'u1');
      expect(out['role'], 'PASSENGER');
      expect(out['email'], 'k@y.ci');
    });
  });
}
