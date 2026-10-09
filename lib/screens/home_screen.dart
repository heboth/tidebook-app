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
    final activeBooking = BookingService().activeBooking;

    final List<Widget> screens = [
      const ExploreScreen(),
      const BookingWizardScreen(),
      const MyBookingsScreen(),
      activeBooking != null
          ? BoardingPassScreen(booking: activeBooking)
          : const Scaffold(body: Center(child: Text('Ingen aktiv reservation fundet.'))),
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
  }
}

