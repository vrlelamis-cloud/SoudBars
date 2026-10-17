/// Fréquence d'échantillonnage de tous les enregistrements (mono, 16 bits).
const int kSampleRate = 44100;

/// Nombre de barres, comme sur l'image d'origine.
const int kBarCount = 14;

/// Forme des barres au repos (hauteur relative, mesurée sur l'image fournie).
const List<double> kRestShape = [
  0.31, 0.71, 0.58, 0.31, 1.0, 0.62, 0.49,
  0.31, 0.49, 0.62, 1.0, 0.58, 0.31, 0.31,
];
