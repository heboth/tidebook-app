enum PassengerType { adult, child, infant }

class PassengerModel {
  final String id;
  final String firstName;
  final String lastName;
  final PassengerType type;
  final String nationality;

  const PassengerModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.type,
    this.nationality = 'DK',
  });

  String get fullName => '$firstName $lastName'.trim();

  factory PassengerModel.fromJson(Map<String, dynamic> json) {
    PassengerType pType = PassengerType.adult;
    final tStr = (json['type'] ?? 'ADULT').toString().toUpperCase();
    if (tStr == 'CHILD') pType = PassengerType.child;
    if (tStr == 'INFANT') pType = PassengerType.infant;

    return PassengerModel(
      id: json['id'] ?? 'P1',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      type: pType,
      nationality: json['nationality'] ?? 'DK',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'type': type.name.toUpperCase(),
    'nationality': nationality,
  };
}

class VehicleModel {
  final String category; // 'CAR_STANDARD', 'CAR_LARGE', 'MOTORCYCLE', 'NONE'
  final String licensePlate;
  final String country;
  final bool isElectric;

  const VehicleModel({
    required this.category,
    required this.licensePlate,
    this.country = 'DK',
    this.isElectric = false,
  });

  bool get hasVehicle => category != 'NONE';

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      category: json['category'] ?? 'NONE',
      licensePlate: json['licensePlate'] ?? '',
      country: json['country'] ?? 'DK',
      isElectric: json['isElectric'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'category': category,
    'licensePlate': licensePlate,
    'country': country,
    'isElectric': isElectric,
  };
}
