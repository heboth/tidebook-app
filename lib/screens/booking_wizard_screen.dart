import 'package:flutter/material.dart';
import 'nets_payment_screen.dart';
import '../models/cabin_model.dart';
import '../models/addon_model.dart';
import '../models/booking_model.dart';
import '../services/auth_service.dart';
import '../models/departure_model.dart';
import '../services/api_service.dart';

import '../services/booking_service.dart';
import '../services/texts_service.dart';
import '../theme/gonordic_theme.dart';
import '../widgets/cabin_card.dart';
import 'boarding_pass_screen.dart';
import 'login_screen.dart';

class BookingWizardScreen extends StatefulWidget {
  final String? initialRouteId;
  final String? initialTripType;
  final DateTime? initialDate;
  final int? initialAdults;
  final bool? hasVehicle;
  final VoidCallback? onFinished;

  const BookingWizardScreen({
    super.key,
    this.initialRouteId,
    this.initialTripType,
    this.initialDate,
    this.initialAdults,
    this.hasVehicle,
    this.onFinished,
  });

  @override
  State<BookingWizardScreen> createState() => _BookingWizardScreenState();
}

class _BookingWizardScreenState extends State<BookingWizardScreen> {
  int _step = 1;
  late String _routeId;
  CabinModel? _cabin;
  final Map<String, int> _addons = {};
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  BookingModel? _booked;

  @override
  void initState() {
    super.initState();
    _routeId = widget.initialRouteId ?? 'ROUTE-CPH-OSL';
    if (CabinModel.defaultCabins.isNotEmpty) {
      _cabin = CabinModel.defaultCabins.first;
    }
    final u = AuthService().currentUser;
    _nameCtrl = TextEditingController(text: u?.fullName ?? 'Mads Jensen');
    _emailCtrl = TextEditingController(text: u?.email ?? 'mads.jensen@example.dk');
    _phoneCtrl = TextEditingController(text: u?.phone ?? '+45 20 30 40 50');
  }

  void _useProfileData() {
    final u = AuthService().currentUser;
    if (u != null) {
      setState(() {
        _nameCtrl.text = u.fullName;
        _emailCtrl.text = u.email;
        _phoneCtrl.text = u.phone;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: GoNordicTheme.success, content: Text(tr('bookingWizard.profileFilled', {'name': u.fullName}))),
      );
    }
  }

  double get _total {
    double s = 890 + (_cabin?.priceDkk ?? 0);
    _addons.forEach((k, v) {
      final a = AddOnModel.defaultAddOns.firstWhere((x) => x.id == k);
      s += a.priceDkk * v;
    });
    return s;
  }

  bool _isProcessingPayment = false;

  /// Prisen fra Core for det valgte (vises på trin 4, så den svarer til beløbet hos Nets)
  double? _serverTotal;

  Future<void> _refreshQuote() async {
    final dep = _nextDeparture();
    if (dep == null) return;
    setState(() => _serverTotal = null);
    final draft = await _buildDraft(dep, firstName: 'Pris', lastName: 'Beregning', name: _nameCtrl.text, email: _emailCtrl.text, phone: _phoneCtrl.text);
    final total = await ApiService().quoteTotal(draft);
    if (mounted) setState(() => _serverTotal = total);
  }

  // Appens kahytskategorier ⇒ Core's BookIT-koder (første ledige kahyt i kategorien bookes)
  static const Map<String, List<String>> _cabinCodes = {
    'OWNERS_SUITE': ['O2', 'O3', 'J3'],
    'COMMODORE_BALCONY': ['X2', 'X1'],
    'COMMODORE_DELUXE': ['X2', 'X1'],
    'COMMODORE_SEAVIEW': ['C2'],
    'STANDARD_SEAVIEW': ['A4', 'A4LV'],
    'STANDARD_INSIDE': ['B4', 'B2', 'B3', 'BD', 'BC'],
    'ECONOMY_INSIDE': ['E4', 'WL'],
    'FAMILY': ['B5', 'F4', 'F4LV'],
  };

