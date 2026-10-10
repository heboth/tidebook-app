import 'package:flutter/material.dart';
import '../theme/gonordic_theme.dart';
import '../services/texts_service.dart';

class GoNordicBanner extends StatelessWidget {
  // Uden tekst bruges standardtilbuddet fra sprogfilen
  final String? text;
  final String? badgeText;

  const GoNordicBanner({
    super.key,
    this.text,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: const BoxDecoration(
        color: Color(0xFF1E6460),
        border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: GoNordicTheme.lime,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badgeText ?? tr('widgets.banner.defaultBadge'),
              style: const TextStyle(
                color: GoNordicTheme.pineDark,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text ?? tr('widgets.banner.defaultText'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
