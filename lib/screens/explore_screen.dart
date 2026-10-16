import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/booking_service.dart';
import '../services/texts_service.dart';
import '../models/user_model.dart';
import '../theme/gonordic_theme.dart';
import '../widgets/gonordic_banner.dart';
import 'booking_wizard_screen.dart';
import 'destination_guide_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import '../widgets/language_picker.dart';

class ExploreScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  const ExploreScreen({super.key, this.onNavigateToTab});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  /// Valgt rute – ruterne kommer fra Core (/api/routes)
  String? _routeId;
  String _tripType = 'CRUISE';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  int _adults = 2;
  int _children = 0;
  bool _hasVehicle = true;

  /// Laveste pris pr. dag fra Core (/api/pricing/lowest, TideRMS-priser) for de næste 14 dage
  Map<String, double?>? _lowestPrices;
  bool _pricesLoading = false;
  bool _pricesFailed = false;
  String? _pricesRouteId;

  @override
  void initState() {
    super.initState();
    BookingService().addListener(_onRoutesChanged);
    _onRoutesChanged();
  }

  @override
  void dispose() {
    BookingService().removeListener(_onRoutesChanged);
    super.dispose();
  }

  void _onRoutesChanged() {
    if (!mounted) return;
    final routes = BookingService().routes;
    if (routes.isEmpty) {
      setState(() {});
      return;
    }
    if (_routeId == null || !routes.any((r) => r.id == _routeId)) {
      _routeId = routes.first.id;
    }
    if (_pricesRouteId != _routeId) _loadPrices();
    setState(() {});
  }

  /// Skifter til næste rute fra Core
  void _nextRoute() {
    final routes = BookingService().routes;
    if (routes.length < 2) return;
    final i = routes.indexWhere((r) => r.id == _routeId);
    setState(() => _routeId = routes[(i + 1) % routes.length].id);
    _loadPrices();
  }

  static String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadPrices() async {
    final routeId = _routeId;
    if (routeId == null) return;
    _pricesRouteId = routeId;
    setState(() {
      _pricesLoading = true;
      _pricesFailed = false;
      _lowestPrices = null;
    });
    final now = DateTime.now();
    final prices = await ApiService().fetchLowestPrices(
      routeId: routeId,
      from: _iso(now.add(const Duration(days: 1))),
      to: _iso(now.add(const Duration(days: 14))),
    );
    if (!mounted || routeId != _routeId) return;
    setState(() {
      _pricesLoading = false;
      _pricesFailed = prices == null;
      _lowestPrices = prices;
    });
  }

  void _showPassengerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('explore.passengerModal.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('explore.passengerModal.adults'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _adults > 1 ? () {
                              setModalState(() => _adults--);
                              setState(() {});
                            } : null,
                          ),
                          Text('$_adults', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: _adults < 9 ? () {
                              setModalState(() => _adults++);
                              setState(() {});
                            } : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('explore.passengerModal.children'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _children > 0 ? () {
                              setModalState(() => _children--);
                              setState(() {});
                            } : null,
                          ),
                          Text('$_children', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: _children < 9 ? () {
                              setModalState(() => _children++);
                              setState(() {});
                            } : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('explore.passengerModal.bringVehicle'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: Text(tr('explore.passengerModal.bringVehicleSub'), style: const TextStyle(fontSize: 12)),
                    value: _hasVehicle,
                    activeThumbColor: GoNordicTheme.pine,
                    onChanged: (val) {
                      setModalState(() => _hasVehicle = val);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(tr('explore.passengerModal.confirm')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: GoNordicTheme.sand,
      appBar: AppBar(
        title: Image.asset(
          'assets/gonordic/logo_white.png',
          height: 24,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) => const Text('Go Nordic Cruiseline'),
        ),
        actions: [
          const LanguagePicker(),
          IconButton(
            icon: Icon(user != null ? Icons.account_circle : Icons.person_outline),
            tooltip: tr('explore.profileTooltip'),
            onPressed: () {
              if (user != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => setState(() {}));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())).then((_) => setState(() {}));
              }
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DestinationGuideScreen())),
            child: GoNordicBanner(
              badgeText: tr('explore.bannerBadge'),
              text: tr('explore.bannerText'),
            ),
          ),
          _buildHero(),
          _buildProfileBar(user),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSearchCard(),
          ),
          _buildPriceStrip(),
          _buildHighlights(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Stack(
      children: [
        SizedBox(
          height: 200,
          width: double.infinity,
          child: Image.asset(
            'assets/gonordic/images/hero-people.jpg',
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => Container(color: GoNordicTheme.pineDark),
          ),
        ),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [GoNordicTheme.pineDark.withValues(alpha: 0.9), Colors.transparent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: GoNordicTheme.lime, borderRadius: BorderRadius.circular(12)),
                child: Text(tr('explore.hero.badge'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: GoNordicTheme.pineDark)),
              ),
              const SizedBox(height: 6),
              Text(tr('explore.hero.title'), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              Text(tr('explore.hero.subtitle'), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileBar(UserModel? user) {
    if (user != null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F4EA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF34A853).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const CircleAvatar(radius: 16, backgroundColor: GoNordicTheme.pine, child: Icon(Icons.check, size: 16, color: GoNordicTheme.lime)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.clubTier.isNotEmpty
                        ? tr('explore.profileBar.greeting', {'name': user.fullName, 'tier': user.clubTier})
                        : tr('explore.profileBar.greetingNoTier', {'name': user.fullName}),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: GoNordicTheme.pine),
                  ),
                  if (user.savedVehiclePlate.isNotEmpty)
                    Text(tr('explore.profileBar.ready', {'plate': user.savedVehiclePlate}), style: const TextStyle(fontSize: 11, color: Color(0xFF1E6460))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GoNordicTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())).then((_) => setState(() {})),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.account_circle, color: GoNordicTheme.teal, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('explore.profileBar.loginTitle'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      Text(tr('explore.profileBar.loginSub'), style: const TextStyle(fontSize: 10, color: GoNordicTheme.textSecondary)),
                    ],
                  ),
                ),
                Text(tr('explore.profileBar.loginLink'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: GoNordicTheme.teal)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _tab('MiniCruise', 'CRUISE'),
                const SizedBox(width: 8),
                _tab(tr('explore.search.ferryTab'), 'ONEWAY'),
              ],
            ),
            const Divider(height: 20),
            _buildRouteSelector(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: GoNordicTheme.sandLight, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, size: 16, color: GoNordicTheme.pine),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_date.day}/${_date.month}-${_date.year}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _showPassengerModal,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: GoNordicTheme.sandLight, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.people_outline, size: 16, color: GoNordicTheme.pine),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              [
                                tr('explore.search.adults', {'count': _adults}),
                                if (_children > 0) tr('explore.search.children', {'count': _children}),
                                if (_hasVehicle) tr('explore.search.vehicle'),
                              ].join(' • '),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (wizardContext) => BookingWizardScreen(
                        initialRouteId: _routeId,
                        initialTripType: _tripType,
                        initialDate: _date,
                        initialAdults: _adults,
                        initialChildren: _children,
                        hasVehicle: _hasVehicle,
                        // Efter bookingen: tilbage til fanerne og videre til "Bookinger"
                        onFinished: () {
                          Navigator.pop(wizardContext);
                          widget.onNavigateToTab?.call(1);
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.search, size: 18),
                label: Text(tr('explore.search.findDepartures')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Rutevælger med Core's ruter; har Core flere, skiftes der med et tryk.
  Widget _buildRouteSelector() {
    final service = BookingService();
    final routes = service.routes;
    final route = routes.where((r) => r.id == _routeId).firstOrNull;
    if (route == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: GoNordicTheme.sandLight, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Icons.directions_boat, color: GoNordicTheme.pine, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                service.routesLoading ? tr('explore.routesLoading') : tr('explore.routesUnavailable'),
                style: TextStyle(fontSize: 12, color: service.routesLoading ? GoNordicTheme.textSecondary : GoNordicTheme.error, fontWeight: FontWeight.bold),
              ),
            ),
            if (!service.routesLoading)
              TextButton(onPressed: () => service.syncBackend(), child: Text(tr('explore.retry'))),
          ],
        ),
      );
    }
    return InkWell(
      onTap: routes.length > 1 ? _nextRoute : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: GoNordicTheme.sandLight, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Icons.directions_boat, color: GoNordicTheme.pine, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(route.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            if (routes.length > 1) const Icon(Icons.swap_horiz, color: GoNordicTheme.teal),
          ],
        ),
      ),
    );
  }

  Widget _tab(String title, String type) {
    final active = _tripType == type;
    return InkWell(
      onTap: () => setState(() => _tripType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? GoNordicTheme.pine : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: active ? Colors.white : GoNordicTheme.textPrimary)),
      ),
    );
  }

  /// Dagens laveste pris fra Core; uden pris (udsolgt, ingen afgang eller fejl) vises en streg
  String _priceFor(DateTime d) {
    final price = _lowestPrices?[_iso(d)];
    return price == null ? tr('explore.noPrice') : tr('explore.price', {'amount': price.round()});
  }

  Widget _buildPriceStrip() {
    if (_routeId == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(tr('explore.priceCalendar'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: GoNordicTheme.textSecondary)),
        ),
        if (_pricesFailed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(child: Text(tr('explore.priceUnavailable'), style: const TextStyle(fontSize: 11, color: GoNordicTheme.error, fontWeight: FontWeight.bold))),
                TextButton(onPressed: _loadPrices, child: Text(tr('explore.retry'))),
              ],
            ),
          ),
        const SizedBox(height: 6),
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: 14,
            itemBuilder: (ctx, i) {
              final d = DateTime.now().add(Duration(days: i + 1));
              final isSelected = _date.year == d.year && _date.month == d.month && _date.day == d.day;
              return Container(
                width: 68,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isSelected ? GoNordicTheme.pine : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? GoNordicTheme.pineDark : GoNordicTheme.border, width: isSelected ? 1.5 : 1),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _date = d),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${d.day}/${d.month}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : GoNordicTheme.textPrimary)),
                          _pricesLoading
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
                              : Text(_priceFor(d), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isSelected ? GoNordicTheme.lime : GoNordicTheme.pine)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHighlights() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('explore.highlights.title'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: GoNordicTheme.textSecondary)),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DestinationGuideScreen())),
                child: Text(tr('explore.highlights.seeAll'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _item(tr('explore.highlights.foodTitle'), tr('explore.highlights.foodSub'), 'assets/gonordic/images/chef-kitchen.jpg'),
          _item(tr('explore.highlights.deckTitle'), tr('explore.highlights.deckSub'), 'assets/gonordic/images/family-window.jpg'),
          _item(tr('explore.highlights.shopTitle'), tr('explore.highlights.shopSub'), 'assets/gonordic/images/taxfree-shop.jpg'),
        ],
      ),
    );
  }

  Widget _item(String title, String sub, String img) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DestinationGuideScreen())),
        child: Row(
          children: [
            Image.asset(img, width: 85, height: 65, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 85, height: 65, color: GoNordicTheme.pineDark)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(sub, style: const TextStyle(fontSize: 10, color: GoNordicTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right, color: GoNordicTheme.teal, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
