class DepartureModel {
  final String id;
  final String routeId;
  final String vesselId;
  final String vesselName;
  final DateTime scheduledDepartureTime;
  final DateTime scheduledArrivalTime;
  final String gateNumber;
  final bool checkInOpen;
  final double basePriceDkk;

  const DepartureModel({
    required this.id,
    required this.routeId,
    required this.vesselId,
    required this.vesselName,
    required this.scheduledDepartureTime,
    required this.scheduledArrivalTime,
    required this.gateNumber,
    required this.checkInOpen,
    required this.basePriceDkk,
  });

  String get timeFormatted {
    final hour = scheduledDepartureTime.hour.toString().padLeft(2, '0');
    final minute = scheduledDepartureTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get arrivalTimeFormatted {
    final hour = scheduledArrivalTime.hour.toString().padLeft(2, '0');
    final minute = scheduledArrivalTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get dateFormatted {
    final d = scheduledDepartureTime;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  factory DepartureModel.fromJson(Map<String, dynamic> json) {
    return DepartureModel(
      id: json['id'] ?? '',
      routeId: json['routeId'] ?? '',
      vesselId: json['vesselId'] ?? 'VESSEL-CROWN',
      vesselName: json['vesselName'] ?? (json['vesselId'] == 'VESSEL-PEARL' ? 'Pearl Seaways' : 'Crown Seaways'),
      scheduledDepartureTime: DateTime.tryParse(json['scheduledDepartureTime'] ?? '') ?? DateTime.now(),
      scheduledArrivalTime: DateTime.tryParse(json['scheduledArrivalTime'] ?? '') ?? DateTime.now().add(const Duration(hours: 17, minutes: 30)),
      gateNumber: json['gateNumber'] ?? 'Gate 1',
      checkInOpen: json['checkInOpen'] ?? true,
      basePriceDkk: (json['basePriceDkk'] as num?)?.toDouble() ?? 890.0,
    );
  }
}
