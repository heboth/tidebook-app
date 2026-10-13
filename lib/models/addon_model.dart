/// Et tilvalg, som det kommer fra Core (/api/addons). Appen har intet eget katalog.
class AddOnModel {
  final String id;
  final String name;
  final String description;

  /// Core's listepris (basePriceDkk). Den endelige pris beregnes af Core/TideRMS i prisberegningen.
  final double? priceDkk;
  final String category;
  final bool isActive;
  final DateTime? validFrom;
  final DateTime? validTo;

  const AddOnModel({
    required this.id,
    required this.name,
    required this.description,
    required this.priceDkk,
    required this.category,
    this.isActive = true,
    this.validFrom,
    this.validTo,
  });

  factory AddOnModel.fromJson(Map<String, dynamic> json) {
    return AddOnModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priceDkk: (json['basePriceDkk'] as num?)?.toDouble(),
      category: json['category']?.toString() ?? '',
      // Mangler feltet, regnes tilvalget ikke som aktivt
      isActive: json['isActive'] == true,
      validFrom: DateTime.tryParse(json['validFrom']?.toString() ?? ''),
      validTo: DateTime.tryParse(json['validTo']?.toString() ?? ''),
    );
  }

  /// Aktivt og gyldigt på datoen (validTo gælder hele dagen).
  bool isAvailableOn(DateTime date) {
    if (!isActive || id.isEmpty) return false;
    final day = DateTime(date.year, date.month, date.day);
    if (validFrom != null && day.isBefore(DateTime(validFrom!.year, validFrom!.month, validFrom!.day))) return false;
    if (validTo != null && day.isAfter(DateTime(validTo!.year, validTo!.month, validTo!.day))) return false;
    return true;
  }
}
