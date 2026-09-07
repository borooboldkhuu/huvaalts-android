"""Align generated Android scaffolding with flutter_secure_storage 11."""
from pathlib import Path

app = Path('android/app/build.gradle.kts')
source = app.read_text()
expected = 'compileSdk = flutter.compileSdkVersion'
if expected not in source:
    raise SystemExit('Unexpected Flutter Android template: compileSdk not found')
app.write_text(source.replace(expected, 'compileSdk = 37'))

settings = Path('android/settings.gradle.kts')
source = settings.read_text()
expected = 'id("com.android.application") version "9.1.0"'
if expected not in source:
    raise SystemExit('Unexpected Flutter Android template: AGP version not found')
settings.write_text(source.replace(expected, 'id("com.android.application") version "9.1.1"'))
