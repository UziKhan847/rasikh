/// Groups the 20 tajwīd rules (tajweed.dart) into a learning path, mirroring
/// the classical teaching order — makhārij and ṣifāt first (how sound is
/// made at all), then the nūn-sākinah and mīm-sākinah families, madd, the
/// lām rules, rā', qalqalah, and finally the special cases. Each topic
/// references rule ids rather than duplicating rule content; the phases
/// built on top of each topic (Learn/Letters/Test/Practice/Recite) live in
/// tajweed_screen.dart, since they need localized strings.
class TajwidTopic {
  final String id;
  final List<String> ruleIds; // empty for the makhārij/ṣifāt/cases topics —
  // those draw from makharij.dart/sifat.dart/tajwid_cases.dart instead.
  const TajwidTopic(this.id, this.ruleIds);
}

const tajwidTopics = <TajwidTopic>[
  TajwidTopic('makharij', []),
  TajwidTopic('sifat', []),
  TajwidTopic('nun', ['izhar', 'idgham_g', 'idgham_ng', 'iqlab', 'ikhfa']),
  TajwidTopic('mim', ['ghunnah', 'izhar_shafawi', 'ikhfa_shafawi', 'idgham_shafawi']),
  TajwidTopic('madd', ['madd2', 'madd4', 'madd45', 'madd6']),
  TajwidTopic('lam', ['shamsiyya', 'qamariyya', 'lam_jalalah']),
  TajwidTopic('raa', ['raa_tafkhim', 'raa_tarqiq']),
  TajwidTopic('qalqalah', ['qalqalah']),
  TajwidTopic('cases', []),
];

TajwidTopic tajwidTopicById(String id) => tajwidTopics.firstWhere((t) => t.id == id);
