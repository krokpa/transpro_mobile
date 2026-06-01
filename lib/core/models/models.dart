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
  final String? avatar;

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
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final stationsList = json['userStations'] as List?;
    final stations = stationsList?.cast<Map<String, dynamic>>();
    Map<String, dynamic>? primary;
    if (stations != null && stations.isNotEmpty) {
      primary = stations.firstWhere(
        (s) => s['isPrimary'] == true,
        orElse: () => stations.first,
      );
    }
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
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'firstName': firstName, 'lastName': lastName,
    'email': email, 'phone': phone, 'role': role,
    'tenantId': tenantId, 'stationId': stationId, 'stationName': stationName,
    'avatar': avatar,
  };

  String get fullName => '$firstName $lastName';
  bool get isPassenger => role == 'PASSENGER';
  bool get isAgent => role == 'COMPANY_AGENT';
  bool get isOwner => role == 'COMPANY_OWNER' || role == 'COMPANY_ADMIN';
  bool get isSuperAdmin => role == 'SUPER_ADMIN';
}

class Tenant {
  final String id;
  final String name;
  final String? logo;
  final String? slug;
  const Tenant({required this.id, required this.name, this.logo, this.slug});
  factory Tenant.fromJson(Map<String, dynamic> j) => Tenant(
    id: j['id'],
    name: j['name'] ?? '',
    logo: j['logo'],
    slug: j['slug'],
  );
}

class RouteStop {
  final int order;
  final String? cityName;
  final int durationFromOriginMinutes;
  final int priceFromOrigin;

  const RouteStop({
    required this.order,
    this.cityName,
    required this.durationFromOriginMinutes,
    required this.priceFromOrigin,
  });

  factory RouteStop.fromJson(Map<String, dynamic> j) => RouteStop(
    order: j['order'] as int? ?? 0,
    cityName: j['city']?['name'] as String?,
    durationFromOriginMinutes: j['durationFromOriginMinutes'] as int? ?? 0,
    priceFromOrigin: j['priceFromOrigin'] as int? ?? 0,
  );
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
  final bool advancedSeatManagement;
  final String? tenantName;
  final String? tenantLogo;
  final String? tenantSlug;
  final String? departureStationId;
  final String? departureStationName;
  final String? departureStationAddress;
  final String? arrivalStationId;
  final String? arrivalStationName;
  final String? arrivalStationAddress;
  final List<RouteStop> stops;

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
    this.advancedSeatManagement = true,
    this.tenantName,
    this.tenantLogo,
    this.tenantSlug,
    this.departureStationId,
    this.departureStationName,
    this.departureStationAddress,
    this.arrivalStationId,
    this.arrivalStationName,
    this.arrivalStationAddress,
    this.stops = const [],
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
    advancedSeatManagement: (j['advancedSeatManagement'] as bool?) ??
        (j['vehicle']?['advancedSeatManagement'] as bool?) ?? true,
    tenantName: j['tenant']?['name'],
    tenantLogo: j['tenant']?['logo'],
    tenantSlug: j['tenant']?['slug'],
    departureStationId: j['departureStation']?['id'],
    departureStationName: j['departureStation']?['name'],
    departureStationAddress: j['departureStation']?['address'],
    arrivalStationId: j['arrivalStation']?['id'],
    arrivalStationName: j['arrivalStation']?['name'],
    arrivalStationAddress: j['arrivalStation']?['address'],
    stops: (j['route']?['stops'] as List?)
            ?.map((s) => RouteStop.fromJson(s as Map<String, dynamic>))
            .toList() ??
        const [],
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

class LuggageBag {
  final String id;
  final String qrCode;
  final String? label;
  final double? weightKg;
  final String status; // DECLARED LOADED ARRIVED CLAIMED MISSING
  final String? missingNote;
  final List<String> photos;
  final DateTime? loadedAt;
  final DateTime? arrivedAt;
  final DateTime? claimedAt;

  const LuggageBag({
    required this.id,
    required this.qrCode,
    this.label,
    this.weightKg,
    required this.status,
    this.missingNote,
    this.photos = const [],
    this.loadedAt,
    this.arrivedAt,
    this.claimedAt,
  });

  factory LuggageBag.fromJson(Map<String, dynamic> j) => LuggageBag(
    id:       j['id'],
    qrCode:   j['qrCode'],
    label:    j['label'] as String?,
    weightKg: (j['weightKg'] as num?)?.toDouble(),
    status:   j['status'] ?? 'DECLARED',
    missingNote: j['missingNote'] as String?,
    photos:   List<String>.from(j['photos'] ?? []),
    loadedAt:   j['loadedAt']  != null ? DateTime.parse(j['loadedAt'])  : null,
    arrivedAt:  j['arrivedAt'] != null ? DateTime.parse(j['arrivedAt']) : null,
    claimedAt:  j['claimedAt'] != null ? DateTime.parse(j['claimedAt']) : null,
  );
}

class BookingLuggage {
  final String id;
  final String bookingId;
  final int bagCount;
  final double totalWeightKg;
  final double freeWeightKg;
  final double excessWeightKg;
  final int excessFeeXof;
  final bool excessPaid;
  final List<LuggageBag> bags;

  const BookingLuggage({
    required this.id,
    required this.bookingId,
    required this.bagCount,
    required this.totalWeightKg,
    required this.freeWeightKg,
    required this.excessWeightKg,
    required this.excessFeeXof,
    required this.excessPaid,
    required this.bags,
  });

