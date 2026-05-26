class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String role;
  final String? tenantId;
  final String? stationId;
  final String? stationName;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    required this.role,
    this.tenantId,
    this.stationId,
    this.stationName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final stations = json['userStations'] as List?;
    final primary = stations?.firstWhere(
      (s) => s['isPrimary'] == true,
      orElse: () => stations.isNotEmpty ? stations.first : null,
    );
    return User(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      phone: json['phone'],
      role: json['role'],
      tenantId: json['tenantId'],
      stationId: primary?['stationId'] ?? primary?['station']?['id'],
      stationName: primary?['station']?['name'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'firstName': firstName, 'lastName': lastName,
    'email': email, 'phone': phone, 'role': role,
    'tenantId': tenantId, 'stationId': stationId, 'stationName': stationName,
  };

  String get fullName => '$firstName $lastName';
  bool get isPassenger => role == 'PASSENGER';
  bool get isAgent => role == 'COMPANY_AGENT';
  bool get isOwner => role == 'COMPANY_OWNER' || role == 'COMPANY_ADMIN';
  bool get isSuperAdmin => role == 'SUPER_ADMIN';
}

class Trip {
  final String id;
  final String routeName;
  final String originCity;
  final String destinationCity;
  final DateTime departureAt;
  final DateTime? estimatedArrivalAt;
  final String status;
  final String tripClass;
  final double price;
  final int availableSeats;
  final int totalSeats;
  final List<String> amenities;
  final String? vehiclePlate;
  final String? driverName;

  const Trip({
    required this.id,
    required this.routeName,
    required this.originCity,
    required this.destinationCity,
    required this.departureAt,
    this.estimatedArrivalAt,
    required this.status,
    required this.tripClass,
    required this.price,
    required this.availableSeats,
    required this.totalSeats,
    required this.amenities,
    this.vehiclePlate,
    this.driverName,
  });

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
    id: j['id'],
    routeName: j['route']?['name'] ?? '',
    originCity: j['route']?['originCity']?['name'] ?? '',
    destinationCity: j['route']?['destinationCity']?['name'] ?? '',
    departureAt: DateTime.parse(j['departureAt']),
    estimatedArrivalAt: j['estimatedArrivalAt'] != null
        ? DateTime.parse(j['estimatedArrivalAt']) : null,
    status: j['status'] ?? 'SCHEDULED',
    tripClass: j['tripClass'] ?? 'STANDARD',
    price: (j['price'] as num).toDouble(),
    availableSeats: j['availableSeats'] ?? 0,
    totalSeats: j['totalSeats'] ?? 0,
    amenities: List<String>.from(j['amenities'] ?? []),
    vehiclePlate: j['vehicle']?['plate'],
    driverName: j['driver'] != null
        ? '${j['driver']['firstName']} ${j['driver']['lastName']}' : null,
  );
}

class Booking {
  final String id;
  final String reference;
  final String status;
  final double totalAmount;
  final List<String> seatNumbers;
  final DateTime createdAt;
  final Trip? trip;

  const Booking({
    required this.id,
    required this.reference,
    required this.status,
    required this.totalAmount,
    required this.seatNumbers,
    required this.createdAt,
    this.trip,
  });

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
    id: j['id'],
    reference: j['reference'],
    status: j['status'],
    totalAmount: (j['totalAmount'] as num).toDouble(),
    seatNumbers: List<String>.from(j['seatNumbers'] ?? []),
    createdAt: DateTime.parse(j['createdAt']),
    trip: j['trip'] != null ? Trip.fromJson(j['trip']) : null,
  );
}

class City {
  final String id;
  final String name;
  const City({required this.id, required this.name});
  factory City.fromJson(Map<String, dynamic> j) => City(id: j['id'], name: j['name']);
}

class TripSeat {
  final String seatNumber;
  final String status; // AVAILABLE | RESERVED | OCCUPIED | BLOCKED
  const TripSeat({required this.seatNumber, required this.status});
  factory TripSeat.fromJson(Map<String, dynamic> j) =>
      TripSeat(seatNumber: j['seatNumber'], status: j['status'] ?? 'AVAILABLE');
  bool get isAvailable => status == 'AVAILABLE';
}

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id:        j['id'],
    type:      j['type'] ?? '',
    title:     j['title'] ?? '',
    message:   j['message'] ?? '',
    isRead:    j['isRead'] ?? false,
    createdAt: DateTime.parse(j['createdAt']),
    data:      j['data'] as Map<String, dynamic>?,
  );
}
