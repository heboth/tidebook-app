import '../utils/port_time.dart';

class DepartureModel {
  final String id;
  final String routeId;
  final String vesselId;
  final String vesselName;
  final DateTime scheduledDepartureTime;
  final DateTime scheduledArrivalTime;
  final String gateNumber;
  final bool checkInOpen;

  const DepartureModel({
    required this.id,
    required this.routeId,
    required this.vesselId,
    required this.vesselName,
    required this.scheduledDepartureTime,
    required this.scheduledArrivalTime,
    required this.gateNumber,
    required this.checkInOpen,
  });

  /// Afgangstid i havnens tid (ikke telefonens tidszone)
  String get timeFormatted => portClock(scheduledDepartureTime);

  String get arrivalTimeFormatted => portClock(scheduledArrivalTime);

  /// Afgangsdato (YYYY-MM-DD) i havnens tid
  String get portDate => portIsoDate(scheduledDepartureTime);

  String get dateFormatted {
    final d = portTime(scheduledDepartureTime);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  /// Bygger en afgang fra Core. Uden id, rute eller gyldige tider opfindes der ingen afgang (null).
  static DepartureModel? tryFromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final routeId = json['routeId']?.toString() ?? '';
    final dep = DateTime.tryParse(json['scheduledDepartureTime']?.toString() ?? '');
    final arr = DateTime.tryParse(json['scheduledArrivalTime']?.toString() ?? '');
    if (id.isEmpty || routeId.isEmpty || dep == null) return null;
    if (json['status'] == 'CANCELLED') return null;
    return DepartureModel(
      id: id,
      routeId: routeId,
      vesselId: json['vesselId']?.toString() ?? '',
      vesselName: json['vesselName']?.toString() ?? '',
      scheduledDepartureTime: dep,
      scheduledArrivalTime: arr ?? dep,
      gateNumber: json['gateNumber']?.toString() ?? '',
      checkInOpen: json['checkInOpen'] == true,
    );
  }
}
