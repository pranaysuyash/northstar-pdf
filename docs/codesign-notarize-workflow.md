# Codesign + Notarize Workflow

**Gate:** RG-122
**Status:** DRAFT — requires Apple Developer account ($99/year) and credentials
**Created:** 2026-08-26
**Prerequisite:** Apple Developer account with App Store Connect access

## Purpose

This document defines the workflow for codesigning, notarizing, and stapling
the PDF Editor app binary before any distribution claim. The app must carry a
valid signature chain from Apple's notary service before it can be distributed
to users.

## 1. Prerequisites

### Required accounts

| Account | Purpose | Cost |
|---|---|---|
| Apple Developer Program | Code signing identity | $99/year |
| App Store Connect | Notarization submission | Included |

### Required tools

| Tool | Version | Source |
|---|---|---|
| Xcode | 15.0+ | Mac App Store |
| `codesign` | Bundled with Xcode | `/usr/bin/codesign` |
| `notarytool` | Bundled with Xcode | `/usr/bin/xcrun notarytool` |
| `stapler` | Bundled with Xcode | `/usr/bin/xcrun stapler` |
| `create-dmg` | Latest | `brew install create-dmg` (optional) |

### Required credentials

| Credential | Storage | Access |
|---|---|---|
| Apple ID | Keychain or environment | Notarization submission |
| App-specific password | Keychain or `NOTARY_PASSWORD` env | Notarization authentication |
| Team ID | Xcode or `TEAM_ID` env | Signing identity |
| Signing certificate | Keychain | Code signing |

## 2. Signing identity setup

### First-time setup (one-time)

```bash
# 1. Generate a signing certificate in Apple Developer portal
#    - Go to https://developer.apple.com/account/resources/certificates
#    - Create a new "Mac App Distribution" certificate
#    - Download and install in Keychain Access

# 2. Verify the certificate is installed
security find-identity -v -p codesigning

# 3. Store credentials for CI
#    - Store Apple ID in Keychain:
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "your-app-specific-password"
```

### Environment variables (for CI)

```bash
export APPLE_ID="your@email.com"
export TEAM_ID="YOUR_TEAM_ID"
export NOTARY_PASSWORD="your-app-specific-password"
export SIGNING_IDENTITY="Developer ID Application: Your Name (YOUR_TEAM_ID)"
```

## 3. Build and sign workflow

### Step 1: Build the release binary

```bash
# Clean build
swift package clean

# Build release configuration
swift build -c release

# Or build the Xcode project
xcodebuild -scheme PDFEditorApp -configuration Release build
```

### Step 2: Create the app bundle

```bash
# The build output should already be a .app bundle
# If not, create one:
APP_NAME="PDFEditor"
BUILD_DIR=".build/release"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

# Verify the bundle exists
ls -la "$APP_BUNDLE"
```

### Step 3: Codesign the app

```bash
# Sign with hardened runtime (required for notarization)
codesign --force --deep --sign "$SIGNING_IDENTITY" \
  --options runtime \
  --timestamp \
  "$APP_BUNDLE"

# Verify the signature
codesign --verify --verbose "$APP_BUNDLE"

# Check the signing details
codesign -dvv "$APP_BUNDLE"
```

### Step 4: Create a DMG (optional, for distribution)

```bash
# Create a DMG for distribution
create-dmg \
  --volname "PDF Editor" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 175 190 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 425 190 \
  "PDFEditor.dmg" \
  "$APP_BUNDLE"

# Sign the DMG
codesign --force --sign "$SIGNING_IDENTITY" \
  --timestamp \
  "PDFEditor.dmg"
```

### Step 5: Submit for notarization

```bash
# Using notarytool (preferred for Xcode 13+)
xcrun notarytool submit "$APP_BUNDLE" \
  --keychain-profile "notarytool-profile" \
  --wait

# Or submit the DMG
xcrun notarytool submit "PDFEditor.dmg" \
  --keychain-profile "notarytool-profile" \
  --wait

# Check notarization status
xcrun notarytool info "$SUBMISSION_ID" \
  --keychain-profile "notarytool-profile"
```

