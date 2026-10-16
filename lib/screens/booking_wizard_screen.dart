import 'package:flutter/material.dart';
import 'nets_payment_screen.dart';
import '../models/cabin_model.dart';
import '../models/addon_model.dart';
import '../models/booking_model.dart';
import '../services/auth_service.dart';
import '../models/departure_model.dart';
import '../models/route_model.dart';
import '../services/api_service.dart';

import '../services/booking_service.dart';
import '../services/texts_service.dart';
import '../utils/port_time.dart';
import '../widgets/partner_ticket_sheet.dart';
import '../theme/gonordic_theme.dart';
import '../widgets/cabin_card.dart';
import 'boarding_pass_screen.dart';
import 'login_screen.dart';
import 'site_page_screen.dart';
import '../services/site_links.dart';

class BookingWizardScreen extends StatefulWidget {
  final String? initialRouteId;
  /// 'CRUISE' (MiniCruise: ud- og hjemrejse) eller 'ONEWAY' (færgeoverfart én vej)
  final String? initialTripType;
  final DateTime? initialDate;
  final int? initialAdults;
  final int? initialChildren;
  final bool? hasVehicle;
  final VoidCallback? onFinished;

  const BookingWizardScreen({
    super.key,
    this.initialRouteId,
    this.initialTripType,
    this.initialDate,
    this.initialAdults,
    this.initialChildren,
    this.hasVehicle,
    this.onFinished,
  });

  @override
  State<BookingWizardScreen> createState() => _BookingWizardScreenState();
}

class _BookingWizardScreenState extends State<BookingWizardScreen> {
  int _step = 1;
  String? _routeId;
  final Map<String, int> _addons = {};
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  BookingModel? _booked;

  // Søgningens valg – kan ændres i trin 1
  late String _tripType;
  late int _adults;
  late int _children;
  late bool _hasVehicle;
  String _vehicleCategory = 'CAR_STANDARD';
  late final TextEditingController _plateCtrl;
  static const _vehicleCategories = ['CAR_STANDARD', 'CAR_LARGE', 'VAN_CAMPER', 'MOTORCYCLE'];

  // Medrejsende (passager 2 og frem); passager 1 er kontaktpersonen nedenfor
  final List<_FellowTraveller> _fellows = [];

  // Afgang – hentes fra Core for den valgte rute (og evt. dato fra søgningen)
  DepartureModel? _departure;

  // MiniCruise: hjemrejsen er ruten den modsatte vej dagen efter (fra Core)
  DepartureModel? _returnDeparture;
  bool _returnLoading = false;
  bool _returnFailed = false;
  bool _departuresLoading = false;
  bool _departuresFailed = false;
  bool _departuresTried = false;

  // Kahytskategorier på afgangen – fra Core (/api/departures/:id/cabins)
  List<CabinModel>? _cabins;
  CabinModel? _cabin;
  bool _cabinsLoading = false;
  bool _cabinsFailed = false;

  // Tilvalg – fra Core (/api/addons)
  List<AddOnModel>? _addOnCatalog;
  bool _addOnsLoading = false;
  bool _addOnsFailed = false;

  // Passagerlisten (EU-direktiv 98/41/EF): køn, nationalitet og fødselsdato indberettes for rejser over 20 sømil
  String? _gender;
  String? _nationality;
  String? _birthDate;
  static const _countries = ['DK', 'NO', 'SE', 'DE', 'FI', 'NL', 'PL', 'GB', 'US', 'FR', 'ES', 'IT'];

