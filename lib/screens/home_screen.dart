import 'package:flutter/material.dart';
import '../services/booking_service.dart';
import '../services/texts_service.dart';
import '../theme/gonordic_theme.dart';
import 'explore_screen.dart';
import 'booking_wizard_screen.dart';
import 'my_bookings_screen.dart';
import 'boarding_pass_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BookingService(),
      builder: (context, _) {
        final activeBooking = BookingService().activeBooking;

        final List<Widget> screens = [
          ExploreScreen(
            onNavigateToTab: (index) => setState(() => _currentIndex = index),
          ),
          BookingWizardScreen(
            onFinished: () => setState(() => _currentIndex = 2),
          ),
          const MyBookingsScreen(),
          activeBooking != null
              ? BoardingPassScreen(booking: activeBooking)
              : Scaffold(
                  backgroundColor: GoNordicTheme.sand,
                  appBar: AppBar(title: Text(tr('home.noPass.title'))),
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.qr_code_2, size: 64, color: GoNordicTheme.teal),
                              const SizedBox(height: 12),
                              Text(
                                tr('home.noPass.heading'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tr('home.noPass.body'),
                                style: const TextStyle(fontSize: 12, color: GoNordicTheme.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => setState(() => _currentIndex = 2),
                                  icon: const Icon(Icons.search),
                                  label: Text(tr('home.noPass.findBooking')),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => setState(() => _currentIndex = 1),
                                  icon: const Icon(Icons.sailing),
                                  label: Text(tr('home.noPass.bookNew')),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          const ProfileScreen(),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: GoNordicTheme.pine,
            unselectedItemColor: GoNordicTheme.textMuted,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.explore),
                label: tr('home.nav.explore'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.sailing),
                label: tr('home.nav.book'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.confirmation_number),
                label: tr('home.nav.myBookings'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.qr_code_2),
                label: tr('home.nav.boardingPass'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person),
                label: tr('home.nav.profile'),
              ),
            ],
          ),
        );
      },
    );
  }
}

