/* ================= ПЕСНИ: общие темы и темы заключённых (inm_<key>) =================
   Каждая строка pat — один такт из 16 шагов (если steps: 12 — вальс 3/4). Слои с inst.min звучат только при погоне/опасности. */
const B = (...bars) => bars.join(' ');   // склейка тактов для читаемости
// готовые треки (сгенерированы под стиль игры; встроены build.js как MUS_SRC) — подключаются в 16_main после загрузки

// ---- ночь без опознанного заключённого: тихий жуткий пульс ----
MUS.def('night', { bpm: 66, ch: {
  bass: { inst: { ...INS.bass, vol: .16 }, pat: [B('A1 - - - . . . . A1 - - - . . . .', 'A1 - - - . . . . A1 - - - . . . .', 'Bb1 - - - . . . . Bb1 - - - . . . .', 'G#1 - - - . . . . G#1 - - - . . . .')] },
  bell: { inst: { ...INS.bell, vol: .07, echo: [.36, .35] }, pat: [B('E5 - - - . . . . . . . . C5 - . .', '. . . . . . . . B4 - - - . . . .', 'F5 - - - . . . . . . E5 - . . . .', '. . . . D#5 - - - . . . . . . . .')] },
  pad: { inst: { ...INS.pad, vol: .045 }, pat: [B('A3 - - - - - - - - - - - - - - -', 'C4 - - - - - - - - - - - - - - -', 'Bb3 - - - - - - - - - - - - - - -', 'G#3 - - - - - - - - - - - - - - -')] },
  hat: { inst: { ...INS.drums, vol: .16, min: .6 }, pat: [B('. . h . . . h . . . h . . . h h', '. . h . . . h . . . h . . . h .', '. . h . . . h . . . h . . . h h', 'k . h . . . h . k . h . . . s .')] },
} });
// ---- рассвет: облегчение, мажор ----
MUS.def('dawn', { bpm: 104, ch: {
  lead: { inst: { ...INS.lead, vol: .08 }, pat: [B('C5 - E5 - G5 - - - A5 - G5 - E5 - - -', 'F5 - A5 - C6 - - - B5 - A5 - G5 - - -', 'E5 - G5 - C6 - - - D6 - C6 - B5 - A5 -', 'G5 - - - - - - - . . . . . . . .')] },
  arp: { inst: { ...INS.thin, vol: .035 }, pat: [B('C4 E4 G4 E4 C4 E4 G4 E4 C4 E4 G4 E4 C4 E4 G4 E4', 'F4 A4 C5 A4 F4 A4 C5 A4 F4 A4 C5 A4 F4 A4 C5 A4', 'A3 C4 E4 C4 A3 C4 E4 C4 F3 A3 C4 A3 F3 A3 C4 A3', 'G3 B3 D4 B3 G3 B3 D4 B3 G3 B3 D4 B3 G3 B3 D4 B3')] },
  bass: { inst: INS.bass, pat: [B('C2 - . . C3 . . . C2 - . . G2 . . .', 'F2 - . . F3 . . . F2 - . . C3 . . .', 'A2 - . . A2 . . . F2 - . . F2 . . .', 'G2 - . . G2 . . . G2 - . . B2 . . .')] },
  drums: { inst: { ...INS.drums, vol: .22 }, pat: [B('k . h . s . h . k . h k s . h .')] },
} });
MUS.def('win', { bpm: 132, ch: {
  lead: { inst: { ...INS.lead2, vol: .07 }, pat: [B('C5 - C5 - C5 - G5 - - - E5 - G5 - - -', 'A5 - G5 - E5 - C5 - D5 - E5 - C5 - - -', 'F5 - F5 - A5 - C6 - - - A5 - C6 - - -', 'D6 - - - B5 - - - C6 - - - - - - -')] },
  bass: { inst: INS.bass, pat: [B('C2 . C3 . C2 . C3 . A1 . A2 . A1 . A2 .', 'F1 . F2 . G1 . G2 . C2 . C3 . C2 . C3 .', 'F1 . F2 . F1 . F2 . A1 . A2 . A1 . A2 .', 'G1 . G2 . G1 . G2 . C2 - - - - - - -')] },
  drums: { inst: INS.drums, pat: [B('k . h . s . h . k k h . s . h h')] },
} });
MUS.def('lose', { bpm: 72, ch: {
  lead: { inst: { ...INS.lead, vol: .07, vib: [4.5, .25, .25] }, pat: [B('E5 - - - D5 - - - C5 - - - B4 - - -', 'A4 - - - - - - - G#4 - - - - - - -', 'C5 - - - B4 - - - A4 - - - G4 - - -', 'F4 - - - E4 - - - - - - - . . . .')] },
  pad: { inst: INS.pad, pat: [B('A3 - - - - - - - - - - - - - - -', 'E3 - - - - - - - - - - - - - - -', 'F3 - - - - - - - - - - - - - - -', 'E3 - - - - - - - - - - - - - - -')] },
  bass: { inst: { ...INS.bass, vol: .14 }, pat: [B('A1 - - - - - - - A1 - - - - - - -', 'E1 - - - - - - - E1 - - - - - - -', 'F1 - - - - - - - D1 - - - - - - -', 'E1 - - - - - - - E1 - - - - - - -')] },
} });