  @override
  void initState() {
    super.initState();
    _routeId = widget.initialRouteId;
    _tripType = widget.initialTripType == 'CRUISE' ? 'CRUISE' : 'ONEWAY';
    _adults = (widget.initialAdults ?? 1).clamp(1, 9);
    _children = (widget.initialChildren ?? 0).clamp(0, 9);
    _hasVehicle = widget.hasVehicle ?? false;
    _plateCtrl = TextEditingController();
    _syncFellows();
    final u = AuthService().currentUser;
    // Kun kundens egne data – ingen eksempelnavne i felterne
    _nameCtrl = TextEditingController(text: u?.fullName ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _phoneCtrl = TextEditingController(text: u?.phone ?? '');
    _nationality = (u?.nationality.isNotEmpty ?? false) ? u!.nationality : null;
    _birthDate = (u?.birthDate.isNotEmpty ?? false) ? u!.birthDate : null;
    BookingService().addListener(_onRoutesChanged);
    _onRoutesChanged();
  }

  @override
  void dispose() {
    BookingService().removeListener(_onRoutesChanged);
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _plateCtrl.dispose();
    for (final f in _fellows) {
      f.dispose();
    }
    super.dispose();
  }

  bool get _isCruise => _tripType == 'CRUISE';
  int get _paxCount => _adults + _children;

  /// Medrejsende svarer til antal voksne (minus kontaktpersonen) og børn – udfyldte felter bevares.
  void _syncFellows() {
    final types = [...List.filled(_adults - 1, 'ADULT'), ...List.filled(_children, 'CHILD')];
    for (var i = 0; i < types.length; i++) {
      if (i < _fellows.length && _fellows[i].type == types[i]) continue;
      if (i < _fellows.length) {
        _fellows[i].dispose();
        _fellows[i] = _FellowTraveller(types[i]);
      } else {
        _fellows.add(_FellowTraveller(types[i]));
      }
    }
    while (_fellows.length > types.length) {
      _fellows.removeLast().dispose();
    }
  }

  /// Rejsetype, antal rejsende eller bil er ændret: kahyt, tilvalg og pris beregnes igen.
  void _onPartyChanged() {
    setState(() {
      _syncFellows();
      if (_cabin != null && _cabin!.berths < _paxCount) _cabin = null;
      _addOnCatalog = null;
      _serverTotal = null;
      _quoteFailed = false;
    });
  }

  void _setTripType(String type) {
    if (type == _tripType) return;
    setState(() {
      _tripType = type;
      _cabins = null;
      _cabin = null;
      _serverTotal = null;
    });
    _loadReturnDeparture();
  }

  /// Ruten den modsatte vej (havnene byttet om) blandt Core's ruter.
  RouteModel? _returnRouteFor(String routeId) {
    final routes = BookingService().routes;
    final out = routes.where((r) => r.id == routeId).firstOrNull;
    if (out == null || out.originPortCode.isEmpty) return null;
    return routes
        .where((r) => r.id != out.id && r.originPortCode == out.destinationPortCode && r.destinationPortCode == out.originPortCode)
        .firstOrNull;
  }

  /// MiniCruise: første afgang hjem dagen efter udrejsen (efter ankomst). Findes ingen, kan der ikke bookes MiniCruise.
  Future<void> _loadReturnDeparture() async {
    final dep = _departure;
    final back = dep == null ? null : _returnRouteFor(dep.routeId);
    if (!_isCruise || dep == null || back == null) {
      setState(() {
        _returnDeparture = null;
        _returnLoading = false;
        _returnFailed = false;
      });
      return;
    }
    setState(() {
      _returnDeparture = null;
      _returnLoading = true;
      _returnFailed = false;
    });
    final out = DateTime.parse(dep.portDate);
    final nextDay = _isoDate(DateTime.utc(out.year, out.month, out.day + 1));
    final list = await ApiService().fetchDepartures(routeId: back.id, date: nextDay);
    if (!mounted || dep.id != _departure?.id || !_isCruise) return;
    final candidates = (list ?? const <DepartureModel>[])
        .where((d) => d.routeId == back.id && d.portDate == nextDay && d.scheduledDepartureTime.isAfter(dep.scheduledArrivalTime))
        .toList()
      ..sort((a, b) => a.scheduledDepartureTime.compareTo(b.scheduledDepartureTime));
    setState(() {
      _returnLoading = false;
      _returnFailed = list == null;
      _returnDeparture = candidates.firstOrNull;
    });
  }

  /// Ruterne kommer fra Core (evt. efter appen er startet): vælg den første, hvis ingen er valgt.
  void _onRoutesChanged() {
    if (!mounted) return;
    final routes = BookingService().routes;
    if (_routeId == null && routes.isNotEmpty) {
      _selectRoute(routes.first.id);
    } else if (_routeId != null && !_departuresTried && !_departuresLoading) {
      _loadDepartures();
    } else {
      setState(() {});
    }
  }

  void _selectRoute(String routeId) {
    setState(() {
      _routeId = routeId;
      _departure = null;
      _returnDeparture = null;
      _departuresTried = false;
      _cabins = null;
      _cabin = null;
      _serverTotal = null;
      _quoteFailed = false;
    });
    _loadDepartures();
  }

  String _isoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  /// Næste afgang på ruten fra Core, der ikke er sejlet (mindst 30 min. til afgang).
  /// Findes ingen, vises en tom tilstand – der opfindes ingen afgang.
  Future<void> _loadDepartures() async {
    final routeId = _routeId;
    if (routeId == null) return;
    setState(() {
      _departuresLoading = true;
      _departuresFailed = false;
      _departuresTried = true;
    });
    final cutoff = DateTime.now().add(const Duration(minutes: 30));
    final now = DateTime.now();
    // Med en dato fra søgningen bruges den; ellers kendte afgange, så i dag og i morgen (Core opretter dagens afgange ved forespørgsel)
    final attempts = widget.initialDate != null
        ? <String?>[_isoDate(widget.initialDate!)]
        : <String?>[null, _isoDate(now), _isoDate(now.add(const Duration(days: 1)))];
    DepartureModel? next;
    var failed = false;
    for (final date in attempts) {
      final list = await ApiService().fetchDepartures(routeId: routeId, date: date);
      if (list == null) {
        failed = true;
        break;
      }
      final upcoming = list.where((d) => d.routeId == routeId && d.scheduledDepartureTime.isAfter(cutoff)).toList()
        ..sort((a, b) => a.scheduledDepartureTime.compareTo(b.scheduledDepartureTime));
      if (upcoming.isNotEmpty) {
        next = upcoming.first;
        break;
      }
    }
    if (!mounted || routeId != _routeId) return;
    setState(() {
      _departuresLoading = false;
      _departuresFailed = failed && next == null;
      _departure = next;
    });
    _loadReturnDeparture();
  }

  /// Ledige kahytter på afgangen, samlet pr. kategori.
  Future<void> _loadCabins() async {
    final dep = _departure;
    if (dep == null) return;
    setState(() {
      _cabinsLoading = true;
      _cabinsFailed = false;
    });
    final ret = _isCruise ? _returnDeparture : null;
    final results = await Future.wait([
      ApiService().fetchDepartureCabins(dep.id),
      if (ret != null) ApiService().fetchDepartureCabins(ret.id),
    ]);
    if (!mounted || dep.id != _departure?.id || ret?.id != (_isCruise ? _returnDeparture?.id : null)) return;
    var raw = results.first;
    if (ret != null) {
      // MiniCruise: samme kahyt ud og hjem – kun kahytter, der er ledige på begge afgange
      final back = results[1];
      final freeBack = back == null ? null : CabinModel.fromCoreCabins(back).expand((c) => c.freeCabinIds).toSet();
      raw = (raw == null || freeBack == null) ? null : raw.where((c) => freeBack.contains(c['id']?.toString())).toList();
    }
    setState(() {
      _cabinsLoading = false;
      _cabinsFailed = raw == null;
      _cabins = raw == null ? null : CabinModel.fromCoreCabins(raw);
      // Er den valgte kahyt ikke længere ledig, nulstilles valget
      if (_cabin != null && !(_cabins?.any((c) => c.freeCabinIds.contains(_cabin!.cabinId)) ?? false)) {
        _cabin = null;
      }
    });
  }

  /// Aktive tilvalg fra Core – filtreret efter antal rejsende og om der er bil med.
  Future<void> _loadAddOns() async {
    setState(() {
      _addOnsLoading = true;
      _addOnsFailed = false;
    });
    final list = await ApiService().fetchAddOns(
      travelDate: _departure?.scheduledDepartureTime,
      hasVehicle: _hasVehicle,
      passengerCount: _paxCount,
      departureId: _departure?.id,
    );
    if (!mounted) return;
    setState(() {
      _addOnsLoading = false;
      _addOnsFailed = list == null;
      _addOnCatalog = list;
      if (list != null) _addons.removeWhere((id, _) => !list.any((a) => a.id == id));
    });
  }

  void _useProfileData() {
    final u = AuthService().currentUser;
    if (u != null) {
      setState(() {
        _nameCtrl.text = u.fullName;
        _emailCtrl.text = u.email;
        _phoneCtrl.text = u.phone;
        if (u.nationality.isNotEmpty) _nationality = u.nationality;
        if (u.birthDate.isNotEmpty) _birthDate = u.birthDate;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: GoNordicTheme.success, content: Text(tr('bookingWizard.profileFilled', {'name': u.fullName}))),
      );
    }
  }

  bool _isProcessingPayment = false;
  // Rejsebetingelserne skal accepteres aktivt; samtykke til markedsføring er frivilligt – intet er forudvalgt
  bool _termsAccepted = false;
  bool _marketingConsent = false;

  /// Prisen fra Core for det valgte (samme beregning som beløbet hos Nets). Appen beregner ingen pris selv.
  double? _serverTotal;
  /// Partnerbilletter (Tivoli, LEGOLAND): dato, tidspunkt og Core's tilbud pr. produkt
  final Map<String, PartnerSelection> _partner = {};

  /// Afbestillingsforsikringen fra TideRMS (via Core) og kundens valg
  InsuranceOffer? _insuranceOffer;
  bool _withInsurance = false;
  bool _quoteLoading = false;
  bool _quoteFailed = false;
  int _quoteSeq = 0;

  Future<void> _refreshQuote() async {
    final dep = _departure;
    if (dep == null) return;
    final seq = ++_quoteSeq;
    setState(() {
      _serverTotal = null;
      _quoteLoading = true;
      _quoteFailed = false;
    });
    final draft = _buildDraft(dep, firstName: 'Pris', lastName: 'Beregning', name: _nameCtrl.text, email: _emailCtrl.text, phone: _phoneCtrl.text, forQuote: true);
    final quote = await ApiService().quote(draft);
    if (!mounted || seq != _quoteSeq) return; // et nyere valg er på vej
    setState(() {
      _quoteLoading = false;
      _serverTotal = quote?.total;
      _quoteFailed = quote == null;
      if (quote != null) {
        _insuranceOffer = quote.insuranceOffer;
        if (_insuranceOffer == null) _withInsurance = false;
      }
    });
  }

  /// Et ben af rejsen med rutens havne fra Core (MiniCruise har to: ud og hjem).
  Map<String, dynamic> _leg(int index, DepartureModel d, String? cabinId) {
    final route = BookingService().routes.where((r) => r.id == d.routeId).firstOrNull?.toJson();
    return {
      'legIndex': index,
      'routeId': d.routeId,
      'departureId': d.id,
      'departureTime': d.scheduledDepartureTime.toUtc().toIso8601String(),
      'arrivalTime': d.scheduledArrivalTime.toUtc().toIso8601String(),
      'vesselId': d.vesselId,
      'originPort': ?route?['originPort'],
      'destinationPort': ?route?['destinationPort'],
      'selectedCabinIds': [?cabinId],
    };
  }

  /// Køretøjet til vogndækket. Mål som på bookingsitet ud fra typen; nummerpladen skriver kunden selv.
  Map<String, dynamic>? _vehicle() {
    if (!_hasVehicle) return null;
    final c = _vehicleCategory;
    return {
      'category': c,
      'licensePlate': _plateCtrl.text.trim().toUpperCase(),
      'country': ?_nationality,
      'lengthMeters': c == 'CAR_LARGE' ? 5.2 : c == 'VAN_CAMPER' ? 6.8 : c == 'MOTORCYCLE' ? 2.2 : 4.8,
      'heightMeters': c == 'VAN_CAMPER' ? 2.8 : c == 'MOTORCYCLE' ? 1.3 : 1.6,
      'widthMeters': c == 'MOTORCYCLE' ? 0.9 : 1.9,
      'weightTonnes': c == 'VAN_CAMPER' ? 3.5 : c == 'MOTORCYCLE' ? 0.3 : 1.8,
      'hasRoofBox': false,
      'hasTrailer': false,
      'isElectric': false,
      'isHazardousCargo': false,
    };
  }

  Map<String, dynamic> _buildDraft(DepartureModel dep, {required String firstName, required String lastName, required String name, required String email, required String phone, bool forQuote = false}) {
    final cabinId = _cabin?.cabinId;
    final ret = _isCruise ? _returnDeparture : null;
    return {
      // Kun versionen og kundens egen afkrydsning – Core sætter tidspunktet for accepten
      'terms_version_id': SiteLinks.termsVersionId,
      'termsAccepted': _termsAccepted,
      // Frivilligt samtykke til tilbud og nyheder på e-mail – Core sætter tidspunkt og IP
      'marketingConsent': {'consented': _marketingConsent, 'consentVersion': SiteLinks.marketingConsentVersion},
      'routeId': dep.routeId,
      'departureId': dep.id,
      'outboundDate': dep.portDate,
      // MiniCruise: hjemrejsen på samme booking (Core kræver præcis to ben)
      'returnDepartureId': ?ret?.id,
      'returnDate': ?ret?.portDate,
      'legs': [_leg(1, dep, cabinId), if (ret != null) _leg(2, ret, cabinId)],
      'ticketClass': 'STANDARD', // samme standard som bookingsitet; PREMIUM har morgenmad inkluderet (0 kr.) i TideRMS
      'passengers': [
        {
          'id': 'P1',
          'firstName': firstName,
          'lastName': lastName,
          'type': 'ADULT',
          // Kun det, passageren selv har oplyst – ingen standardværdier på passagerlisten
          'nationality': ?_nationality,
          'dateOfBirth': ?_birthDate,
          'gender': ?_gender,
        },
        for (var i = 0; i < _fellows.length; i++)
          {
            'id': 'P${i + 2}',
            // Prisberegningen bruger kun passagertypen – navnene er kundens egne ved betalingen
            'firstName': forQuote ? 'Pris' : _fellows[i].firstCtrl.text.trim(),
            'lastName': forQuote ? 'Beregning' : _fellows[i].lastCtrl.text.trim(),
            'type': _fellows[i].type,
            'nationality': ?_fellows[i].nationality,
            'dateOfBirth': ?_fellows[i].birthDate,
            'gender': ?_fellows[i].gender,
          },
      ],
      'vehicle': ?_vehicle(),
      'leadContact': {
        'fullName': name,
        'email': email,
        'phone': phone,
      },
      'selectedCabinIds': [?cabinId],
      'cabinIds': [?cabinId], // prisberegningen (/pricing/calculate) bruger cabinIds
      'addOns': [
        ..._addons.entries.map((e) => {'id': e.key, 'quantity': e.value}),
        // Partnerbilletter: prisen er Core's tilbud (quoteId) – den lægges i prisen, og Core reserverer og udsteder billetterne
        ..._partner.values.map((p) => {'id': p.addOn.id, 'quantity': 1, 'quoteId': p.quote.quoteId}),
      ],
      'dynamicAddOns': _partner.values.map((p) => {'quoteId': p.quote.quoteId}).toList(),
      // Afbestillingsforsikring: prisen sættes af TideRMS; Core gemmer den på bookingen
      'withCancellationInsurance': _withInsurance && _insuranceOffer != null,
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
    final nameParts = name.split(RegExp(r'\s+'));
    if (nameParts.length < 2) {
      // Intet opfundet efternavn – kunden skal selv skrive det
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('bookingWizard.missingLastName'))),
      );
      return;
    }
    if (_gender == null || _nationality == null || _birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('bookingWizard.missingPassengerDetails'))),
      );
      return;
    }
    String? fellowProblem;
    for (var i = 0; i < _fellows.length && fellowProblem == null; i++) {
      final f = _fellows[i];
      if (f.firstCtrl.text.trim().isEmpty || f.lastCtrl.text.trim().isEmpty || f.birthDate == null || f.gender == null || f.nationality == null) {
        fellowProblem = tr('bookingWizard.step4.missingFellowDetails', {'n': i + 2});
      } else if (f.type == 'CHILD' && _departure != null && _ageOn(f.birthDate!, _departure!.scheduledDepartureTime) > 15) {
        fellowProblem = tr('bookingWizard.step4.childTooOld', {'n': i + 2});
      }
    }
    if (fellowProblem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(fellowProblem)));
      return;
    }
    if (_hasVehicle && _plateCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('bookingWizard.step4.missingPlate'))),
      );
      return;
    }
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('bookingWizard.consent.termsRequired'))),
      );
      return;
    }
    final dep = _departure;
    if (dep == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: GoNordicTheme.error, content: Text(tr('bookingWizard.noDeparture'))),
      );
      return;
    }

    setState(() => _isProcessingPayment = true);

    final firstName = nameParts.first;
    final lastName = nameParts.sublist(1).join(' ');

    if (!await _refreshPartnerQuotes()) {
      if (!mounted) return;
      setState(() => _isProcessingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: GoNordicTheme.error, content: Text(tr('bookingWizard.partner.expired'))));
      return;
    }
    final draft = _buildDraft(dep, firstName: firstName, lastName: lastName, name: name, email: email, phone: phone);

    final session = await ApiService().startCheckout(draft);
    if (!mounted) return;
    setState(() => _isProcessingPayment = false);

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

  String _two(int n) => n.toString().padLeft(2, '0');

  /// Alder i hele år på rejsedagen
  int _ageOn(String birthDate, DateTime day) {
    final b = DateTime.tryParse(birthDate);
    if (b == null) return 0;
    var age = day.year - b.year;
    if (day.month < b.month || (day.month == b.month && day.day < b.day)) age--;
    return age;
  }

  /// Indlæsning, fejl (med "Prøv igen") eller tom tilstand – bruges for alt, der hentes fra Core.
  Widget _status({required bool loading, required bool failed, required String loadingText, required String failedText, VoidCallback? onRetry, String? emptyText}) {
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Expanded(child: Text(loadingText, style: const TextStyle(fontSize: 12, color: GoNordicTheme.textSecondary))),
          ],
        ),
      );
    }
    if (failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(failedText, style: const TextStyle(color: GoNordicTheme.error, fontSize: 12, fontWeight: FontWeight.bold))),
            if (onRetry != null) TextButton(onPressed: onRetry, child: Text(tr('bookingWizard.retry'))),
          ],
        ),
      );
    }
    if (emptyText != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(emptyText, style: const TextStyle(fontSize: 12, color: GoNordicTheme.textSecondary)),
      );
    }
    return const SizedBox.shrink();
  }

  /// Partnerbillet (fx Tivoli): vælges med dato, tidspunkt og antal i et ark – prisen kommer fra partneren via Core.
  Widget _partnerTile(AddOnModel a) {
    final sel = _partner[a.id];
    return Card(
      key: Key('wizard-partner-${a.id}'),
      child: ListTile(
        title: Text(a.label),
        subtitle: sel == null
            ? (a.partnerName.isEmpty ? null : Text(tr('bookingWizard.partner.partner', {'name': a.partnerName})))
            : Text(tr('bookingWizard.partner.summary', {'date': sel.date, 'time': sel.time == null ? '' : ' ${sel.time}', 'count': sel.ticketCount, 'amount': sel.quote.totalPriceDkk.round()})),
        trailing: TextButton(
          onPressed: () => _openPartnerSheet(a),
          child: Text(sel == null ? tr('bookingWizard.partner.choose') : tr('bookingWizard.partner.change')),
        ),
      ),
    );
  }

  Future<void> _openPartnerSheet(AddOnModel a) async {
    final dep = _departure;
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PartnerTicketSheet(addOn: a, initialDate: dep?.portDate ?? DateTime.now().toIso8601String().split('T').first, current: _partner[a.id]),
    );
    if (!mounted) return;
    if (result is PartnerSelection) {
      setState(() => _partner[a.id] = result);
      _refreshQuote();
    } else if (result == false) {
      setState(() => _partner.remove(a.id));
      _refreshQuote();
    }
  }

  /// Tilbuddet fra partneren gælder 15 minutter: er det ældre end 12, hentes et nyt med samme valg før betaling.
  Future<bool> _refreshPartnerQuotes() async {
    for (final entry in _partner.entries.toList()) {
      final p = entry.value;
      if (DateTime.now().difference(p.quotedAt).inMinutes < 12) continue;
      try {
        final q = await ApiService().partnerQuote(p.addOn.id, date: p.date, time: p.time, tickets: p.tickets);
        _partner[entry.key] = PartnerSelection(addOn: p.addOn, date: p.date, time: p.time, tickets: p.tickets, quote: q, quotedAt: DateTime.now());
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  /// Afbestillingsforsikring som tilvalg – kun når TideRMS har en til rejsen.
  Widget _insuranceTile() {
    final o = _insuranceOffer;
    if (o == null) return const SizedBox.shrink();
    final details = [
      // TideRMS' beskrivelse er på dansk – på andre sprog bruges appens egen tekst
      (TextsService.instance.language == 'da' && (o.description?.isNotEmpty ?? false)) ? o.description! : tr('bookingWizard.insurance.lead'),
      if (o.priceType == 'PERCENT' && o.percent != null) tr('bookingWizard.insurance.percent', {'percent': o.percent! % 1 == 0 ? o.percent!.round() : o.percent!}),
      if (o.priceType == 'FIXED' && o.per == 'PERSON') tr('bookingWizard.insurance.perPerson'),
      if (!o.premiumRefundable) tr('bookingWizard.insurance.notRefundable'),
    ].join(' · ');
    return Card(
      key: const Key('wizard-insurance'),
      child: CheckboxListTile(
        value: _withInsurance,
        activeColor: GoNordicTheme.pine,
        title: Text(tr('bookingWizard.insurance.title', {'provider': o.provider})),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('bookingWizard.insurance.price', {'amount': o.priceDkk.toStringAsFixed(o.priceDkk % 1 == 0 ? 0 : 2).replaceAll('.', ',')}), style: const TextStyle(fontWeight: FontWeight.bold, color: GoNordicTheme.pine)),
            Text(details, style: const TextStyle(fontSize: 11)),
            if (o.termsUrl != null && o.termsUrl!.isNotEmpty)
              Text('${tr('bookingWizard.insurance.terms')}: ${o.termsUrl}', style: const TextStyle(fontSize: 11, color: GoNordicTheme.teal)),
          ],
        ),
        onChanged: (v) {
          setState(() => _withInsurance = v == true);
          _refreshQuote();
        },
      ),
    );
  }

  /// Prisen fra Core – vises kun, når serveren har beregnet den.
  Widget _quoteView() {
    if (_serverTotal != null) {
      return Text(tr('bookingWizard.step4.total', {'amount': _serverTotal!.round()}), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GoNordicTheme.pine));
    }
    return _status(
      loading: _quoteLoading,
      failed: _quoteFailed,
      loadingText: tr('bookingWizard.quote.loading'),
      failedText: tr('bookingWizard.quote.failed'),
      onRetry: _refreshQuote,
    );
  }

  Widget _step1() {
    final service = BookingService();
    final routes = service.routes;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _partyCard(),
        const SizedBox(height: 12),
        Text(tr('bookingWizard.step1.title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        if (routes.isEmpty)
          _status(
            loading: service.routesLoading,
            failed: !service.routesLoading,
            loadingText: tr('bookingWizard.step1.routesLoading'),
            failedText: tr('bookingWizard.step1.routesUnavailable'),
            onRetry: () => service.syncBackend(),
          )
        else
          Card(
            child: Column(
              children: routes.map((r) => ListTile(
                title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                leading: Icon(
                  _routeId == r.id ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: GoNordicTheme.pine,
                ),
                onTap: () {
                  if (_routeId != r.id) _selectRoute(r.id);
                },
              )).toList(),
            ),
          ),
        const SizedBox(height: 12),
        if (_routeId != null)
          Builder(builder: (context) {
            final dep = _departure;
            if (dep == null) {
              return _status(
                loading: _departuresLoading,
                failed: _departuresFailed,
                loadingText: tr('bookingWizard.step1.departuresLoading'),
                failedText: tr('bookingWizard.step1.departuresUnavailable'),
                onRetry: _loadDepartures,
                emptyText: tr('bookingWizard.step1.noDepartures'),
              );
            }
            final ret = _returnDeparture;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _departureLine('bookingWizard.step1.departure', dep),
                  if (_isCruise)
                    ret != null
                        ? _departureLine('bookingWizard.step1.returnDeparture', ret)
                        : _status(
                            loading: _returnLoading,
                            failed: _returnFailed,
                            loadingText: tr('bookingWizard.step1.returnLoading'),
                            failedText: tr('bookingWizard.step1.returnUnavailable'),
                            onRetry: _loadReturnDeparture,
                            emptyText: tr('bookingWizard.step1.noReturn'),
                          ),
                ],
              ),
            );
          }),
        ElevatedButton(
          onPressed: _departure == null || (_isCruise && _returnDeparture == null)
              ? null
              : () {
                  setState(() => _step = 2);
                  _loadCabins();
                },
          child: Text(tr('bookingWizard.step1.next')),
        ),
      ],
    );
  }

  /// Afgangstid i havnens tid, ikke telefonens
  Widget _departureLine(String key, DepartureModel d) {
    final t = portTime(d.scheduledDepartureTime);
    return Text(
      tr(key, {'date': '${t.day}/${t.month}-${t.year}', 'time': '${_two(t.hour)}:${_two(t.minute)}'}),
      style: const TextStyle(fontWeight: FontWeight.w600, color: GoNordicTheme.pine),
    );
  }

  /// Søgningens valg: rejsetype, rejsende og køretøj – kan rettes her.
  Widget _partyCard() {
    Widget counter(String label, int value, int min, ValueChanged<int> onChanged, String key) => Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        IconButton(
          key: Key('$key-minus'),
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        Text('$value', key: Key('$key-count'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        IconButton(
          key: Key('$key-plus'),
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < 9 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('wizard-trip-cruise'),
                  label: Text(tr('bookingWizard.step1.cruise')),
                  selected: _isCruise,
                  onSelected: (_) => _setTripType('CRUISE'),
                ),
                ChoiceChip(
                  key: const Key('wizard-trip-oneway'),
                  label: Text(tr('bookingWizard.step1.oneway')),
                  selected: !_isCruise,
                  onSelected: (_) => _setTripType('ONEWAY'),
                ),
              ],
            ),
            Text(tr(_isCruise ? 'bookingWizard.step1.cruiseHint' : 'bookingWizard.step1.onewayHint'), style: const TextStyle(fontSize: 11, color: GoNordicTheme.textSecondary)),
            const Divider(height: 16),
            counter(tr('explore.passengerModal.adults'), _adults, 1, (v) { _adults = v; _onPartyChanged(); }, 'wizard-adults'),
            counter(tr('explore.passengerModal.children'), _children, 0, (v) { _children = v; _onPartyChanged(); }, 'wizard-children'),
            SwitchListTile(
              key: const Key('wizard-vehicle'),
              contentPadding: const EdgeInsets.only(right: 8),
              dense: true,
              title: Text(tr('explore.passengerModal.bringVehicle'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              value: _hasVehicle,
              activeThumbColor: GoNordicTheme.pine,
              onChanged: (v) { _hasVehicle = v; _onPartyChanged(); },
            ),
            if (_hasVehicle)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: DropdownButtonFormField<String>(
                  key: const Key('wizard-vehicle-category'),
                  initialValue: _vehicleCategory,
                  decoration: InputDecoration(labelText: tr('bookingWizard.vehicle.category')),
                  items: _vehicleCategories.map((c) => DropdownMenuItem(value: c, child: Text(tr('bookingWizard.vehicle.categories.$c')))).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    _vehicleCategory = v;
                    _onPartyChanged();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _step2() {
    // Alle rejsende skal kunne være i kahytten (Core afviser ellers bookingen)
    final all = _cabins;
    final cabins = all?.where((c) => c.berths >= _paxCount).toList();
    final hidden = (all?.length ?? 0) - (cabins?.length ?? 0);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(tr('bookingWizard.step2.title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (cabins == null || cabins.isEmpty)
          _status(
            loading: _cabinsLoading,
            failed: _cabinsFailed,
            loadingText: tr('bookingWizard.step2.loading'),
            failedText: tr('bookingWizard.step2.unavailable'),
            onRetry: _loadCabins,
            emptyText: cabins == null ? null : tr(hidden > 0 ? 'bookingWizard.step2.noneForParty' : 'bookingWizard.step2.none', {'count': _paxCount}),
          )
        else ...[
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(tr('bookingWizard.step2.capacityNote', {'count': _paxCount}), style: const TextStyle(fontSize: 11, color: GoNordicTheme.textSecondary)),
            ),
          ...cabins.map((c) => CabinCard(
            cabin: c,
            isSelected: _cabin?.category == c.category,
            onSelect: () {
              setState(() => _cabin = c);
              _refreshQuote();
            },
          )),
        ],
        if (_cabin != null) _quoteView(),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: cabins == null
              ? null
              : () {
                  if (cabins.isNotEmpty && _cabin == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('bookingWizard.step2.selectCabin'))),
                    );
                    return;
                  }
                  setState(() => _step = 3);
                  if (_addOnCatalog == null) _loadAddOns();
                },
          child: Text(tr('bookingWizard.step2.next')),
        ),
      ],
    );
  }

  Widget _step3() {
    final catalog = _addOnCatalog;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(tr('bookingWizard.step3.title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        if (catalog == null || catalog.isEmpty)
          _status(
            loading: _addOnsLoading,
            failed: _addOnsFailed,
            loadingText: tr('bookingWizard.step3.loading'),
            failedText: tr('bookingWizard.step3.unavailable'),
            onRetry: _loadAddOns,
            emptyText: catalog == null ? null : tr('bookingWizard.step3.none'),
          )
        else
          ...catalog.map((a) => a.isPartner ? _partnerTile(a) : Card(
            child: CheckboxListTile(
              title: Text(a.label),
              subtitle: a.priceDkk == null ? null : Text(tr('bookingWizard.step3.price', {'amount': a.priceDkk!.round()})),
              value: _addons.containsKey(a.id), activeColor: GoNordicTheme.pine,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _addons[a.id] = 1;
                  } else {
                    _addons.remove(a.id);
                  }
                });
                _refreshQuote();
              },
            ),
          )),
        const SizedBox(height: 8),
        _quoteView(),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            setState(() => _step = 4);
            if (_serverTotal == null && !_quoteLoading) _refreshQuote();
          },
          child: Text(tr('bookingWizard.step3.next')),
        ),
      ],
    );
  }

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
                  child: Text(
                    user.clubTier.isNotEmpty
                        ? tr('bookingWizard.step4.loggedInAs', {'name': user.fullName, 'tier': user.clubTier})
                        : tr('bookingWizard.step4.loggedInAsNoTier', {'name': user.fullName}),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
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
                      if (!mounted) return;
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fellows.isEmpty ? tr('bookingWizard.step4.travellerTitle') : tr('bookingWizard.step4.travellerN', {'n': 1, 'type': tr('bookingWizard.step4.adult')}), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._travellerFields(
                  keyPrefix: 'wizard',
                  birthDate: _birthDate,
                  onBirthDate: (v) => setState(() => _birthDate = v),
                  gender: _gender,
                  onGender: (v) => setState(() => _gender = v),
                  nationality: _nationality,
                  onNationality: (v) => setState(() => _nationality = v),
                  defaultAge: 30,
                ),
                const SizedBox(height: 6),
                Text(tr('bookingWizard.step4.manifestNote'), style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
        ),
        for (var i = 0; i < _fellows.length; i++) _fellowCard(i),
        if (_hasVehicle) _vehicleCard(),
        const SizedBox(height: 8),
        _insuranceTile(),
        const SizedBox(height: 8),
        // Kun Core's pris vises; uden pris kan der ikke betales
        _quoteView(),
        const SizedBox(height: 8),
        _consentCard(),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _isProcessingPayment || _serverTotal == null || !_termsAccepted ? null : _startPaymentFlow,
          child: _isProcessingPayment
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(tr('bookingWizard.step4.continueToPayment')),
        ),
      ],
    );
  }

  /// Fødselsdato, køn og nationalitet til passagerlisten – samme felter for alle rejsende.
  List<Widget> _travellerFields({
    required String keyPrefix,
    required String? birthDate,
    required ValueChanged<String> onBirthDate,
    required String? gender,
    required ValueChanged<String?> onGender,
    required String? nationality,
    required ValueChanged<String?> onNationality,
    required int defaultAge,
  }) {
    return [
      InkWell(
        key: Key('$keyPrefix-birthdate'),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: birthDate != null ? DateTime.tryParse(birthDate) ?? DateTime(now.year - defaultAge) : DateTime(now.year - defaultAge),
            firstDate: DateTime(1900),
            lastDate: now,
          );
          if (picked != null) onBirthDate(picked.toIso8601String().split('T').first);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: tr('bookingWizard.step4.birthDate')),
          child: Text(birthDate ?? tr('bookingWizard.step4.choose')),
        ),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        key: Key('$keyPrefix-gender'),
        initialValue: gender,
        decoration: InputDecoration(labelText: tr('bookingWizard.step4.gender')),
        items: [
          DropdownMenuItem(value: 'FEMALE', child: Text(tr('bookingWizard.step4.genderFemale'))),
          DropdownMenuItem(value: 'MALE', child: Text(tr('bookingWizard.step4.genderMale'))),
          DropdownMenuItem(value: 'OTHER', child: Text(tr('bookingWizard.step4.genderOther'))),
        ],
        onChanged: onGender,
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        key: Key('$keyPrefix-nationality'),
        initialValue: _countries.contains(nationality) ? nationality : null,
        decoration: InputDecoration(labelText: tr('bookingWizard.step4.nationality')),
        items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(tr('countries.$c')))).toList(),
        onChanged: onNationality,
      ),
    ];
  }

  /// Medrejsende nr. i+2: navn og passagerlistens oplysninger
  Widget _fellowCard(int i) {
    final f = _fellows[i];
    final prefix = 'wizard-p${i + 2}';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        key: Key(prefix),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('bookingWizard.step4.travellerN', {'n': i + 2, 'type': tr(f.type == 'CHILD' ? 'bookingWizard.step4.child' : 'bookingWizard.step4.adult')}),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(key: Key('$prefix-first'), controller: f.firstCtrl, decoration: InputDecoration(labelText: tr('bookingWizard.step4.firstName'))),
              const SizedBox(height: 8),
              TextField(key: Key('$prefix-last'), controller: f.lastCtrl, decoration: InputDecoration(labelText: tr('bookingWizard.step4.lastName'))),
              const SizedBox(height: 8),
              ..._travellerFields(
                keyPrefix: prefix,
                birthDate: f.birthDate,
                onBirthDate: (v) => setState(() => f.birthDate = v),
                gender: f.gender,
                onGender: (v) => setState(() => f.gender = v),
                nationality: f.nationality,
                onNationality: (v) => setState(() => f.nationality = v),
                defaultAge: f.type == 'CHILD' ? 8 : 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Køretøjet: typen er valgt i trin 1, nummerpladen skrives her
  Widget _vehicleCard() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('bookingWizard.vehicle.title'), style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(tr('bookingWizard.vehicle.categories.$_vehicleCategory'), style: const TextStyle(fontSize: 12, color: GoNordicTheme.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              key: const Key('wizard-plate'),
              controller: _plateCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: tr('bookingWizard.vehicle.licensePlate')),
            ),
          ],
        ),
      ),
    ),
  );

  /// Accept af rejsebetingelserne (påkrævet) og samtykke til markedsføring (frivilligt) – ingen er forudvalgt.
  Widget _consentCard() => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            key: const Key('wizard-terms'),
            value: _termsAccepted,
            onChanged: (v) => setState(() => _termsAccepted = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text(tr('bookingWizard.consent.termsAccept', {'version': SiteLinks.termsVersionId}), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            subtitle: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('wizard-terms-link'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () => SitePageScreen.openTerms(context),
                child: Text(tr('bookingWizard.consent.readTerms'), style: const TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
              ),
            ),
          ),
          CheckboxListTile(
            key: const Key('wizard-marketing-consent'),
            value: _marketingConsent,
            onChanged: (v) => setState(() => _marketingConsent = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text(tr('bookingWizard.consent.marketing'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            subtitle: Text(tr('bookingWizard.consent.marketingHint'), style: const TextStyle(fontSize: 11, color: GoNordicTheme.textSecondary)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextButton(
              key: const Key('wizard-privacy-link'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () => SitePageScreen.openPrivacyPolicy(context),
              child: Text(tr('bookingWizard.consent.privacyLink'), style: const TextStyle(fontSize: 11, decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ),
    ),
  );

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

/// En medrejsende (passager 2 og frem). Typen følger søgningen: voksen eller barn (0–15 år).
class _FellowTraveller {
  final String type;
  final firstCtrl = TextEditingController();
  final lastCtrl = TextEditingController();
  String? birthDate;
  String? gender;
  String? nationality;

  _FellowTraveller(this.type);

  void dispose() {
    firstCtrl.dispose();
    lastCtrl.dispose();
  }
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