  /// En ledig kahyt i Core i den valgte kategori (eller null uden kahyt).
  Future<String?> _resolveCabinId(DepartureModel dep) async {
    if (_cabin == null) return null;
    final cabins = await ApiService().fetchDepartureCabins(dep.id);
    final free = cabins.where((c) => c['isBookedOnDeparture'] != true && c['isBooked'] != true).toList();
    final codes = _cabinCodes[_cabin!.category] ?? const <String>[];
    for (final code in codes) {
      final hit = free.where((c) => c['category'] == code).toList();
      if (hit.isNotEmpty) return hit.first['id'] as String?;
    }
    return free.isNotEmpty ? free.first['id'] as String? : null;
  }

  Future<Map<String, dynamic>> _buildDraft(DepartureModel dep, {required String firstName, required String lastName, required String name, required String email, required String phone}) async {
    final user = AuthService().currentUser;
    final cabinId = await _resolveCabinId(dep);
    return {
      'termsAccepted': true,
      'routeId': _routeId,
      'departureId': dep.id,
      'outboundDate': dep.scheduledDepartureTime.toIso8601String().split('T')[0],
      'ticketClass': 'PREMIUM',
      'passengers': [
        {
          'id': 'P1',
          'firstName': firstName,
          'lastName': lastName,
          'type': 'ADULT',
          'nationality': user?.nationality ?? 'DK',
          'dateOfBirth': user?.birthDate ?? '1988-01-01',
        }
      ],
      'leadContact': {
        'fullName': name,
        'email': email,
        'phone': phone,
      },
      'selectedCabinIds': [?cabinId],
      'cabinIds': [?cabinId], // prisberegningen (/pricing/calculate) bruger cabinIds
      'addOns': _addons.entries.map((e) => {'id': e.key, 'quantity': e.value}).toList(),
    };

  }

