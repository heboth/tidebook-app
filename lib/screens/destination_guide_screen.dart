import 'package:flutter/material.dart';
import '../theme/gonordic_theme.dart';
import '../widgets/gonordic_banner.dart';
import 'booking_wizard_screen.dart';

class DestinationGuideScreen extends StatelessWidget {
  const DestinationGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoNordicTheme.sand,
      appBar: AppBar(title: const Text('Oplev Ombord & Destinationer')),
      body: ListView(
        children: [
          const GoNordicBanner(
            badgeText: 'MINICRUISE',
            text: '2 nætter til søs og 5 timer til at udforske smukke Oslo',
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _card(
                  'Oslo Operahus & Fjordbyen',
                  'Gå en tur på det ikoniske marmortag på Oslo Operaen og nyd udsigten over fjorden, Munch Museet og Barcode.',
                  'assets/gonordic/images/oslo-opera.jpg',
                ),
                _card(
                  'Gastronomi & Skandinaviske Buffeter',
                  'Vores dygtige kokke tryller med frisk fisk, saftigt kød, nordiske oste og lækre desserter i 7 Seas og Explorers Steakhouse.',
                  'assets/gonordic/images/chef-kitchen.jpg',
                ),
                _card(
                  'Tax-Free Sea Shop Ombord',
                  'Shop parfume, kosmetik, skandinavisk slik, spiritus og mærkevarer med op til 20-40% rabat i forhold til landpriser.',
                  'assets/gonordic/images/taxfree-shop.jpg',
                ),
                _card(
                  'Skiferie i de Norske Fjelde',
                  'Tag bilen med til Norefjell, Hemsedal, Hafjell eller Trysil. Nem og udhvilet ankomst i Oslo kl. 10:00.',
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
                          builder: (_) => const BookingWizardScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.sailing),
                    label: const Text('Book MiniCruise Nu →'),
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
