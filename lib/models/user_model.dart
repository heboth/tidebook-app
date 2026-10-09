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
    this.phone = '+45 20 30 40 50',
    this.address = 'Dampfærgevej 30, 2. th',
    this.postalCode = '2100',
    this.city = 'København Ø',
    this.country = 'Danmark',
    this.nationality = 'DK',
    this.passportNumber = 'DK-98124501',
    this.birthDate = '1985-06-14',
    this.savedVehiclePlate = 'CP 48 921',
    this.savedVehicleCategory = 'CAR_STANDARD',
    this.isElectricVehicle = true,
    this.clubMemberNumber = 'NC-2026-88192',
    this.clubTier = 'Nordic Club Guld',
    this.clubPoints = 2450,
    this.preferredCabin = 'Commodore Balcony',
    this.savedCoPassengers = const ['Camilla Jensen', 'Lucas Jensen (Barn)'],
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
      fullName: json['fullName'] ?? json['username'] ?? 'Rejsende',
      phone: json['phone'] ?? '+45 20 30 40 50',
      address: json['address'] ?? 'Dampfærgevej 30, 2. th',
      postalCode: json['postalCode'] ?? '2100',
      city: json['city'] ?? 'København Ø',
      country: json['country'] ?? 'Danmark',
      nationality: json['nationality'] ?? 'DK',
      passportNumber: json['passportNumber'] ?? 'DK-98124501',
      birthDate: json['birthDate'] ?? '1985-06-14',
      savedVehiclePlate: json['savedVehiclePlate'] ?? 'CP 48 921',
      savedVehicleCategory: json['savedVehicleCategory'] ?? 'CAR_STANDARD',
      isElectricVehicle: json['isElectricVehicle'] ?? true,
      clubMemberNumber: json['clubMemberNumber'] ?? 'NC-2026-88192',
      clubTier: json['clubTier'] ?? 'Nordic Club Guld',
      clubPoints: json['clubPoints'] ?? 2450,
      preferredCabin: json['preferredCabin'] ?? 'Commodore Balcony',
      savedCoPassengers: (json['savedCoPassengers'] as List?)?.map((e) => e.toString()).toList() ??
          const ['Camilla Jensen', 'Lucas Jensen (Barn)'],
      role: userRole,
    );
  }
}

