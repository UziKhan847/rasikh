import '../data/mushaf.dart';
import 'l10n.dart';
import 'settings.dart';

/// The muṣḥafs to choose from: generated (typeset by the app) or original
/// (drawn from the print itself). What's chosen is a script id; one without
/// a [script] isn't ready yet, and shows greyed out.
class MushafEdition {
  final String? script;
  final String Function(AppLocalizations) name;
  const MushafEdition(this.name, [this.script]);
}

String _newMadani(AppLocalizations l) => l.edNewMadani;
String _oldMadani(AppLocalizations l) => l.edOldMadani;
String _indoPak(AppLocalizations l) => l.indoPak;

const kGeneratedEditions = [
  MushafEdition(_newMadani, 'uthmani'),
  MushafEdition(_indoPak, 'indopak'),
];
const kOriginalEditions = [
  MushafEdition(_oldMadani, kOldMadani),
  MushafEdition(_newMadani, kNewMadaniPrint),
  MushafEdition(_indoPak),
];

/// [script]'s name, for what's chosen now.
String mushafEditionName(AppLocalizations l, String script) => switch (script) {
      kOldMadani => l.edOldMadani,
      'indopak' => l.indoPak,
      _ => l.edNewMadani,
    };

/// Whether [editions]'s script can be picked here.
bool mushafEditionOn(MushafEdition e) =>
    e.script != null && (e.script != 'indopak' || kIndopakMushafAvailable);