/* ---- темы заключённых ---- */
// Искатель: дразнилка «кто не спрятался» на музыкальной шкатулке, в погоне — бег и барабаны
MUS.def('inm_seeker', { bpm: 92, tempoUp: .25, ch: {
  box: { inst: { ...INS.thin, vol: .06, echo: [.24, .3] }, pat: [B('G5 - E5 - A5 - G5 - E5 - - - . . . .', 'G5 - E5 - A5 - G5 - E5 - - - . . D5 -', 'F5 - D5 - G5 - F5 - D5 - - - . . . .', 'E5 - C#5 - F5 - E5 - C#5 - - - . . . .')] },
  bass: { inst: { ...INS.bass, vol: .15 }, pat: [B('A1 . . . E2 . . . A1 . . . E2 . . .', 'A1 . . . E2 . . . A1 . . . E2 . . .', 'D2 . . . A2 . . . D2 . . . A2 . . .', 'A1 . . . E2 . . . A1 . . . G#1 . . .')] },
  run: { inst: { ...INS.lead2, vol: .05, min: .7 }, pat: [B('A4 C5 E5 C5 A4 C5 E5 C5 A4 C5 E5 C5 A4 C5 E5 C5', 'A4 C5 E5 C5 A4 C5 E5 C5 A4 C5 E5 C5 A4 C5 E5 C5', 'D4 F4 A4 F4 D4 F4 A4 F4 D4 F4 A4 F4 D4 F4 A4 F4', 'E4 G#4 B4 G#4 E4 G#4 B4 G#4 E4 G#4 B4 G#4 E4 G#4 B4 D5')] },
  drums: { inst: { ...INS.drums, min: .45 }, pat: [B('k . h . s . h . k . h . s . h h', 'k . h . s . h . k . h . s . s s')] },
} });
// Фарфоровая кукла: вальс шкатулки 3/4, при опасности — сердцебиение
MUS.def('inm_doll', { bpm: 84, steps: 12, ch: {
  box: { inst: { ...INS.bell, vol: .08, echo: [.3, .35] }, pat: [B('D5 - - - F5 - A5 - - - . .', 'G5 - - - F5 - E5 - - - . .', 'F5 - - - E5 - D5 - - - C#5 -', 'D5 - - - - - . . A4 - . .')] },
  waltz: { inst: { ...INS.thin, vol: .03 }, pat: [B('D3 - - - A3 - F3 - A3 - F3 -', 'C3 - - - G3 - E3 - G3 - E3 -', 'Bb2 - - - F3 - D3 - A2 - E3 -', 'D3 - - - A3 - F3 - A3 - . .')] },
  heart: { inst: { ...INS.drums, vol: .4, min: .5 }, pat: [B('k . k . . . . . . . . .')] },
  creep: { inst: { ...INS.saw, vol: .03, min: .8 }, pat: [B('D4 - - - - - - - - - - -', 'D#4 - - - - - - - - - - -')] },
} });
// I Feel Fantastic: робо-арпеджио, «фантастически» бодрая и неправильная
MUS.def('inm_tara', { bpm: 112, ch: {
  arp: { inst: { ...INS.thin, vol: .05 }, pat: [B('E4 B4 E5 G5 E4 B4 E5 G5 E4 B4 E5 G5 E4 B4 E5 G5', 'C4 G4 C5 E5 C4 G4 C5 E5 C4 G4 C5 E5 C4 G4 C5 E5', 'D4 A4 D5 F#5 D4 A4 D5 F#5 D4 A4 D5 F#5 D4 A4 D5 F#5', 'B3 F#4 B4 D#5 B3 F#4 B4 D#5 B3 F#4 B4 D#5 B3 F#4 B4 A4')] },
  voice: { inst: { ...INS.lead, wave: 'square', vol: .05, vib: [7, .3, .05] }, pat: [B('G5 - - - F#5 - - - E5 - - - . . . .', 'E5 - - - G5 - - - C6 - - - . . . .', 'A5 - - - F#5 - - - D5 - - - . . . .', 'B5 - - - - - - - . . . . . . . .')] },
  bass: { inst: INS.bass, pat: [B('E2 . E2 . E3 . E2 . E2 . E2 . E3 . E2 .', 'C2 . C2 . C3 . C2 . C2 . C2 . C3 . C2 .', 'D2 . D2 . D3 . D2 . D2 . D2 . D3 . D2 .', 'B1 . B1 . B2 . B1 . B1 . B1 . B2 . A1 .')] },
  drums: { inst: { ...INS.drums, min: .5 }, pat: [B('k . h k s . h . k . h k s . h s')] },
} });
// Телеведущий: заставка новостей, которая «съехала»
MUS.def('inm_broadcaster', { bpm: 120, ch: {
  jingle: { inst: { ...INS.saw, vol: .05 }, pat: [B('C5 - - - G4 - - - C5 - E5 - D5 - - -', 'C5 - - - G4 - - - C#5 - F5 - D#5 - - -', 'D5 - - - A4 - - - D5 - F#5 - E5 - - -', 'C5 - B4 - A#4 - A4 - G#4 - - - . . . .')] },
  bass: { inst: INS.bass, pat: [B('C2 . . C2 . . C2 . C2 . . C2 . . G1 .', 'C#2 . . C#2 . . C#2 . C#2 . . C#2 . . G#1 .', 'D2 . . D2 . . D2 . D2 . . D2 . . A1 .', 'C2 . . B1 . . A#1 . A1 . . G#1 . . G1 .')] },
  stat: { inst: { wave: 'noise', vol: .03, a: .01, d: .1, s: .4, r: .05 }, pat: [B('C7 . . . . . C7 . . . . . C7 . . .')] },
  drums: { inst: { ...INS.drums, min: .4 }, pat: [B('k . . k s . . . k . k . s . h h')] },
} });
