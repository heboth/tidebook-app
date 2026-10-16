import 'package:flutter/material.dart';
import '../models/cabin_model.dart';
import '../services/texts_service.dart';
import '../theme/gonordic_theme.dart';

/// En kahytskategori fra Core. Viser ingen pris – prisen kommer fra Core's prisberegning
/// for det samlede valg.
class CabinCard extends StatelessWidget {
  final CabinModel cabin;
  final bool isSelected;
  final VoidCallback onSelect;

  const CabinCard({
    super.key,
    required this.cabin,
    required this.isSelected,
    required this.onSelect,
  });

  /// Kategoriens navn fra tekstpakken; findes det ikke, vises Core's kode.
  static String categoryLabel(String code) => CabinModel.categoryLabel(code);

  /// Billede efter kategoriens første bogstav (kun udseende – ingen data).
  static String? _imageFor(String code) {
    switch (code.isEmpty ? '' : code[0]) {
      case 'O':
      case 'J':
        return 'assets/gonordic/images/cabin-owners-suite.jpg';
      case 'X':
        return 'assets/gonordic/images/cabin-commodore-deluxe.jpg';
      case 'C':
      case 'W':
        return 'assets/gonordic/images/cabin-commodore-seaview.jpg';
      case 'A':
        return 'assets/gonordic/images/cabin-standard-seaview.jpg';
      case 'B':
        return 'assets/gonordic/images/cabin-standard-inside.jpg';
      case 'E':
        return 'assets/gonordic/images/cabin-economy-inside.jpg';
      case 'F':
      case 'G':
        return 'assets/gonordic/images/cabin-pet.jpg';
      case 'H':
      case 'I':
        return 'assets/gonordic/images/cabin-handicap.jpg';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _imageFor(cabin.category);
    final placeholder = Container(
      height: 110,
      color: GoNordicTheme.pineDark,
      child: const Center(child: Icon(Icons.hotel, color: Colors.white54, size: 40)),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? GoNordicTheme.pine : GoNordicTheme.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: image == null
                  ? placeholder
                  : Image.asset(
                      image,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => placeholder,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          categoryLabel(cabin.category),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(cabin.category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: GoNordicTheme.pine)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (cabin.berths > 0) tr('widgets.cabinCard.berths', {'count': cabin.berths}),
                      if (cabin.decks.isNotEmpty) tr('widgets.cabinCard.decks', {'decks': cabin.decks.join(', ')}),
                      tr('widgets.cabinCard.free', {'count': cabin.freeCount}),
                    ].join(' • '),
                    style: const TextStyle(fontSize: 12, color: GoNordicTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onSelect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? GoNordicTheme.pine : GoNordicTheme.lime,
                        foregroundColor: isSelected ? Colors.white : GoNordicTheme.pineDark,
                      ),
                      child: Text(isSelected ? tr('widgets.cabinCard.selected') : tr('widgets.cabinCard.select')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