### Step 6: Staple the notarization ticket

```bash
# Staple to the app bundle
xcrun stapler staple "$APP_BUNDLE"

# Or staple to the DMG
xcrun stapler staple "PDFEditor.dmg"

# Verify the staple
xcrun stapler validate "$APP_BUNDLE"
```

### Step 7: Verify the complete chain

```bash
# Full verification
spctl --assess --type execute "$APP_BUNDLE"

# Check the Gatekeeper assessment
spctl --assess --verbose "$APP_BUNDLE"

# Verify notarization ticket
xcrun stapler validate "$APP_BUNDLE"
```

## 4. CI/CD integration

### GitHub Actions workflow

```yaml
# .github/workflows/release.yml
name: Release Build + Notarize

on:
  push:
    tags:
      - 'v*'

jobs:
  build-and-notarize:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build release
        run: swift build -c release

      - name: Codesign
        env:
          SIGNING_IDENTITY: ${{ secrets.SIGNING_IDENTITY }}
        run: |
          codesign --force --deep --sign "$SIGNING_IDENTITY" \
            --options runtime \
            --timestamp \
            .build/release/PDFEditor.app

      - name: Notarize
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          TEAM_ID: ${{ secrets.TEAM_ID }}
          NOTARY_PASSWORD: ${{ secrets.NOTARY_PASSWORD }}
        run: |
          xcrun notarytool store-credentials "notarytool-profile" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --password "$NOTARY_PASSWORD"
          xcrun notarytool submit .build/release/PDFEditor.app \
            --keychain-profile "notarytool-profile" \
            --wait

      - name: Staple
        run: xcrun stapler staple .build/release/PDFEditor.app

      - name: Verify
        run: spctl --assess --type execute .build/release/PDFEditor.app

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: PDFEditor-notarized
          path: .build/release/PDFEditor.app
```

## 5. Verification checklist

| Check | Command | Expected |
|---|---|---|
| Code signature valid | `codesign --verify --verbose $APP_BUNDLE` | Valid signature |
| Hardened runtime | `codesign -dvv $APP_BUNDLE \| grep runtime` | `runtime` flag present |
| Timestamp present | `codesign -dvv $APP_BUNDLE \| grep Timestamp` | Timestamp present |
| Notarization ticket | `xcrun stapler validate $APP_BUNDLE` | Ticket validated |
| Gatekeeper pass | `spctl --assess --type execute $APP_BUNDLE` | Assessment passed |
| No unsigned code | `codesign -dvv $APP_BUNDLE \| grep -c "sealed resources"` | All resources sealed |

## 6. Troubleshooting

### Common issues

| Issue | Cause | Fix |
|---|---|---|
| "no identity found" | Certificate not in keychain | Install certificate in Keychain Access |
| "the signature is invalid" | Wrong signing identity | Check `security find-identity -v -p codesigning` |
| "notarization failed" | Missing hardened runtime | Add `--options runtime` to codesign |
| "stapler failed" | Notarization not complete | Wait for notarization to finish |
| "rejected by Gatekeeper" | Missing notarization | Submit for notarization first |

### Notarization rejection reasons

| Reason | Fix |
|---|---|
| Missing hardened runtime | Re-sign with `--options runtime` |
| Unsigned executable | Sign all binaries in the bundle |
| Missing entitlements | Add required entitlements |
| Malware detected | Scan for known issues |

## 7. Falsifiers

This gate is not PASS until:
1. `codesign --verify` exits 0 on the app bundle
2. `xcrun stapler validate` exits 0 on the app bundle
3. `spctl --assess --type execute` exits 0 on the app bundle
4. The notarization submission ID is recorded in evidence
5. The signing identity matches the Apple Developer account

## 8. Evidence

After implementation, evidence will be recorded in:
- `docs/release-gates.md` RG-122 entry
- `docs/audits/codesign-notarize-evidence-YYYY-MM-DD.md`
- CI workflow logs

---

**Status:** This is an implementation plan. The actual signing, notarization,
and stapling require an Apple Developer account and credentials that are not
available in this environment. This document serves as the runbook for when
those credentials become available.
