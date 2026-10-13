enum UserRole {
  person, // Regular passenger/customer
  agent, // Online Agent (OA) / B2B - NOT allowed in passenger app
  groupLeader, // Group leader - NOT allowed in passenger app
}

class UserModel {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String phone;
  final String address;
  final String postalCode;
  final String city;
  final String country;
  final String nationality;
  final String passportNumber;
  final String birthDate;
  final String savedVehiclePlate;
  final String savedVehicleCategory;
  final bool isElectricVehicle;
  final String clubMemberNumber;
  final String clubTier;
  final int clubPoints;
  final String preferredCabin;
  final List<String> savedCoPassengers;
  final UserRole role;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    // Ingen standard-stamdata: felter, som Core/kunden ikke har udfyldt, står tomme
    this.phone = '',
    this.address = '',
    this.postalCode = '',
    this.city = '',
    this.country = '',
    this.nationality = '',
    this.passportNumber = '',
    this.birthDate = '',
    this.savedVehiclePlate = '',
    this.savedVehicleCategory = '',
    this.isElectricVehicle = false,
    this.clubMemberNumber = '',
    this.clubTier = '',
    this.clubPoints = 0,
    this.preferredCabin = '',
    this.savedCoPassengers = const [],
    this.role = UserRole.person,
  });

  bool get isCustomer => role == UserRole.person;
  bool get isAgent => role == UserRole.agent;
  bool get isGroupLeader => role == UserRole.groupLeader;

  UserModel copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? address,
    String? postalCode,
    String? city,
    String? nationality,
    String? passportNumber,
    String? savedVehiclePlate,
    String? savedVehicleCategory,
    bool? isElectricVehicle,
  }) {
    return UserModel(
      id: id,
      username: username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      country: country,
      nationality: nationality ?? this.nationality,
      passportNumber: passportNumber ?? this.passportNumber,
      birthDate: birthDate,
      savedVehiclePlate: savedVehiclePlate ?? this.savedVehiclePlate,
      savedVehicleCategory: savedVehicleCategory ?? this.savedVehicleCategory,
      isElectricVehicle: isElectricVehicle ?? this.isElectricVehicle,
      clubMemberNumber: clubMemberNumber,
      clubTier: clubTier,
      clubPoints: clubPoints,
      preferredCabin: preferredCabin,
      savedCoPassengers: savedCoPassengers,
      role: role,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    UserRole userRole = UserRole.person;
    final rList = json['roles'] as List?;
    if (rList != null && rList.contains('Agent')) {
      userRole = UserRole.agent;
    } else if (rList != null && rList.contains('GroupLeader')) {
      userRole = UserRole.groupLeader;
    }

    return UserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? json['email'] ?? json['username'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      postalCode: json['postalCode'] ?? '',
      city: json['city'] ?? '',
      country: json['country'] ?? '',
      nationality: json['nationality'] ?? '',
      passportNumber: json['passportNumber'] ?? '',
      birthDate: json['birthDate'] ?? '',
      savedVehiclePlate: json['savedVehiclePlate'] ?? '',
      savedVehicleCategory: json['savedVehicleCategory'] ?? '',
      isElectricVehicle: json['isElectricVehicle'] ?? false,
      clubMemberNumber: json['clubMemberNumber'] ?? '',
      clubTier: json['clubTier'] ?? '',
      clubPoints: json['clubPoints'] ?? 0,
      preferredCabin: json['preferredCabin'] ?? '',
      savedCoPassengers: (json['savedCoPassengers'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      role: userRole,
    );
  }
}

