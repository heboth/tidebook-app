import 'passenger_model.dart';

class BoardingPassModel {
  final String passengerId;
  final String passengerName;
  final String qrPayload;
  final String? seatOrCabin;

  const BoardingPassModel({
    required this.passengerId,
    required this.passengerName,
    required this.qrPayload,
    this.seatOrCabin,
  });

  factory BoardingPassModel.fromJson(Map<String, dynamic> json) {
    return BoardingPassModel(
      passengerId: json['passengerId']?.toString() ?? '',
      passengerName: json['passengerName']?.toString() ?? '',
      qrPayload: json['qrPayload']?.toString() ?? '',
      seatOrCabin: json['seatOrCabin']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'passengerId': passengerId,
    'passengerName': passengerName,
    'qrPayload': qrPayload,
    if (seatOrCabin != null) 'seatOrCabin': seatOrCabin,
  };
}

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

  /// Salgskanalen fra Core ('B2C', 'AGENT', 'CALL_CENTER', 'OTA') – null hvis Core ikke sender den
  final String? channel;
  final bool isGroupBooking;
  final DateTime createdAt;
  final List<BoardingPassModel> boardingPasses;
  final String? bookingToken;

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
    this.channel,
    this.isGroupBooking = false,
    DateTime? createdAt,
    this.boardingPasses = const [],
    this.bookingToken,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCheckedIn => status == 'CHECKED_IN' || boardingPasses.isNotEmpty;
  bool get isCancelled => status == 'CANCELLED';

  /// Official scannable QR payload issued by Core check-in response
  String? get qrPayload =>
      boardingPasses.isNotEmpty ? boardingPasses.first.qrPayload : null;

  BookingModel copyWith({
    String? status,
    List<PassengerModel>? passengers,
    VehicleModel? vehicle,
    List<String>? cabinNumbers,
    List<Map<String, dynamic>>? addOns,
    String? paymentStatus,
    List<BoardingPassModel>? boardingPasses,
    String? bookingToken,
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
      paymentStatus: paymentStatus ?? this.paymentStatus,
      gateNumber: gateNumber,
      isDirectCustomer: isDirectCustomer,
      channel: channel,
      isGroupBooking: isGroupBooking,
      createdAt: createdAt,
      boardingPasses: boardingPasses ?? this.boardingPasses,
      bookingToken: bookingToken ?? this.bookingToken,
    );
  }

  factory BookingModel.fromJson(Map<String, dynamic> json, {String? bookingToken}) {
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

    final rawBoardingPasses = <BoardingPassModel>[];
    if (json['boardingPasses'] is List) {
      for (final bp in json['boardingPasses']) {
        if (bp is Map) {
          rawBoardingPasses.add(BoardingPassModel.fromJson(Map<String, dynamic>.from(bp)));
        }
      }
    } else if (json['passengerBoardingPasses'] is List) {
      for (final bp in json['passengerBoardingPasses']) {
        if (bp is Map) {
          rawBoardingPasses.add(BoardingPassModel.fromJson(Map<String, dynamic>.from(bp)));
        }
      }
    } else if (json['checkedInLegs'] is List) {
      for (final leg in json['checkedInLegs']) {
        if (leg is Map && leg['passengerBoardingPasses'] is List) {
          for (final bp in leg['passengerBoardingPasses']) {
            if (bp is Map) {
              rawBoardingPasses.add(BoardingPassModel.fromJson(Map<String, dynamic>.from(bp)));
            }
          }
        }
      }
    }

    final effectiveToken = bookingToken ?? json['bookingToken']?.toString();

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
      vesselName: json['vesselName'] ?? '',
      // Mangler et felt, opfindes der ikke data: en booking uden status/betaling er ikke bekræftet eller betalt
      status: json['status'] ?? 'PENDING',
      ticketClass: json['ticketClass'] ?? 'STANDARD',
      passengers: paxList,
      vehicle: veh,
      selectedCabinIds: cabinIds,
      cabinTitle: json['cabinTitle'] ?? (cabinIds.isNotEmpty ? 'Kahyt' : 'Ingen kahyt'),
      cabinNumbers: cabinIds,
      addOns: (json['addOns'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      leadContactName: lead['fullName'] ?? '',
      leadContactEmail: lead['email'] ?? '',
      leadContactPhone: lead['phone'] ?? '',
      totalAmountDkk: (fare['totalAmountDkk'] as num?)?.toDouble() ??
          (json['totalAmountDkk'] as num?)?.toDouble() ??
          0.0,
      paymentStatus: json['paymentStatus'] ?? 'PENDING',
      gateNumber: json['gateNumber'] ?? 'Gate 1 (Terminal Dampfærgevej)',
      isDirectCustomer: json['agentId'] == null && json['bookedByAgent'] == null,
      channel: json['channel']?.toString(),
      isGroupBooking: json['isGroupBooking'] == true,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      boardingPasses: rawBoardingPasses,
      bookingToken: effectiveToken,
    );
  }
}
