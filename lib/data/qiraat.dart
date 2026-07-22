/// The ten canonical Qirā'āt (advanced mode). Study notes only — the
/// Qirā'āt are transmitted person-to-person; this module is a map of the
/// terrain, and the app says so in the UI. Always verify with a teacher.
class Qiraah {
  final String reader;
  final String arabic;
  final String city;
  final String died; // AH
  final String rawi1;
  final String rawi2;
  final List<String> signatures; // famous usul features
  final String bio; // short biography (facts per abouttajweed.com)

  const Qiraah(this.reader, this.arabic, this.city, this.died, this.rawi1,
      this.rawi2, this.signatures,
      {this.bio = ''});
}

const qiraat = <Qiraah>[
  Qiraah('Nāfi‘ al-Madanī', 'نَافِع', 'Madinah', '169', 'Qālūn', 'Warsh', [
    'Warsh: muttaṣil & munfaṣil madd stretched to 6 counts',
    'Warsh: taqlīl (slight imālah) of many final alifs',
    'Warsh: tashīl / naql of hamzah (e.g. قَدَفْلَحَ for قَدْ أَفْلَحَ)',
    'Qālūn: ṣilah of mīm al-jam‘ (عَلَيْهِمُو) as an option',
  ],
      bio:
          'Nāfi‘ ibn ‘Abd ar-Raḥmān ibn Abī Nu‘aym (Abū Ruwaym), of Isfahani origin, born 70 AH and passed away 169 AH in Madinah. He recited to around seventy of the tābi‘īn — among them Abū Ja‘far — and became the imam of recitation in Madinah after him. His two transmitters are Qālūn and Warsh.'),
  Qiraah('Ibn Kathīr al-Makkī', 'ابْن كَثِير', 'Makkah', '120', 'Al-Bazzī', 'Qunbul', [
    'Ṣilah of mīm al-jam‘ throughout (هُمُو / عَلَيْهِمُو)',
    'Munfaṣil madd read short (2 counts)',
    'Qunbul: السِّرَاط with sīn in al-Fātiḥah',
  ],
      bio:
          '‘Abdullāh ibn Kathīr, the imam of recitation in Makkah and one of the tābi‘īn, passed away 120 AH. His reading reaches us through al-Bazzī (d. 250 AH) and Qunbul (d. 291 AH), each via unbroken chains from him.'),
  Qiraah('Abū ‘Amr al-Baṣrī', 'أَبُو عَمْرو', 'Basrah', '154', 'Ad-Dūrī', 'As-Sūsī', [
    'As-Sūsī: idghām kabīr (merging like letters across words)',
    'Imālah of words like النَّاسِ in jarr (Dūrī)',
    'Munfaṣil madd may be shortened',
  ],
      bio:
          'Zabbān ibn al-‘Alā’, Abū ‘Amr of Basrah (d. 154 AH), was among the greatest scholars of both recitation and Arabic — one of the founding figures of Arabic linguistics. Ad-Dūrī (d. 246 AH) and as-Sūsī (d. 261 AH) transmit his reading.'),
  Qiraah('Ibn ‘Āmir ash-Shāmī', 'ابْن عَامِر', 'Damascus', '118', 'Hishām', 'Ibn Dhakwān', [
    'The earliest of the ten readers (a tābi‘ī)',
    'Several unique word-forms in 2:116 and elsewhere',
  ],
      bio:
          '‘Abdullāh ibn ‘Āmir al-Yaḥṣubī (d. 118 AH), a tābi‘ī and the judge of Damascus, is the earliest of the ten readers. His reading was the recitation of Greater Syria, carried by Hishām (d. 245 AH) and Ibn Dhakwān (d. 242 AH).'),
  Qiraah('‘Āṣim al-Kūfī', 'عَاصِم', 'Kufah', '127', 'Shu‘bah', 'Ḥafṣ', [
    'Ḥafṣ ‘an ‘Āṣim: the transmission most of the world recites today',
    'Madd muttaṣil/munfaṣil at 4–5 counts',
    'Single imālah in Ḥafṣ: مَجْرَاهَا (11:41)',
  ],
      bio:
          '‘Āṣim ibn Bahdalah Abī an-Najūd (Abū Bakr), a tābi‘ī, led the reciters of Kufah after ‘Abd ar-Raḥmān as-Sulamī and was famed for eloquence, mastery, and the finest voice of his time; he passed away 127 AH. His transmitters are Shu‘bah (95–193 AH) and Ḥafṣ (90–180 AH) — the riwāyah most of the Muslim world reads today.'),
  Qiraah('Ḥamzah al-Kūfī', 'حَمْزَة', 'Kufah', '156', 'Khalaf', 'Khallād', [
    'Long madd: 6 counts in muttaṣil and munfaṣil',
    'Sakt (brief pause) before hamzah in some positions',
    'Extensive imālah; ishmām of الصِّرَاط toward zāy (Khalaf)',
  ],
      bio:
          'Ḥamzah ibn Ḥabīb az-Zayyāt (80–156 AH), an oil merchant of Kufah, devout and precise, became the city’s imam of recitation after ‘Āṣim and al-A‘mash. Khalaf (d. 229 AH) and Khallād (d. 220 AH) transmit his reading.'),
  Qiraah('Al-Kisā’ī', 'الْكِسَائِي', 'Kufah', '189', 'Abū al-Ḥārith', 'Ad-Dūrī', [
    'Systematic imālah of final alifs (e.g. الضُّحَى → ḍuḥē)',
    'Imālah of the tā’ marbūṭah at stops in many words',
  ],
      bio:
          '‘Alī ibn Ḥamzah al-Kisā’ī (d. 189 AH) headed the Kufan school of Arabic grammar and succeeded Ḥamzah in leading its reciters. His reading is carried by Abū al-Ḥārith (d. 240 AH) and ad-Dūrī (d. 246 AH) — the same Dūrī who transmits Abū ‘Amr.'),
  Qiraah('Abū Ja‘far al-Madanī', 'أَبُو جَعْفَر', 'Madinah', '130', 'Ibn Wardān', 'Ibn Jammāz', [
    'Ṣilah of mīm al-jam‘',
    'Gentle, simplified hamzah treatment',
  ],
      bio:
          'Yazīd ibn al-Qa‘qā‘, Abū Ja‘far (d. 130 AH), a tābi‘ī and the elder imam of recitation in Madinah — Nāfi‘ was among his students. Ibn Wardān (d. ~160 AH) and Ibn Jammāz (d. ~170 AH) transmit his reading.'),
  Qiraah('Ya‘qūb al-Baṣrī', 'يَعْقُوب', 'Basrah', '205', 'Ruways', 'Rawḥ', [
    'Stops on هـ of pronouns with hā’ as-sakt (e.g. عَلَيْهِيهْ)',
    'Munfaṣil madd short',
  ],
      bio:
          'Ya‘qūb ibn Isḥāq al-Ḥaḍramī (117–205 AH) inherited the leadership of Basrah’s reciters after Abū ‘Amr’s school; the imam of the grand mosque of Basrah. His transmitters are Ruways (d. 238 AH) and Rawḥ (d. 234 AH).'),
  Qiraah('Khalaf al-‘Āshir', 'خَلَف الْعَاشِر', 'Kufah/Baghdad', '229', 'Isḥāq', 'Idrīs', [
    'Chooses between Ḥamzah and al-Kisā’ī without sakt',
  ],
      bio:
          'Khalaf ibn Hishām al-Bazzār (150–229 AH) of Baghdad memorised the Qur’an at ten. Best known as a transmitter of Ḥamzah, he also chose a reading of his own — the tenth qirā’ah — carried by Isḥāq (d. 286 AH) and Idrīs (d. 292 AH).'),
];

