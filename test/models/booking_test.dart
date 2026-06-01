import 'package:flutter_test/flutter_test.dart';
import 'package:transpro_mobile/core/models/models.dart';

void main() {
  group('Booking.fromJson', () {
    test('parses fields without embedded trip', () {
      final json = {
        'id': 'b1',
        'reference': 'TRP-0001',
        'status': 'CONFIRMED',
        'totalAmount': 10000,
        'seatNumbers': ['1A', '1B'],
        'createdAt': '2026-05-01T10:00:00.000Z',
      };
      final booking = Booking.fromJson(json);
      expect(booking.id, 'b1');
      expect(booking.reference, 'TRP-0001');
      expect(booking.status, 'CONFIRMED');
      expect(booking.totalAmount, 10000.0);
      expect(booking.seatNumbers, ['1A', '1B']);
      expect(booking.trip, isNull);
    });

    test('parses embedded trip', () {
      final json = {
        'id': 'b2',
        'reference': 'TRP-0002',
        'status': 'PENDING',
        'totalAmount': 5000,
        'seatNumbers': [],
        'createdAt': '2026-05-02T09:00:00.000Z',
        'trip': {
          'id': 'trip1',
          'departureAt': '2026-06-01T08:00:00.000Z',
          'status': 'SCHEDULED',
          'tripClass': 'STANDARD',
          'price': 5000,
          'availableSeats': 10,
          'totalSeats': 30,
          'amenities': [],
          'route': {
            'name': 'Abidjan–Daloa',
            'originCity': {'name': 'Abidjan'},
            'destinationCity': {'name': 'Daloa'},
            'stops': [],
          },
        },
      };
      final booking = Booking.fromJson(json);
      expect(booking.trip, isNotNull);
      expect(booking.trip!.routeName, 'Abidjan–Daloa');
    });

    test('handles empty seatNumbers', () {
      final json = {
        'id': 'b3',
        'reference': 'TRP-0003',
        'status': 'CANCELLED',
        'totalAmount': 0,
        'createdAt': '2026-05-03T00:00:00.000Z',
      };
      final booking = Booking.fromJson(json);
      expect(booking.seatNumbers, isEmpty);
    });
  });

  group('AppNotification.fromJson', () {
    test('parses all fields', () {
      final json = {
        'id': 'n1',
        'type': 'BOOKING_CONFIRMED',
        'title': 'Réservation confirmée',
        'message': 'Votre réservation TRP-0001 est confirmée.',
        'isRead': false,
        'createdAt': '2026-05-10T12:00:00.000Z',
        'data': {'bookingId': 'b1'},
      };
      final notif = AppNotification.fromJson(json);
      expect(notif.id, 'n1');
      expect(notif.type, 'BOOKING_CONFIRMED');
      expect(notif.isRead, isFalse);
      expect(notif.data?['bookingId'], 'b1');
    });

    test('defaults isRead to false when missing', () {
      final json = {
        'id': 'n2',
        'type': 'TRIP_DEPARTED',
        'title': 'T',
        'message': 'M',
        'createdAt': '2026-05-11T08:00:00.000Z',
      };
      expect(AppNotification.fromJson(json).isRead, isFalse);
    });
  });

  group('RouteStop.fromJson', () {
    test('parses stop with city', () {
      final json = {
        'order': 2,
        'city': {'name': 'Yamoussoukro'},
        'durationFromOriginMinutes': 200,
        'priceFromOrigin': 3000,
      };
      final stop = RouteStop.fromJson(json);
      expect(stop.order, 2);
      expect(stop.cityName, 'Yamoussoukro');
      expect(stop.durationFromOriginMinutes, 200);
      expect(stop.priceFromOrigin, 3000);
    });

    test('handles missing city gracefully', () {
      final json = {
        'order': 1,
        'durationFromOriginMinutes': 60,
        'priceFromOrigin': 1000,
      };
      expect(RouteStop.fromJson(json).cityName, isNull);
    });
  });
}
