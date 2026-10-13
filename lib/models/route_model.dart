class RouteModel {
  final String id;
  final String name;
  final String originPortCode;
  final String originPortName;
  final String originTerminal;
  final String destinationPortCode;
  final String destinationPortName;
  final String destinationTerminal;
  final double distanceNauticalMiles;
  final int durationMinutes;

  const RouteModel({
    required this.id,
    required this.name,
    required this.originPortCode,
    required this.originPortName,
    required this.originTerminal,
    required this.destinationPortCode,
    required this.destinationPortName,
    required this.destinationTerminal,
    required this.distanceNauticalMiles,
    required this.durationMinutes,
  });

  String get durationString {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    return '${hours}t ${mins > 0 ? '$mins min' : ''}';
  }

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final origin = json['originPort'] is Map ? json['originPort'] : {};
    final destination = json['destinationPort'] is Map ? json['destinationPort'] : {};
    return RouteModel(
      // Kun Core's data – mangler et felt, står det tomt (ingen indbyggede havne eller distancer)
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      originPortCode: origin['code'] ?? '',
      originPortName: origin['name'] ?? '',
      originTerminal: origin['terminal'] ?? '',
      destinationPortCode: destination['code'] ?? '',
      destinationPortName: destination['name'] ?? '',
      destinationTerminal: destination['terminal'] ?? '',
      distanceNauticalMiles: (json['distanceNauticalMiles'] as num?)?.toDouble() ?? 0,
      durationMinutes: (json['standardDurationMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'originPort': {
      'code': originPortCode,
      'name': originPortName,
      'terminal': originTerminal,
    },
    'destinationPort': {
      'code': destinationPortCode,
      'name': destinationPortName,
      'terminal': destinationTerminal,
    },
    'distanceNauticalMiles': distanceNauticalMiles,
    'standardDurationMinutes': durationMinutes,
  };
}