  Future<void> _startPaymentFlow() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('bookingWizard.missingContact'))),
      );
      return;
    }

    setState(() => _isProcessingPayment = true);

    final nameParts = name.split(' ');
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Jensen';

    final departures = BookingService().departures;
    final dep = _nextDeparture() ?? departures.firstWhere(
      (d) => d.routeId == _routeId,
      orElse: () => departures.isNotEmpty
          ? departures.first
          : DepartureModel(
              id: 'DEP-CPH-OSL-TOMORROW',
              routeId: _routeId,
              vesselId: 'VESSEL-CROWN',
              vesselName: 'Crown Seaways',
              scheduledDepartureTime: DateTime.now().add(const Duration(days: 1)),
              scheduledArrivalTime: DateTime.now().add(const Duration(days: 1, hours: 17, minutes: 30)),
              gateNumber: 'Gate 1 (Terminal Dampfærgevej)',
              checkInOpen: true,
              basePriceDkk: 890,
            ),
    );

    final draft = await _buildDraft(dep, firstName: firstName, lastName: lastName, name: name, email: email, phone: phone);

    final session = await ApiService().startCheckout(draft);
    setState(() => _isProcessingPayment = false);

    if (!mounted) return;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GoNordicTheme.error,
          content: Text(tr('bookingWizard.paymentServerUnreachable')),
        ),
      );
      return;
    }

    _showNetsPaymentModal(session);
  }

  void _showNetsPaymentModal(CheckoutSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NetsPaymentSheet(
        session: session,
        onPaymentCompleted: (result) {
          Navigator.pop(ctx);
          BookingService().rememberBooking(result.booking!, result.bookingToken ?? session.bookingToken);
          setState(() {
            _booked = result.booking;
            _step = 5;
          });
        },
        onCancel: () {
          Navigator.pop(ctx);
          ApiService().abandonPayment(session.paymentId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('bookingWizard.paymentCancelled'))),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoNordicTheme.sand,
      appBar: AppBar(
        title: Text(tr('bookingWizard.title', {'step': _step})),
        leading: _step > 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: tr('bookingWizard.previousStep'),
                onPressed: () => setState(() => _step--),
              )
            : null,
      ),
      body: _buildStep(),
    );
  }

  Widget _buildStep() {
    if (_step == 1) return _step1();
    if (_step == 2) return _step2();
    if (_step == 3) return _step3();
    if (_step == 4) return _step4();
    return _step5();
  }

  /// Næste afgang på den valgte rute, der ikke er sejlet (mindst 30 min. til afgang).
  DepartureModel? _nextDeparture() {
    final cutoff = DateTime.now().add(const Duration(minutes: 30));
    final upcoming = BookingService().departures
        .where((d) => d.routeId == _routeId && d.scheduledDepartureTime.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.scheduledDepartureTime.compareTo(b.scheduledDepartureTime));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  Widget _step1() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(tr('bookingWizard.step1.title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      Card(
        child: Column(
          children: BookingService().routes.map((r) => ListTile(
            title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            leading: Icon(
              _routeId == r.id ? Icons.radio_button_checked : Icons.radio_button_off,
              color: GoNordicTheme.pine,
            ),
            onTap: () => setState(() => _routeId = r.id),
          )).toList(),
        ),
      ),
      const SizedBox(height: 12),
      Builder(builder: (context) {
        final dep = _nextDeparture();
        if (dep == null) return const SizedBox.shrink();
        final t = dep.scheduledDepartureTime.toLocal();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            tr('bookingWizard.step1.departure', {'date': '${t.day}/${t.month}-${t.year}', 'time': '${_two(t.hour)}:${_two(t.minute)}'}),
            style: const TextStyle(fontWeight: FontWeight.w600, color: GoNordicTheme.pine),
          ),
        );
      }),
      ElevatedButton(onPressed: () => setState(() => _step = 2), child: Text(tr('bookingWizard.step1.next'))),
    ],
  );

  Widget _step2() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(tr('bookingWizard.step2.title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...CabinModel.defaultCabins.map((c) => CabinCard(
        cabin: c, isSelected: _cabin?.id == c.id,
        onSelect: () => setState(() => _cabin = c),
      )),
      const SizedBox(height: 12),
      ElevatedButton(
        onPressed: () {
          if (_cabin == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('bookingWizard.step2.selectCabin'))),
            );
            return;
          }
          setState(() => _step = 3);
        },
        child: Text(tr('bookingWizard.step2.next')),
      ),
    ],
  );

  Widget _step3() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(tr('bookingWizard.step3.title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ...AddOnModel.defaultAddOns.map((a) => Card(
        child: CheckboxListTile(
          title: Text(a.name), subtitle: Text('${a.priceDkk.toInt()} DKK'),
          value: _addons.containsKey(a.id), activeColor: GoNordicTheme.pine,
          onChanged: (v) => setState(() {
            if (v == true) {
              _addons[a.id] = 1;
            } else {
              _addons.remove(a.id);
            }
          }),
        ),
      )),
      ElevatedButton(onPressed: () { setState(() => _step = 4); _refreshQuote(); }, child: Text(tr('bookingWizard.step3.next'))),
    ],
  );

  Widget _step4() {
    final user = AuthService().currentUser;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(tr('bookingWizard.step4.title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (user != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4EA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF34A853).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF34A853), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(tr('bookingWizard.step4.loggedInAs', {'name': user.fullName, 'tier': user.clubTier}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                TextButton(
                  onPressed: _useProfileData,
                  child: Text(tr('bookingWizard.step4.useProfile'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GoNordicTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 20, color: GoNordicTheme.teal),
                const SizedBox(width: 8),
                Expanded(child: Text(tr('bookingWizard.step4.loginForQuickFill'), style: const TextStyle(fontSize: 11))),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())).then((_) {
                      setState(() {
                        final u = AuthService().currentUser;
                        if (u != null) {
                          _nameCtrl.text = u.fullName;
                          _emailCtrl.text = u.email;
                          _phoneCtrl.text = u.phone;
                        }
                      });
                    });
                  },
                  child: Text(tr('bookingWizard.step4.login'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: tr('bookingWizard.step4.fullName'))),
                const SizedBox(height: 8),
                TextField(controller: _emailCtrl, decoration: InputDecoration(labelText: tr('bookingWizard.step4.email'))),
                const SizedBox(height: 8),
                TextField(controller: _phoneCtrl, decoration: InputDecoration(labelText: tr('bookingWizard.step4.mobile'))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(tr('bookingWizard.step4.total', {'amount': (_serverTotal ?? _total).toInt()}), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GoNordicTheme.pine)),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _isProcessingPayment ? null : _startPaymentFlow,
          child: _isProcessingPayment
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(tr('bookingWizard.step4.continueToPayment')),
        ),
      ],
    );
  }

  Widget _step5() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset('assets/gonordic/app_icon.png', width: 64, height: 64, fit: BoxFit.cover),
          ),
          const SizedBox(height: 10),
          const Icon(Icons.check_circle, color: GoNordicTheme.success, size: 48),
          const SizedBox(height: 8),
          Text(tr('bookingWizard.step5.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('${_booked?.pnr}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: GoNordicTheme.pine)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BoardingPassScreen(booking: _booked!))),
              icon: const Icon(Icons.qr_code_2),
              label: Text(tr('bookingWizard.step5.showBoardingPass')),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                if (widget.onFinished != null) {
                  widget.onFinished!();
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    _step = 1;
                    _booked = null;
                  });
                }
              },
              child: Text(tr('bookingWizard.step5.backToHome')),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NetsPaymentSheet extends StatefulWidget {
  final CheckoutSession session;
  final ValueChanged<CompletedPaymentResult> onPaymentCompleted;
  final VoidCallback onCancel;

  const _NetsPaymentSheet({
    required this.session,
    required this.onPaymentCompleted,
    required this.onCancel,
  });

  @override
  State<_NetsPaymentSheet> createState() => _NetsPaymentSheetState();
}

