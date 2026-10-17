# SoundBars

Enregistreur audio : les 14 barres blanches sont le seul bouton de l'app.
Touche les barres → enregistrement, les barres suivent le son (FFT en temps réel).
Touche encore → arrêt et sauvegarde (WAV 44,1 kHz mono).

## Compiler l'APK (depuis le téléphone)
1. Crée un dépôt GitHub vide, envoie tout le contenu de ce dossier à la racine
   (y compris `.github/workflows/build.yml`).
2. Onglet **Actions** → « Build APK » → s'il ne démarre pas seul : **Run workflow**.
3. Quand il est vert, ouvre l'exécution → **Artifacts** → `SoundBars-apk`.
4. Décompresse, installe `app-release.apk`, accepte l'accès au micro.

## En cas d'erreur
Copie le journal rouge de l'étape qui échoue et envoie-le moi : je te renvoie
uniquement les fichiers corrigés.

## Limites connues
- Si l'app passe en arrière-plan (ou écran éteint), l'enregistrement est arrêté
  et sauvegardé automatiquement (Android coupe le micro).
- Un enregistrement fait ~5 Mo par minute (WAV non compressé).
