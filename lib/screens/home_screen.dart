import 'package:flutter/material.dart';
import '../services/booking_service.dart';
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
                  appBar: AppBar(title: const Text('Boardingkort')),
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
                              const Text(
                                'Intet aktivt boardingkort fundet',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Søg din eksisterende reservation frem under Mine Bookinger, eller gennemfør en ny booking for at se dit QR boardingkort.',
                                style: TextStyle(fontSize: 12, color: GoNordicTheme.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => setState(() => _currentIndex = 2),
                                  icon: const Icon(Icons.search),
                                  label: const Text('Find Eksisterende Booking'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => setState(() => _currentIndex = 1),
                                  icon: const Icon(Icons.sailing),
                                  label: const Text('Book Ny Rejse'),
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
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.explore),
                label: 'Udforsk',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.sailing),
                label: 'Book Rejse',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.confirmation_number),
                label: 'Mine Bookinger',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_2),
                label: 'Boardingkort',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Min Profil',
              ),
            ],
          ),
        );
      },
    );
  }
}

