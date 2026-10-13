/// En kahytskategori på en afgang, samlet fra Core's kahytsliste (/api/departures/:id/cabins).
/// Kategorien er Core's BookIT-kode (fx X2, B4). Prisen kommer kun fra Core's prisberegning.
class CabinModel {
  final String category;
  final int berths;
  final List<String> freeCabinIds;
  final List<int> decks;
  final String bedType;

  const CabinModel({
    required this.category,
    required this.berths,
    required this.freeCabinIds,
    required this.decks,
    this.bedType = '',
  });

  /// Den kahyt, der reserveres, når kategorien vælges (første ledige).
  String get cabinId => freeCabinIds.first;
  int get freeCount => freeCabinIds.length;

  /// Grupperer Core's kahytter pr. kategori – kun ledige kahytter tæller med.
  static List<CabinModel> fromCoreCabins(List<Map<String, dynamic>> cabins) {
    final byCategory = <String, List<Map<String, dynamic>>>{};
    for (final c in cabins) {
      if (c['isBookedOnDeparture'] == true || c['isBooked'] == true) continue;
      final id = c['id']?.toString();
      final category = c['category']?.toString();
      if (id == null || id.isEmpty || category == null || category.isEmpty) continue;
      byCategory.putIfAbsent(category, () => []).add(c);
    }
    final result = byCategory.entries.map((e) {
      final decks = e.value.map((c) => (c['deck'] as num?)?.toInt()).whereType<int>().toSet().toList()..sort();
      final berths = e.value.map((c) => (c['berths'] as num?)?.toInt() ?? 0).fold<int>(0, (a, b) => a > b ? a : b);
      return CabinModel(
        category: e.key,
        berths: berths,
        freeCabinIds: e.value.map((c) => c['id'].toString()).toList(),
        decks: decks,
        bedType: e.value.first['bedType']?.toString() ?? '',
      );
    }).toList()
      ..sort((a, b) => a.category.compareTo(b.category));
    return result;
  }
}
