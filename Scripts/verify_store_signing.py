#!/usr/bin/env python3
"""Verify Family Controls in the final App Store IPA before uploading it."""

import argparse
from pathlib import Path
import plistlib
import subprocess
from tempfile import TemporaryDirectory


TEAM = "47C4WT5UPR"
APP_ID = "com.heartofjellyfish.scrollstopper"
GROUP = "group." + APP_ID
FAMILY_CONTROLS = "com.apple.developer.family-controls"
BUNDLE_IDS = {APP_ID, *(f"{APP_ID}.{name}" for name in ("monitor", "shield", "action"))}


def run(*args):
    result = subprocess.run(args, capture_output=True)
    if result.returncode:
        raise ValueError(result.stderr.decode(errors="replace").strip())
    return result


def verify(app):
    bundles = [app, *sorted((app / "PlugIns").glob("*.appex"))]
    observed = []
    issues = []
    for bundle in bundles:
        info = plistlib.loads((bundle / "Info.plist").read_bytes())
        bundle_id = info["CFBundleIdentifier"]
        observed.append(bundle_id)
        try:
            signature = plistlib.loads(run("codesign", "-d", "--xml", "--entitlements", "-", str(bundle)).stdout)
            profile = plistlib.loads(run("security", "cms", "-D", "-i", str(bundle / "embedded.mobileprovision")).stdout)
            for source, entitlements in (("signature", signature), ("profile", profile["Entitlements"])):
                if entitlements.get(FAMILY_CONTROLS) is not True:
                    issues.append(f"{bundle_id}: {source} lacks Family Controls")
                if entitlements.get("application-identifier") != f"{TEAM}.{bundle_id}":
                    issues.append(f"{bundle_id}: {source} has the wrong application identifier")
                if GROUP not in entitlements.get("com.apple.security.application-groups", []):
                    issues.append(f"{bundle_id}: {source} lacks the shared App Group")
            if (signature.get("get-task-allow") or profile["Entitlements"].get("get-task-allow")
                    or "ProvisionedDevices" in profile or profile.get("ProvisionsAllDevices")):
                issues.append(f"{bundle_id}: the signature or profile is not for App Store distribution")
        except (ValueError, plistlib.InvalidFileException, KeyError) as error:
            issues.append(f"{bundle_id}: could not inspect signature and profile ({error})")

    if len(observed) != len(BUNDLE_IDS) or set(observed) != BUNDLE_IDS:
        issues.append(f"Expected the main app and three Screen Time extensions. Found {observed}.")
    if issues:
        raise ValueError("\n".join(issues))
    run("codesign", "--verify", "--deep", "--strict", str(app))
    for bundle_id in observed:
        print(f"OK {bundle_id}: Family Controls in distribution signature and profile")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path, help="Exported App Store IPA or its unpacked .app")
    package = parser.parse_args().package.resolve()
    try:
        if package.suffix == ".app":
            verify(package)
        elif package.suffix == ".ipa":
            with TemporaryDirectory() as directory:
                run("ditto", "-x", "-k", str(package), directory)
                apps = list((Path(directory) / "Payload").glob("*.app"))
                if len(apps) != 1:
                    raise ValueError("Expected one application in the IPA payload")
                verify(apps[0])
        else:
            raise ValueError("Expected an exported .ipa or .app")
    except (ValueError, OSError, plistlib.InvalidFileException, KeyError) as error:
        parser.exit(1, f"Signing verification failed:\n{error}\n")


if __name__ == "__main__":
    main()