class QiraatDifference {
  final String ref;
  final String topic;
  final String hafs; // as read in Ḥafṣ
  final String variant;
  final String readBy;
  final String note;

  const QiraatDifference(this.ref, this.topic, this.hafs, this.variant,
      this.readBy, this.note);
}

const qiraatDifferences = <QiraatDifference>[
  QiraatDifference(
    '1:4', 'Word form', 'مَالِكِ يَوْمِ الدِّينِ', 'مَلِكِ يَوْمِ الدِّينِ',
    'Nāfi‘, Ibn Kathīr, Abū ‘Amr, Ibn ‘Āmir, Ḥamzah, Abū Ja‘far',
    '“Māliki” (Owner) is read by ‘Āṣim, al-Kisā’ī, Ya‘qūb and Khalaf; the rest read “Maliki” (King). Both are mass-transmitted and both meanings are true of Allah.',
  ),
  QiraatDifference(
    '1:6', 'Pronunciation of ṣād', 'الصِّرَاطَ', 'السِّرَاطَ',
    'Qunbul ‘an Ibn Kathīr (sīn); Khalaf ‘an Ḥamzah (ishmām toward zāy)',
    'A pure articulation difference on the same word — a window into how precisely the readings were preserved.',
  ),
  QiraatDifference(
    '2:9', 'Verb pattern', 'وَمَا يَخْدَعُونَ إِلَّآ أَنفُسَهُمْ', 'وَمَا يُخَادِعُونَ إِلَّآ أَنفُسَهُمْ',
    'Nāfi‘, Ibn Kathīr, Abū ‘Amr',
    'Form I vs Form III of the same root خ-د-ع; the readings together enrich the meaning.',
  ),
  QiraatDifference(
    '2:10', 'Verb pattern', 'بِمَا كَانُوا يَكْذِبُونَ', 'بِمَا كَانُوا يُكَذِّبُونَ',
    'Nāfi‘, Ibn Kathīr, Abū ‘Amr, Ibn ‘Āmir, Abū Ja‘far, Ya‘qūb',
    'The Kufans (‘Āṣim, Ḥamzah, al-Kisā’ī, Khalaf) read “yakdhibūn” (they lie); the others “yukadhdhibūn” (they deny).',
  ),
  QiraatDifference(
    '11:41', 'Imālah', 'مَجْر۪ىٰهَا (majrēhā)', 'مَجْرَاهَا (majrāhā)',
    'Imālah by Ḥafṣ (his only one), Ḥamzah, al-Kisā’ī, Khalaf',
    'Imālah leans the alif toward an “ē” sound. This word is the single imālah in the Ḥafṣ transmission.',
  ),
  QiraatDifference(
    '97:1', 'Madd munfaṣil length', 'إِنَّآ أَنزَلْنَاهُ — 4–5 counts', 'Same letters — 2 counts (qaṣr) or 6 (ṭūl)',
    'Short: Ibn Kathīr, Abū Ja‘far, Ya‘qūb, (Qālūn & Dūrī optionally). Long: Warsh, Ḥamzah',
    'The words are identical; the transmitted timing differs. Train each length in the Counts Studio.',
  ),
  QiraatDifference(
    '93:1–2', 'Imālah of final alif', 'وَالضُّحَىٰ — plain ā', 'ē-leaning (imālah) / between (taqlīl)',
    'Imālah: Ḥamzah, al-Kisā’ī, Khalaf. Taqlīl: Warsh, Abū ‘Amr (Dūrī)',
    'Final-alif words from yā’-roots lean in several readings — one of the most audible Qirā’āt signatures.',
  ),
];
