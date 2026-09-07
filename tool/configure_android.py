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

# A separate app id allows the demo to coexist with a production installation.
import sys
import xml.etree.ElementTree as ET
if '--demo' in sys.argv:
    source = app.read_text()
    source = source.replace('applicationId = "mn.huvaalts.huvalts"',
                            'applicationId = "mn.huvaalts.huvalts.demo"')
    app.write_text(source)
    android = 'http://schemas.android.com/apk/res/android'
    tools = 'http://schemas.android.com/tools'
    ET.register_namespace('android', android)
    ET.register_namespace('tools', tools)
    for manifest in Path('android/app/src').glob('*/AndroidManifest.xml'):
        tree = ET.parse(manifest)
        root = tree.getroot()
        for permission in list(root.findall('uses-permission')):
            if permission.get(f'{{{android}}}name') == 'android.permission.INTERNET':
                root.remove(permission)
        ET.SubElement(root, 'uses-permission', {
            f'{{{android}}}name': 'android.permission.INTERNET',
            f'{{{tools}}}node': 'remove',
        })
        application = root.find('application')
        if application is not None and manifest.parent.name == 'main':
            application.set(f'{{{android}}}label', 'ХУВААЛЦ Демо')
        tree.write(manifest, encoding='utf-8', xml_declaration=True)
