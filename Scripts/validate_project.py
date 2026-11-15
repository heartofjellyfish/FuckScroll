#!/usr/bin/env python3
"""Check install-critical extension metadata, shared entitlements and resources."""
from pathlib import Path
import plistlib, json
root = Path(__file__).resolve().parents[1]
points = {
    'ActivityMonitor': 'com.apple.deviceactivity.monitor-extension',
    'ShieldConfiguration': 'com.apple.ManagedSettingsUI.shield-configuration-service',
    'ShieldAction': 'com.apple.ManagedSettings.shield-action-service',
}
for name in ['ScrollStopper', *points]:
    ent = plistlib.loads((root / f'Config/{name}.entitlements').read_bytes())
    assert ent['com.apple.developer.family-controls'] is True, name
    assert ent['com.apple.security.application-groups'] == ['group.com.heartofjellyfish.scrollstopper'], name
    info = plistlib.loads((root / f'Config/{name}-Info.plist').read_bytes())
    if name in points:
        assert info['NSExtension']['NSExtensionPointIdentifier'] == points[name], name
        assert info['NSExtension']['NSExtensionPrincipalClass'] == f'$(PRODUCT_MODULE_NAME).{name}', name
for metadata in (root / 'ScrollStopper/Resources/Assets.xcassets').glob('*/Contents.json'):
    for image in json.loads(metadata.read_text()).get('images', []):
        if 'filename' in image: assert (metadata.parent / image['filename']).exists(), image
privacy = plistlib.loads((root / 'ScrollStopper/Resources/PrivacyInfo.xcprivacy').read_bytes())
assert privacy['NSPrivacyTracking'] is False
assert privacy['NSPrivacyCollectedDataTypes'] == []
print('PASS: extension metadata, shared entitlements, assets and privacy manifest')