class _NetsPaymentSheetState extends State<_NetsPaymentSheet> {
  bool _isCompleting = false;
  String? _errorMessage;

  /// Åbner Nets' betalingsside; når kunden er sendt tilbage, bekræfter Core betalingen (/complete).
  Future<void> _payAndComplete() async {
    final page = widget.session.paymentPageUrl;
    final returnUrl = widget.session.returnUrl;
    final cancelUrl = widget.session.cancelUrl;
    if (page == null || returnUrl == null || cancelUrl == null) {
      setState(() => _errorMessage = tr('bookingWizard.payment.pageUnavailable'));
      return;
    }
    setState(() => _errorMessage = null);
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => NetsPaymentScreen(paymentPageUrl: page, returnUrl: returnUrl, cancelUrl: cancelUrl, pnr: widget.session.pnr),
      ),
    );
    if (!mounted) return;
    if (paid != true) {
      setState(() => _errorMessage = tr('bookingWizard.payment.notCompleted'));
      return;
    }

    setState(() => _isCompleting = true);
    try {
      final res = await ApiService().completePayment(widget.session.paymentId);
      if (!mounted) return;
      if (res.success && res.booking != null) {
        widget.onPaymentCompleted(res);
      } else {
        setState(() {
          _isCompleting = false;
          _errorMessage = res.errorMessage ?? tr('bookingWizard.payment.notConfirmed', {'pnr': widget.session.pnr});
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCompleting = false;
        _errorMessage = tr('bookingWizard.payment.networkError', {'pnr': widget.session.pnr});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock, color: Colors.blue, size: 22),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('bookingWizard.payment.title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(tr('bookingWizard.payment.reserved', {'pnr': widget.session.pnr}), style: const TextStyle(fontSize: 11, color: GoNordicTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _isCompleting ? null : widget.onCancel,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: GoNordicTheme.sand,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GoNordicTheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tr('bookingWizard.payment.amountDue'), style: const TextStyle(fontSize: 13, color: GoNordicTheme.textSecondary, fontWeight: FontWeight.bold)),
                Text(
                  '${widget.session.amountDkk.toInt()} DKK',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: GoNordicTheme.pineDark, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF92400E), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.session.provider == 'simulator'
                        ? tr('bookingWizard.payment.simulatorNotice')
                        : tr('bookingWizard.payment.secureNotice'),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: const TextStyle(color: GoNordicTheme.error, fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isCompleting ? null : _payAndComplete,
            child: _isCompleting
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      const SizedBox(width: 10),
                      Text(tr('bookingWizard.payment.verifying')),
                    ],
                  )
                : Text(tr('bookingWizard.payment.pay')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _isCompleting ? null : widget.onCancel,
            child: Text(tr('bookingWizard.payment.cancel')),
          ),
        ],
      ),
    );
  }
}

