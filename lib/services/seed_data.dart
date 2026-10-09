import '../models/route_model.dart';
import '../models/departure_model.dart';
import '../models/passenger_model.dart';
import '../models/booking_model.dart';

class SeedData {
  static List<RouteModel> getRoutes() => const [
        RouteModel(
          id: 'ROUTE-CPH-OSL',
          name: 'København – Oslo (Kattegat & Oslofjorden)',
          originPortCode: 'DKCPH',
          originPortName: 'København Havn',
          originTerminal: 'DFDS Terminalen, Dampfærgevej 30',
          destinationPortCode: 'NOOSL',
          destinationPortName: 'Oslo Havn',
          destinationTerminal: 'Revierkaia / Vippetangen',
          distanceNauticalMiles: 274.0,
          durationMinutes: 1050,
        ),
        RouteModel(
          id: 'ROUTE-OSL-CPH',
          name: 'Oslo – København (Oslofjorden & Kattegat)',
          originPortCode: 'NOOSL',
          originPortName: 'Oslo Havn',
          originTerminal: 'Revierkaia / Vippetangen',
          destinationPortCode: 'DKCPH',
          destinationPortName: 'København Havn',
          destinationTerminal: 'DFDS Terminalen, Dampfærgevej 30',
          distanceNauticalMiles: 274.0,
          durationMinutes: 1050,
        ),
      ];

  static List<DepartureModel> getDepartures() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dep1 = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 16, 30);
    return [
      DepartureModel(
        id: 'DEP-CPH-OSL-TOMORROW',
        routeId: 'ROUTE-CPH-OSL',
        vesselId: 'VESSEL-CROWN',
        vesselName: 'Crown Seaways',
        scheduledDepartureTime: dep1,
        scheduledArrivalTime: dep1.add(const Duration(hours: 17, minutes: 30)),
        gateNumber: 'Gate 1 (Terminal Dampfærgevej)',
        checkInOpen: true,
        basePriceDkk: 890,
      ),
      DepartureModel(
        id: 'DEP-OSL-CPH-TOMORROW',
        routeId: 'ROUTE-OSL-CPH',
        vesselId: 'VESSEL-PEARL',
        vesselName: 'Pearl Seaways',
        scheduledDepartureTime: dep1,
        scheduledArrivalTime: dep1.add(const Duration(hours: 17, minutes: 30)),
        gateNumber: 'Gate 2 (Revierkaia Oslo)',
        checkInOpen: true,
        basePriceDkk: 890,
      ),
    ];
  }

  static List<BookingModel> getInitialBookings() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final tomorrow = DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0];

    return [
      BookingModel(
        pnr: 'TIDE-9021',
        bookingCode: 'BK-2026-9021',
        routeId: 'ROUTE-CPH-OSL',
        routeName: 'København – Oslo',
        departureId: 'DEP-CPH-OSL-TOMORROW',
        departureDate: tomorrow,
        departureTime: '16:30',
        arrivalTime: '10:00 (+1)',
        vesselName: 'Crown Seaways',
        status: 'CONFIRMED',
        ticketClass: 'PREMIUM',
        passengers: const [
          PassengerModel(id: 'P1', firstName: 'Mads', lastName: 'Jensen', type: PassengerType.adult),
          PassengerModel(id: 'P2', firstName: 'Camilla', lastName: 'Jensen', type: PassengerType.adult),
        ],
        vehicle: const VehicleModel(category: 'CAR_STANDARD', licensePlate: 'CP 48 921', isElectric: true),
        selectedCabinIds: const ['CAB-CROW-1101'],
        cabinTitle: 'Commodore Balcony (Dæk 11)',
        cabinNumbers: const ['CAB-CROW-1101'],
        addOns: const [
          {'name': 'Skandinavisk Morgenmadsbuffet', 'quantity': 2, 'price': 149},
          {'name': 'Commodore VIP Lounge Pass', 'quantity': 2, 'price': 195},
        ],
        leadContactName: 'Mads Jensen',
        leadContactEmail: 'mads.jensen@example.dk',
        leadContactPhone: '+45 20 30 40 50',
        totalAmountDkk: 4253,
        paymentStatus: 'PAID',
        gateNumber: 'Gate 1 (Terminal Dampfærgevej)',
      ),
      BookingModel(
        pnr: 'TIDE-4412',
        bookingCode: 'BK-2026-4412',
        routeId: 'ROUTE-CPH-OSL',
        routeName: 'København – Oslo',
        departureId: 'DEP-CPH-OSL-TODAY',
        departureDate: today,
        departureTime: '16:30',
        arrivalTime: '10:00 (+1)',
        vesselName: 'Crown Seaways',
        status: 'CHECKED_IN',
        ticketClass: 'FLEX',
        passengers: const [
          PassengerModel(id: 'P3', firstName: 'Henrik', lastName: 'Lindqvist', type: PassengerType.adult, nationality: 'NO'),
          PassengerModel(id: 'P4', firstName: 'Ingrid', lastName: 'Lindqvist', type: PassengerType.adult, nationality: 'NO'),
        ],
        vehicle: const VehicleModel(category: 'CAR_LARGE', licensePlate: 'EK 88219', isElectric: true),
        selectedCabinIds: const ['CAB-CROW-9101'],
        cabinTitle: 'Commodore Havudsigt (Dæk 9)',
        cabinNumbers: const ['CAB-CROW-9101'],
        addOns: const [
          {'name': 'Prioriteret Ombordkørsel', 'quantity': 1, 'price': 180},
          {'name': 'Stor 7 Seas Aftenbuffet', 'quantity': 2, 'price': 289},
        ],
        leadContactName: 'Henrik Lindqvist',
        leadContactEmail: 'henrik.lindqvist@oslo-fjord.no',
        leadContactPhone: '+47 912 34 567',
        totalAmountDkk: 3373,
        paymentStatus: 'PAID',
        gateNumber: 'Gate 1 (Bilbane 3)',
      ),
    ];
  }
}
