import '../services/texts_service.dart';

/// Et tilvalg, som det kommer fra Core (/api/addons). Appen har intet eget katalog.
class AddOnModel {
  final String id;
  final String name;
  final String description;

  /// Prisen på afgangen fra TideRMS (via Core's /departures/:id/availability). null = ukendt – katalogets
  /// basePriceDkk er kun vejledende og vises aldrig som pris.
  final double? priceDkk;
  final String category;
  final bool isActive;
  final DateTime? validFrom;
  final DateTime? validTo;

  /// Partnerbillet (fx Tivoli, LEGOLAND): prisen afhænger af dato og evt. tidspunkt og kommer fra partneren
  final bool isPartner;
  final String partnerName;

  const AddOnModel({
    required this.id,
    required this.name,
    required this.description,
    required this.priceDkk,
    required this.category,
    this.isActive = true,
    this.validFrom,
    this.validTo,
    this.isPartner = false,
    this.partnerName = '',
  });

  factory AddOnModel.fromJson(Map<String, dynamic> json) {
    return AddOnModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priceDkk: null,
      category: json['category']?.toString() ?? '',
      // Mangler feltet, regnes tilvalget ikke som aktivt
      isActive: json['isActive'] == true,
      validFrom: DateTime.tryParse(json['validFrom']?.toString() ?? ''),
      validTo: DateTime.tryParse(json['validTo']?.toString() ?? ''),
      isPartner: json['pricingModel'] == 'DYNAMIC_API',
      partnerName: (json['externalProviderConfig'] as Map?)?['partnerName']?.toString() ?? '',
    );
  }

  /// Navnet på appens sprog (`addOns.<id>` i tekstpakken/TideCMS); ellers Core's navn (dansk).
  String get label {
    final key = 'addOns.$id';
    final text = tr(key);
    return text == key ? name : text;
  }

  /// Samme tilvalg med prisen fra TideRMS.
  AddOnModel withPrice(double? price) => AddOnModel(
        id: id, name: name, description: description, priceDkk: price, category: category,
        isActive: isActive, validFrom: validFrom, validTo: validTo, isPartner: isPartner, partnerName: partnerName,
      );

  /// Aktivt og gyldigt på datoen (validTo gælder hele dagen).
  bool isAvailableOn(DateTime date) {
    if (!isActive || id.isEmpty) return false;
    final day = DateTime(date.year, date.month, date.day);
    if (validFrom != null && day.isBefore(DateTime(validFrom!.year, validFrom!.month, validFrom!.day))) return false;
    if (validTo != null && day.isAfter(DateTime(validTo!.year, validTo!.month, validTo!.day))) return false;
    return true;
  }
}
