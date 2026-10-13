import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/texts_service.dart';

/// Et sprog i vælgeren: kode, kort navn (DK/NO/UK), navn på sproget selv og flag som SVG.
class _Lang {
  const _Lang(this.code, this.short, this.label, this.flag);
  final String code, short, label, flag;
}

const _dk = '<svg viewBox="0 0 37 28" xmlns="http://www.w3.org/2000/svg"><rect width="37" height="28" fill="#C8102E"/><rect x="12" width="4" height="28" fill="#fff"/><rect y="12" width="37" height="4" fill="#fff"/></svg>';
const _no = '<svg viewBox="0 0 22 16" xmlns="http://www.w3.org/2000/svg"><rect width="22" height="16" fill="#BA0C2F"/><rect x="6" width="4" height="16" fill="#fff"/><rect y="6" width="22" height="4" fill="#fff"/><rect x="7" width="2" height="16" fill="#00205B"/><rect y="7" width="22" height="2" fill="#00205B"/></svg>';
// Union Jack uden clipPath (flutter_svg): de røde diagonaler er lagt forskudt som på det rigtige flag
const _uk = '<svg viewBox="0 0 60 30" xmlns="http://www.w3.org/2000/svg"><rect width="60" height="30" fill="#012169"/>'
    '<path d="M0,0 L60,30 M60,0 L0,30" stroke="#fff" stroke-width="6"/>'
    '<path d="M0,0 L30,15 M60,30 L30,15" stroke="#C8102E" stroke-width="2" transform="translate(0,-1)"/>'
    '<path d="M60,0 L30,15 M0,30 L30,15" stroke="#C8102E" stroke-width="2" transform="translate(0,1)"/>'
    '<path d="M30,0 v30 M0,15 h60" stroke="#fff" stroke-width="10"/><path d="M30,0 v30 M0,15 h60" stroke="#C8102E" stroke-width="6"/></svg>';

const _langs = [
  _Lang('da', 'DK', 'Dansk', _dk),
  _Lang('no', 'NO', 'Norsk', _no),
  _Lang('en', 'UK', 'English (UK)', _uk),
];

Widget _flag(_Lang l) => ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SvgPicture.string(l.flag, width: 22, height: 15, fit: BoxFit.cover),
    );

/// Sprogvalg som dropdown med flag og DK/NO/UK – til app-bjælken. Valget gemmes og huskes ved næste start.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, this.color = Colors.white});

  /// Farve på koden og pilen (hvid på den mørke app-bjælke)
  final Color color;

  @override
  Widget build(BuildContext context) {
    final texts = TextsService.instance;
    final current = _langs.firstWhere((l) => l.code == texts.language, orElse: () => _langs.first);
    return PopupMenuButton<String>(
      key: const Key('languagePicker'),
      tooltip: 'Sprog · Språk · Language',
      initialValue: current.code,
      position: PopupMenuPosition.under,
      onSelected: (code) {
        if (code != texts.language) texts.setLanguage(code);
      },
      itemBuilder: (_) => [
        for (final l in _langs)
          PopupMenuItem<String>(
            value: l.code,
            child: Row(children: [
              _flag(l),
              const SizedBox(width: 10),
              SizedBox(width: 28, child: Text(l.short, style: const TextStyle(fontWeight: FontWeight.bold))),
              Text(l.label),
              if (l.code == current.code) ...[const Spacer(), const Icon(Icons.check, size: 18)],
            ]),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _flag(current),
          const SizedBox(width: 6),
          Text(current.short, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          Icon(Icons.arrow_drop_down, color: color, size: 20),
        ]),
      ),
    );
  }
}