  factory BookingLuggage.fromJson(Map<String, dynamic> j) => BookingLuggage(
    id:            j['id'],
    bookingId:     j['bookingId'],
    bagCount:      j['bagCount'] as int? ?? 0,
    totalWeightKg: (j['totalWeightKg'] as num?)?.toDouble() ?? 0,
    freeWeightKg:  (j['freeWeightKg']  as num?)?.toDouble() ?? 20,
    excessWeightKg:(j['excessWeightKg'] as num?)?.toDouble() ?? 0,
    excessFeeXof:  j['excessFeeXof'] as int? ?? 0,
    excessPaid:    j['excessPaid'] as bool? ?? false,
    bags: (j['bags'] as List?)
        ?.map((b) => LuggageBag.fromJson(b as Map<String, dynamic>))
        .toList() ?? [],
  );
}

class DeliveryRequest {
  final String id;
  final String parcelId;
  final String address;
  final String? district;
  final String? landmark;
  final double? latitude;
  final double? longitude;
  final String contactName;
  final String contactPhone;
  final String status; // PENDING ASSIGNED EN_ROUTE DELIVERED FAILED CANCELLED
  final int? deliveryFee;
  final bool isPaid;
  final String? deliveryNotes;
  final String? failReason;
  final DateTime createdAt;

  const DeliveryRequest({
    required this.id,
    required this.parcelId,
    required this.address,
    this.district,
    this.landmark,
    this.latitude,
    this.longitude,
    required this.contactName,
    required this.contactPhone,
    required this.status,
    this.deliveryFee,
    this.isPaid = false,
    this.deliveryNotes,
    this.failReason,
    required this.createdAt,
  });

  factory DeliveryRequest.fromJson(Map<String, dynamic> j) => DeliveryRequest(
    id:           j['id'],
    parcelId:     j['parcelId'],
    address:      j['address'] ?? '',
    district:     j['district'] as String?,
    landmark:     j['landmark'] as String?,
    latitude:     (j['latitude'] as num?)?.toDouble(),
    longitude:    (j['longitude'] as num?)?.toDouble(),
    contactName:  j['contactName'] ?? '',
    contactPhone: j['contactPhone'] ?? '',
    status:       j['status'] ?? 'PENDING',
    deliveryFee:  j['deliveryFee'] as int?,
    isPaid:       j['isPaid'] as bool? ?? false,
    deliveryNotes: j['deliveryNotes'] as String?,
    failReason:   j['failReason'] as String?,
    createdAt:    DateTime.parse(j['createdAt']),
  );
}

class Payment {
  final String id;
  final double amount;
  final String currency;
  final String method;
  final String status;
  final String? transactionId;
  final String? providerRef;
  final DateTime? paidAt;
  final DateTime? failedAt;
  final String? failReason;
  final DateTime createdAt;
  final String? bookingReference;
  final List<String> seatNumbers;
  final double? bookingTotal;
  final String? bookingStatus;
  final String? routeName;
  final String? originCity;
  final String? destinationCity;
  final DateTime? tripDepartureAt;
  final String? tenantName;
  final String? tenantLogo;

  const Payment({
    required this.id,
    required this.amount,
    required this.currency,
    required this.method,
    required this.status,
    this.transactionId,
    this.providerRef,
    this.paidAt,
    this.failedAt,
    this.failReason,
    required this.createdAt,
    this.bookingReference,
    this.seatNumbers = const [],
    this.bookingTotal,
    this.bookingStatus,
    this.routeName,
    this.originCity,
    this.destinationCity,
    this.tripDepartureAt,
    this.tenantName,
    this.tenantLogo,
  });

  factory Payment.fromJson(Map<String, dynamic> j) {
    final b     = j['booking'] as Map<String, dynamic>?;
    final trip  = b?['trip']   as Map<String, dynamic>?;
    final route = trip?['route']  as Map<String, dynamic>?;
    final tenant = trip?['tenant'] as Map<String, dynamic>?;
    return Payment(
      id:               j['id'],
      amount:           (j['amount'] as num).toDouble(),
      currency:         j['currency'] ?? 'XOF',
      method:           j['method']   ?? 'MOBILE_MONEY',
      status:           j['status']   ?? 'PENDING',
      transactionId:    j['transactionId'],
      providerRef:      j['providerRef'],
      paidAt:           j['paidAt']   != null ? DateTime.parse(j['paidAt'])   : null,
      failedAt:         j['failedAt'] != null ? DateTime.parse(j['failedAt']) : null,
      failReason:       j['failReason'],
      createdAt:        DateTime.parse(j['createdAt']),
      bookingReference: b?['reference'],
      seatNumbers:      List<String>.from(b?['seatNumbers'] ?? []),
      bookingTotal:     b != null ? (b['totalAmount'] as num?)?.toDouble() : null,
      bookingStatus:    b?['status'],
      routeName:        route?['name'],
      originCity:       route?['originCity']?['name'],
      destinationCity:  route?['destinationCity']?['name'],
      tripDepartureAt:  trip?['departureAt'] != null
          ? DateTime.parse(trip!['departureAt']) : null,
      tenantName:       tenant?['name'],
      tenantLogo:       tenant?['logo'],
    );
  }

  bool get isSuccess    => status == 'SUCCESS';
  bool get isFailed     => status == 'FAILED';
  bool get isProcessing => status == 'PROCESSING';
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
