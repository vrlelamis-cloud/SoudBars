"""Ajoute la permission micro, le nom de l'app et le minSdk requis par `record`."""
import pathlib
import re

manifest = pathlib.Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text()
if "RECORD_AUDIO" not in text:
    text = text.replace(
        "<application",
        '<uses-permission android:name="android.permission.RECORD_AUDIO"/>\n    <application',
        1,
    )
text = re.sub(r'android:label="[^"]*"', 'android:label="SoundBars"', text, count=1)
manifest.write_text(text)

for name in ("build.gradle.kts", "build.gradle"):
    gradle = pathlib.Path("android/app") / name
    if gradle.exists():
        gradle.write_text(
            gradle.read_text().replace("flutter.minSdkVersion", "23")
        )
print("Android configuré.")
