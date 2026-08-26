# Auto-Update Integration

**Gate:** RG-123
**Status:** DRAFT — requires product decision on update channel
**Created:** 2026-08-26
**Prerequisite:** Sparkle framework integration; Apple Developer account for signing

## Purpose

This document defines the auto-update mechanism for the PDF Editor app. The
update channel must deliver signed updates to users, support rollback, and
maintain version compatibility. The privacy boundary (RG-028) must be respected.

## 1. Update channel options

| Channel | Effort | Pros | Cons |
|---|---|---|---|
| **Sparkle** (recommended) | Low (1-2 days) | Open-source, well-established, native macOS | Requires hosting; no App Store |
| App Store | Medium | Built-in updates, Apple review | Requires Apple review; slower |
| Manual download | Zero | No integration needed | No automatic updates |

**Recommendation:** Sparkle framework. It's the pragmatic choice for a
non-App Store macOS app. Open-source (BSD license), well-tested, used by
thousands of macOS apps.

## 2. Sparkle framework integration

### Prerequisites

| Requirement | Purpose |
|---|---|
| Sparkle 2.x | Update framework |
| EdDSA signing keys | Update signature verification |
| HTTPS hosting | Update feed and binary hosting |
| Apple Developer account | Code signing for updates |

### Installation

```bash
# Via Swift Package Manager (recommended)
# Add to Package.swift dependencies:
.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0")

# Or via CocoaPods
pod 'Sparkle', '~> 2.5'
```

### Configuration

```swift
import Sparkle

// In AppDelegate or App init:
let updaterController = SPUStandardUpdaterController(
  startingUpdater: true,
  updaterDelegate: nil,
  userDriverDelegate: nil
)

// Configure the updater
updaterController.updater.feedURL = URL(string: "https://your-domain.com/appcast.xml")
updaterController.updater.automaticallyChecksForUpdates = true
updaterController.updater.updateCheckInterval = 86400 // 24 hours
```

### Appcast feed

The appcast XML feed must include:
- Version number
- Release notes
- Minimum system version
- EdDSA signature
- Binary download URL

```xml
<?xml version="1.0" standalone="no"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     version="2.0">
  <channel>
    <title>PDF Editor</title>
    <link>https://your-domain.com/appcast.xml</link>
    <item>
      <title>Version 1.0.1</title>
      <sparkle:version>1.0.1</sparkle:version>
      <sparkle:shortVersionString>1.0.1</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <description>Bug fixes and improvements</description>
      <pubDate>Mon, 26 Aug 2026 12:00:00 +0000</pubDate>
      <enclosure url="https://your-domain.com/releases/PDFEditor-1.0.1.zip"
                 type="application/octet-stream"
                 sparkle:edSignature="..." />
    </item>
  </channel>
</rss>
```

### Signing keys

```bash
# Generate EdDSA keys for update signing
generate_keys

# This creates:
# - dsa_pub.pem (public key, embedded in app)
# - dsa_priv.pem (private key, kept secure for signing)

# The public key must be embedded in the app binary
# The private key is used to sign updates before publishing
```

## 3. Update flow

```
1. App checks appcast feed (every 24 hours or on manual check)
2. Sparkle parses feed and compares versions
3. If update available: show release notes and "Install Update" button
4. User clicks "Install Update"
5. Sparkle downloads update ZIP in background
6. Sparkle verifies EdDSA signature
7. Sparkle quits the app
8. Sparkle replaces the app bundle
9. Sparkle relaunches the app
```

## 4. Rollback and compatibility

### Rollback strategy

| Scenario | Strategy |
|---|---|
| Update fails to install | Sparkle automatically reverts to previous version |
| Update causes crash | User can manually reinstall previous version |
| Update corrupts data | Recovery flow (RG-029) handles data recovery |

### Version compatibility

| Check | Implementation |
|---|---|
| Minimum system version | `sparkle:minimumSystemVersion` in appcast |
| Architecture compatibility | Separate appcast feeds for ARM64 and x86_64 |
| Database migration | App handles schema upgrades on launch |

### Delta updates

Sparkle supports delta updates (binary diff) to minimize download size:
- Full update: ~50 MB (full app bundle)
- Delta update: ~5 MB (binary diff)

## 5. Privacy compliance

| Requirement | Implementation |
|---|---|
| No tracking | Sparkle does not track users by default |
| No telemetry | Update checks are anonymous HTTP requests |
| Local-first | Update feed is the only external request |
| Consent | User must opt-in to automatic updates |
| CSP compliance | Update feed URL must be in CSP allowlist |

### CSP update

```html
<!-- Add to index.html CSP -->
<meta http-equiv="Content-Security-Policy"
      content="default-src 'self'; connect-src https://your-domain.com;">
```

## 6. Hosting requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| HTTPS | Required | Required |
| Bandwidth | 10 GB/month | 100 GB/month |
| Storage | 500 MB | 2 GB |
| CDN | Optional | Recommended |

### Hosting options

| Option | Cost | Pros |
|---|---|---|
| GitHub Releases | Free | Integrated with repo |
| AWS S3 + CloudFront | ~$10/month | Reliable, fast |
| Cloudflare R2 | ~$5/month | No egress fees |
| Self-hosted | Variable | Full control |

## 7. Implementation checklist

| Task | Effort | Status |
|---|---|---|
| Add Sparkle dependency | 1 hour | Not started |
| Generate EdDSA signing keys | 30 min | Not started |
| Configure updater in App | 2 hours | Not started |
| Create appcast feed | 2 hours | Not started |
| Set up hosting | 1 hour | Not started |
| Test update flow | 2 hours | Not started |
| Test rollback | 1 hour | Not started |
| Update CSP | 30 min | Not started |
| Document update policy | 1 hour | Not started |

**Total estimated effort:** 1-2 days

## 8. Falsifiers

This gate is not PASS until:
1. Sparkle updater is configured and checks for updates
2. Appcast feed is valid XML with EdDSA signatures
3. Update download, verification, and installation work end-to-end
4. Rollback works when update fails
5. No user tracking or telemetry occurs
6. CSP allows the update feed URL
7. Privacy boundary (RG-028) is maintained

## 9. Evidence

After implementation, evidence will be recorded in:
- `docs/release-gates.md` RG-123 entry
- `docs/audits/auto-update-evidence-YYYY-MM-DD.md`
- Update flow test results

---

**Status:** This is an implementation plan. The actual Sparkle integration
requires hosting setup and EdDSA key generation. This document serves as the
runbook for when those resources become available.
