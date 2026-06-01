import 'package:flutter_test/flutter_test.dart';
import 'package:transpro_mobile/core/models/models.dart';

Map<String, dynamic> _baseTripJson({
  Map<String, dynamic>? overrides,
}) {
  final base = <String, dynamic>{
    'id': 'trip1',
    'departureAt': '2026-06-01T08:00:00.000Z',
    'estimatedArrivalAt': '2026-06-01T14:00:00.000Z',
    'status': 'SCHEDULED',
    'tripClass': 'STANDARD',
    'price': 5000,
    'availableSeats': 20,
    'totalSeats': 30,
    'amenities': ['WIFI', 'AC'],
    'advancedSeatManagement': true,
    'route': {
      'name': 'Abidjan–Bouaké',
      'originCity': {'name': 'Abidjan'},
      'destinationCity': {'name': 'Bouaké'},
      'stops': [],
    },
    'tenant': {'name': 'STC CI', 'logo': null, 'slug': 'stc-ci'},
    'departureStation': {'id': 'ds1', 'name': 'Adjamé', 'address': 'Gare Adjamé'},
    'arrivalStation': {'id': 'as1', 'name': 'Gare Bouaké', 'address': 'Bouaké centre'},
  };
  if (overrides != null) base.addAll(overrides);
  return base;
}

void main() {
  group('Trip.fromJson', () {
    test('parses basic fields', () {
      final trip = Trip.fromJson(_baseTripJson());
      expect(trip.id, 'trip1');
      expect(trip.routeName, 'Abidjan–Bouaké');
      expect(trip.originCity, 'Abidjan');
      expect(trip.destinationCity, 'Bouaké');
      expect(trip.status, 'SCHEDULED');
      expect(trip.tripClass, 'STANDARD');
      expect(trip.price, 5000.0);
      expect(trip.availableSeats, 20);
      expect(trip.totalSeats, 30);
      expect(trip.amenities, ['WIFI', 'AC']);
    });

    test('parses departure and arrival stations', () {
      final trip = Trip.fromJson(_baseTripJson());
      expect(trip.departureStationId, 'ds1');
      expect(trip.departureStationName, 'Adjamé');
      expect(trip.arrivalStationName, 'Gare Bouaké');
    });

    test('parses dates correctly', () {
      final trip = Trip.fromJson(_baseTripJson());
      expect(trip.departureAt, DateTime.parse('2026-06-01T08:00:00.000Z'));
      expect(trip.estimatedArrivalAt, DateTime.parse('2026-06-01T14:00:00.000Z'));
    });

    test('handles null estimatedArrivalAt', () {
      final trip = Trip.fromJson(_baseTripJson(overrides: {'estimatedArrivalAt': null}));
      expect(trip.estimatedArrivalAt, isNull);
    });

    test('parses vehicle and driver', () {
      final trip = Trip.fromJson(_baseTripJson(overrides: {
        'vehicle': {'plate': 'CI-1234-AB', 'advancedSeatManagement': false},
        'driver': {'firstName': 'Jean', 'lastName': 'Kouassi'},
      }));
      expect(trip.vehiclePlate, 'CI-1234-AB');
      expect(trip.driverName, 'Jean Kouassi');
    });

    test('falls back to vehicle.advancedSeatManagement when trip field absent', () {
      final json = _baseTripJson(overrides: {
        'advancedSeatManagement': null,
        'vehicle': {'plate': 'X', 'advancedSeatManagement': false},
      });
      json.remove('advancedSeatManagement');
      final trip = Trip.fromJson(json);
      expect(trip.advancedSeatManagement, isFalse);
    });

    test('parses route stops', () {
      final json = _baseTripJson(overrides: {
        'route': {
          'name': 'R',
          'originCity': {'name': 'A'},
          'destinationCity': {'name': 'B'},
          'stops': [
            {
              'order': 1,
              'city': {'name': 'Yamoussoukro'},
              'durationFromOriginMinutes': 180,
              'priceFromOrigin': 2500,
            }
          ],
        },
      });
      final trip = Trip.fromJson(json);
      expect(trip.stops.length, 1);
      expect(trip.stops.first.cityName, 'Yamoussoukro');
      expect(trip.stops.first.durationFromOriginMinutes, 180);
      expect(trip.stops.first.priceFromOrigin, 2500);
    });
  });

  group('TripSeat', () {
    test('isAvailable true only for AVAILABLE status', () {
      expect(TripSeat.fromJson({'seatNumber': '1A', 'status': 'AVAILABLE'}).isAvailable, isTrue);
      expect(TripSeat.fromJson({'seatNumber': '1B', 'status': 'RESERVED'}).isAvailable, isFalse);
      expect(TripSeat.fromJson({'seatNumber': '1C', 'status': 'OCCUPIED'}).isAvailable, isFalse);
      expect(TripSeat.fromJson({'seatNumber': '1D', 'status': 'BLOCKED'}).isAvailable, isFalse);
    });

    test('defaults status to AVAILABLE when missing', () {
      expect(TripSeat.fromJson({'seatNumber': '2A'}).isAvailable, isTrue);
    });
  });
}
