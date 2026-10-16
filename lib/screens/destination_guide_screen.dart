import 'package:flutter/material.dart';
import '../theme/gonordic_theme.dart';
import '../services/texts_service.dart';
import '../widgets/gonordic_banner.dart';
import 'booking_wizard_screen.dart';

class DestinationGuideScreen extends StatelessWidget {
  const DestinationGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoNordicTheme.sand,
      appBar: AppBar(title: Text(tr('destinationGuide.title'))),
      body: ListView(
        children: [
          GoNordicBanner(
            badgeText: 'MINICRUISE',
            text: tr('destinationGuide.bannerText'),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _card(
                  tr('destinationGuide.osloTitle'),
                  tr('destinationGuide.osloText'),
                  'assets/gonordic/images/oslo-opera.jpg',
                ),
                _card(
                  tr('destinationGuide.foodTitle'),
                  tr('destinationGuide.foodText'),
                  'assets/gonordic/images/chef-kitchen.jpg',
                ),
                _card(
                  tr('destinationGuide.shopTitle'),
                  tr('destinationGuide.shopText'),
                  'assets/gonordic/images/taxfree-shop.jpg',
                ),
                _card(
                  tr('destinationGuide.skiTitle'),
                  tr('destinationGuide.skiText'),
                  'assets/gonordic/images/ski-lift.jpg',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BookingWizardScreen(initialTripType: 'CRUISE', initialAdults: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.sailing),
                    label: Text(tr('destinationGuide.bookNow')),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, String desc, String img) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            img,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => Container(
              height: 160,
              color: GoNordicTheme.pineDark,
              child: const Center(child: Icon(Icons.photo, color: Colors.white54, size: 40)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GoNordicTheme.textPrimary)),
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(fontSize: 12, color: GoNordicTheme.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
