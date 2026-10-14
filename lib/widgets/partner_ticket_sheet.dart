import 'package:flutter/material.dart';
import '../models/addon_model.dart';
import '../services/api_service.dart';
import '../services/texts_service.dart';
import '../theme/gonordic_theme.dart';

/// Partnerbilletterne, kunden har valgt til ét produkt (fx Tivoli): dato, evt. tidspunkt, antal og Core's tilbud.
class PartnerSelection {
  final AddOnModel addOn;
  final String date;
  final String? time;
  final Map<String, int> tickets;
  final PartnerQuote quote;
  final DateTime quotedAt;
  const PartnerSelection({required this.addOn, required this.date, this.time, required this.tickets, required this.quote, required this.quotedAt});

  int get ticketCount => tickets.values.fold(0, (a, b) => a + b);
}

/// Ark til partnerbilletter: dato, ledige tidspunkter (fra partneren via Core) og antal billetter pr. type.
/// Prisen er altid Core's tilbud – appen beregner ingen pris selv.
class PartnerTicketSheet extends StatefulWidget {
  final AddOnModel addOn;
  final String initialDate;
  final PartnerSelection? current;
  const PartnerTicketSheet({super.key, required this.addOn, required this.initialDate, this.current});

  @override
  State<PartnerTicketSheet> createState() => _PartnerTicketSheetState();
}

class _PartnerTicketSheetState extends State<PartnerTicketSheet> {
  static const _types = ['ADULT', 'CHILD', 'SENIOR'];
  late String _date = widget.current?.date ?? widget.initialDate;
  late String? _time = widget.current?.time;
  late final Map<String, int> _tickets = {for (final t in _types) t: widget.current?.tickets[t] ?? (t == 'ADULT' ? 2 : 0)};
  PartnerAvailability? _availability;
  bool _loadingTimes = false;
  PartnerQuote? _quote;
  bool _quoting = false;
  String? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final seq = ++_seq;
    setState(() {
      _loadingTimes = true;
      _availability = null;
      _quote = null;
      _error = null;
    });
    try {
      final a = await ApiService().partnerAvailability(widget.addOn.id, _date);
      if (!mounted || seq != _seq) return;
      setState(() {
        _availability = a;
        _loadingTimes = false;
        if (!a.requiresTime) _time = null;
        if (a.requiresTime && !a.slots.any((s) => s.time == _time && s.remaining > 0)) _time = null;
      });
      _requote();
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loadingTimes = false;
        _error = '$e';
      });
    }
  }

  Future<void> _requote() async {
    final a = _availability;
    if (a == null || a.slots.isEmpty || (a.requiresTime && _time == null) || _tickets.values.every((v) => v == 0)) {
      setState(() => _quote = null);
      return;
    }
    final seq = ++_seq;
    setState(() {
      _quoting = true;
      _error = null;
    });
    try {
      final q = await ApiService().partnerQuote(widget.addOn.id, date: _date, time: _time, tickets: _tickets);
      if (!mounted || seq != _seq) return;
      setState(() {
        _quote = q;
        _quoting = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _quote = null;
        _quoting = false;
        _error = '$e';
      });
    }
  }

  PartnerSlot? get _slot {
    final a = _availability;
    if (a == null || a.slots.isEmpty) return null;
    return a.requiresTime ? a.slots.where((s) => s.time == _time).firstOrNull : a.slots.first;
  }

  @override
  Widget build(BuildContext context) {
    final a = _availability;
    final slot = _slot ?? a?.slots.firstOrNull;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.addOn.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              if (widget.addOn.partnerName.isNotEmpty)
                Text(tr('bookingWizard.partner.partner', {'name': widget.addOn.partnerName}), style: const TextStyle(fontSize: 12, color: GoNordicTheme.textSecondary)),
              const SizedBox(height: 12),
              InkWell(
                key: const Key('partner-date'),
                onTap: () async {
                  final now = DateTime.now();
                  final initial = DateTime.tryParse(_date) ?? now;
                  final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(now.year, now.month, now.day), lastDate: now.add(const Duration(days: 400)));
                  if (picked == null) return;
                  setState(() => _date = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                  _loadAvailability();
                },
                child: InputDecorator(decoration: InputDecoration(labelText: tr('bookingWizard.partner.date')), child: Text(_date)),
              ),
              const SizedBox(height: 12),
              if (_loadingTimes)
                Row(children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(tr('bookingWizard.partner.loadingTimes'), style: const TextStyle(fontSize: 12)),
                ])
              else if (a != null && a.slots.isEmpty)
                Text(tr('bookingWizard.partner.closed'), style: const TextStyle(color: GoNordicTheme.error))
              else if (a != null && a.requiresTime) ...[
                Text(tr('bookingWizard.partner.chooseTime'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: a.slots.map((s) => ChoiceChip(
                        key: Key('partner-time-${s.time}'),
                        selected: s.time == _time,
                        selectedColor: GoNordicTheme.pine.withValues(alpha: 0.2),
                        label: Text('${s.time} · ${s.remaining > 0 ? tr('bookingWizard.partner.remaining', {'count': s.remaining}) : tr('bookingWizard.partner.soldOut')}'),
                        onSelected: s.remaining > 0
                            ? (_) {
                                setState(() => _time = s.time);
                                _requote();
                              }
                            : null,
                      )).toList(),
                ),
              ],
              const SizedBox(height: 12),
              if (slot != null)
                ..._types.where((t) => slot.prices.containsKey(t)).map((t) => Row(
                      children: [
                        Expanded(child: Text('${slot.labels[t] ?? t} · ${slot.prices[t]!.round()} DKK')),
                        IconButton(
                          key: Key('partner-minus-$t'),
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: (_tickets[t] ?? 0) > 0
                              ? () {
                                  setState(() => _tickets[t] = (_tickets[t] ?? 0) - 1);
                                  _requote();
                                }
                              : null,
                        ),
                        Text('${_tickets[t] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          key: Key('partner-plus-$t'),
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            setState(() => _tickets[t] = (_tickets[t] ?? 0) + 1);
                            _requote();
                          },
                        ),
                      ],
                    )),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: GoNordicTheme.error, fontSize: 12))),
              if (_quote?.notes != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_quote!.notes!, style: const TextStyle(fontSize: 11, color: GoNordicTheme.textSecondary))),
              const SizedBox(height: 8),
              Text(tr('bookingWizard.partner.issuedLater'), style: const TextStyle(fontSize: 11, color: GoNordicTheme.textSecondary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _quoting ? tr('bookingWizard.partner.loadingPrice') : _quote != null ? tr('bookingWizard.partner.total', {'amount': _quote!.totalPriceDkk.round()}) : '',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: GoNordicTheme.pine),
                    ),
                  ),
                  if (widget.current != null)
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('bookingWizard.partner.remove'))),
                  ElevatedButton(
                    key: const Key('partner-add'),
                    onPressed: _quote == null || _quoting
                        ? null
                        : () => Navigator.pop(
                              context,
                              PartnerSelection(addOn: widget.addOn, date: _date, time: _time, tickets: Map.of(_tickets)..removeWhere((_, v) => v == 0), quote: _quote!, quotedAt: DateTime.now()),
                            ),
                    child: Text(tr('bookingWizard.partner.add')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
