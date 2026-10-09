import 'passenger_model.dart';

class BookingModel {
  final String pnr;
  final String bookingCode;
  final String routeId;
  final String routeName;
  final String departureId;
  final String departureDate;
  final String departureTime;
  final String arrivalTime;
  final String vesselName;
  final String status; // 'CONFIRMED', 'CHECKED_IN', 'CANCELLED'
  final String ticketClass; // 'STANDARD', 'FLEX', 'PREMIUM'
  final List<PassengerModel> passengers;
  final VehicleModel? vehicle;
  final List<String> selectedCabinIds;
  final String cabinTitle;
  final List<String> cabinNumbers;
  final List<Map<String, dynamic>> addOns;
  final String leadContactName;
  final String leadContactEmail;
  final String leadContactPhone;
  final double totalAmountDkk;
  final String paymentStatus;
  final String gateNumber;
  final bool isDirectCustomer;
  final DateTime createdAt;

  BookingModel({
    required this.pnr,
    required this.bookingCode,
    required this.routeId,
    required this.routeName,
    required this.departureId,
    required this.departureDate,
    required this.departureTime,
    required this.arrivalTime,
    required this.vesselName,
    required this.status,
    required this.ticketClass,
    required this.passengers,
    this.vehicle,
    required this.selectedCabinIds,
    required this.cabinTitle,
    required this.cabinNumbers,
    required this.addOns,
    required this.leadContactName,
    required this.leadContactEmail,
    required this.leadContactPhone,
    required this.totalAmountDkk,
    required this.paymentStatus,
    this.gateNumber = 'Gate 1 (Terminal Dampfærgevej)',
    this.isDirectCustomer = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCheckedIn => status == 'CHECKED_IN';
  bool get isCancelled => status == 'CANCELLED';

  String get qrPayload =>
      'TB:$pnr:${passengers.isNotEmpty ? passengers.first.id : "PAX"}:$departureDate';

  BookingModel copyWith({
    String? status,
    List<PassengerModel>? passengers,
    VehicleModel? vehicle,
    List<String>? cabinNumbers,
    List<Map<String, dynamic>>? addOns,
  }) {
    return BookingModel(
      pnr: pnr,
      bookingCode: bookingCode,
      routeId: routeId,
      routeName: routeName,
      departureId: departureId,
      departureDate: departureDate,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      vesselName: vesselName,
      status: status ?? this.status,
      ticketClass: ticketClass,
      passengers: passengers ?? this.passengers,
      vehicle: vehicle ?? this.vehicle,
      selectedCabinIds: selectedCabinIds,
      cabinTitle: cabinTitle,
      cabinNumbers: cabinNumbers ?? this.cabinNumbers,
      addOns: addOns ?? this.addOns,
      leadContactName: leadContactName,
      leadContactEmail: leadContactEmail,
      leadContactPhone: leadContactPhone,
      totalAmountDkk: totalAmountDkk,
      paymentStatus: paymentStatus,
      gateNumber: gateNumber,
      isDirectCustomer: isDirectCustomer,
      createdAt: createdAt,
    );
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final lead = json['leadContact'] is Map ? json['leadContact'] : {};
    final fare = json['fareBreakdown'] is Map ? json['fareBreakdown'] : {};
    final paxList = (json['passengers'] as List?)
            ?.map((p) => PassengerModel.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    final veh = json['vehicle'] != null
        ? VehicleModel.fromJson(json['vehicle'] as Map<String, dynamic>)
        : null;

    final cabinIds = (json['selectedCabinIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return BookingModel(
      pnr: json['pnr'] ?? '',
      bookingCode: json['bookingCode'] ?? json['pnr'] ?? '',
      routeId: json['routeId'] ?? 'ROUTE-CPH-OSL',
      routeName: json['routeName'] ??
          (json['routeId'] == 'ROUTE-OSL-CPH'
              ? 'Oslo – København'
              : 'København – Oslo (Kattegat & Oslofjorden)'),
      departureId: json['departureId'] ?? '',
      departureDate: json['outboundDate'] ??
          DateTime.now().toIso8601String().split('T')[0],
      departureTime: json['departureTime'] ?? '16:30',
      arrivalTime: json['arrivalTime'] ?? '10:00 (+1)',
      vesselName: json['vesselName'] ?? 'Crown Seaways',
      status: json['status'] ?? 'CONFIRMED',
      ticketClass: json['ticketClass'] ?? 'PREMIUM',
      passengers: paxList,
      vehicle: veh,
      selectedCabinIds: cabinIds,
      cabinTitle: json['cabinTitle'] ??
          (cabinIds.isNotEmpty ? 'Commodore Balcony' : 'Standard Kahyt'),
      cabinNumbers: cabinIds.isNotEmpty ? cabinIds : ['CAB-CROW-1101'],
      addOns: (json['addOns'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      leadContactName: lead['fullName'] ?? 'Mads Jensen',
      leadContactEmail: lead['email'] ?? 'mads.jensen@example.dk',
      leadContactPhone: lead['phone'] ?? '+45 20 30 40 50',
      totalAmountDkk: (fare['totalAmountDkk'] as num?)?.toDouble() ?? 4253.0,
      paymentStatus: json['paymentStatus'] ?? 'PAID',
      gateNumber: json['gateNumber'] ?? 'Gate 1 (Terminal Dampfærgevej)',
      isDirectCustomer: json['agentId'] == null && json['bookedByAgent'] == null,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
