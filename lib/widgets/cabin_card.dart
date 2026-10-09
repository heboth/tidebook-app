import 'package:flutter/material.dart';
import '../models/cabin_model.dart';
import '../theme/gonordic_theme.dart';

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

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                Image.asset(
                  cabin.imageAsset,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(
                    height: 140,
                    color: GoNordicTheme.pineDark,
                    child: const Center(child: Icon(Icons.hotel, color: Colors.white54, size: 40)),
                  ),
                ),
                if (cabin.includesBreakfast)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: GoNordicTheme.lime,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'INKL. MORGENMAD',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: GoNordicTheme.pineDark),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        cabin.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${cabin.priceDkk.toInt()} DKK', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: GoNordicTheme.pine)),
                  ],
                ),
                Text(cabin.subtitle, style: const TextStyle(fontSize: 12, color: GoNordicTheme.textSecondary)),
                const SizedBox(height: 8),
                Text(cabin.description, style: const TextStyle(fontSize: 12, color: GoNordicTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? GoNordicTheme.pine : GoNordicTheme.lime,
                      foregroundColor: isSelected ? Colors.white : GoNordicTheme.pineDark,
                    ),
                    child: Text(isSelected ? '✓ Valgt' : 'Vælg kahyt'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
