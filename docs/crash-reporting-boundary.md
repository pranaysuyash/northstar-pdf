# Crash-Reporting Boundary

**Gate:** RG-124
**Status:** DRAFT — requires product decision on telemetry scope
**Created:** 2026-08-26
**Prerequisite:** Privacy policy (RG-028) is PASS; this document defines the crash-reporting boundary within that policy

## Purpose

This document defines the boundary for crash telemetry in the PDF Editor.
Crash telemetry must be bounded by the privacy policy (RG-028); opt-in
consent is explicit; no raw PDF bytes or user content leak into crash reports.

## 1. Privacy boundary (RG-028 recap)

The privacy boundary is PASS:
- Document bytes and secrets remain local unless explicit consent authorizes transfer
- Network-egression assertion proves zero external HTTP requests during the full browser workflow cycle
- CSP policy prevents unauthorized external connections

Crash reporting must respect this boundary:
- No PDF content in crash reports
- No form field values in crash reports
- No file paths or filenames in crash reports
- No user content in crash reports

## 2. Telemetry options

| Option | Privacy | Cost | Effort | Notes |
|---|---|---|---|---|
| **No telemetry** (recommended) | Maximum | Free | Zero | Safest option; no external requests |
| Opt-in crash reports | High | Free | Low | User must explicitly consent |
| Local-only crash logs | Maximum | Free | Low | Crash logs stay on disk |
| Third-party crash reporter | Variable | Variable | Medium | PLCrashReporter, Sentry, etc. |

**Recommendation:** Start with **no telemetry**. The app is local-first and
privacy-first. Crash reports can be added later if users request them, but
the default must be zero external requests.

## 3. If opt-in crash reports are added

### Consent flow

```
1. App launches for the first time
2. Show "Help improve PDF Editor" dialog
3. Explain: "Crash reports help us fix bugs. They never contain your PDF content."
4. User chooses: "Send crash reports" or "Don't send"
5. Store preference in UserDefaults (not Keychain)
6. Never ask again unless preference is reset
```

### What crash reports may contain

| Data | Included | Reason |
|---|---|---|
| App version | ✅ | Identify affected version |
| macOS version | ✅ | Identify affected platform |
| Architecture | ✅ | ARM64 vs x86_64 |
| Crash stack trace | ✅ | Identify crash location |
| Exception type | ✅ | Classify crash severity |
| Memory pressure | ✅ | Detect OOM crashes |
| Disk space | ⚠️ | Only if relevant to crash |

### What crash reports must NOT contain

| Data | Excluded | Reason |
|---|---|---|
| PDF content | ❌ | Privacy boundary (RG-028) |
| Form field values | ❌ | User content |
| File paths | ❌ | May reveal document names |
| Filenames | ❌ | May reveal document content |
| User text input | ❌ | User content |
| Clipboard content | ❌ | User content |
| Network requests | ❌ | Privacy boundary |
| Encryption keys | ❌ | Security boundary |

### Technical implementation

```swift
// Example: PLCrashReporter configuration
import PLCrashReporter

let config = PLCrashReporterConfig.default()
config.shouldMachExceptionHandler = true
config.shouldUseLiveThreadReporter = false

let reporter = PLCrashReporter.shared()

// Before sending, sanitize the report
func sanitizeReport(_ report: PLCrashReport) -> PLCrashReport {
    // Remove any file paths
    // Remove any user content
    // Keep only: version, OS, arch, stack trace, exception
    return report
}
```

### Storage and transmission

| Stage | Storage | Retention |
|---|---|---|
| Crash occurs | Local disk (`~/Library/Logs/CrashReporter/`) | 7 days |
| User consents | App bundles report | Until next launch |
| Report sent | Server (if opt-in) | 90 days |
| Report deleted | After processing | Immediate |

## 4. Local-only crash logs (alternative)

If no external crash reporting is added, the app can still write local crash
logs for debugging:

```swift
// Write crash log to app sandbox
let logDirectory = FileManager.default.urls(
    for: .applicationSupportDirectory,
    in: .userDomainMask
).first!.appendingPathComponent("CrashLogs")

// Rotate logs (keep last 5)
// Compress old logs
// Never leave the sandbox
```

Users can manually submit crash logs if they choose:
- App shows "View Crash Logs" in Help menu
- User can copy the log and email it
- No automatic submission

## 5. Network boundary

| Request type | Allowed | Notes |
|---|---|---|
| Update check (Sparkle) | ✅ (opt-in) | Only if auto-update is enabled |
| Crash report submission | ✅ (opt-in) | Only if user consents |
| Telemetry | ❌ | Never allowed |
| Analytics | ❌ | Never allowed |
| Feature tracking | ❌ | Never allowed |
| A/B testing | ❌ | Never allowed |

## 6. Compliance

| Regulation | Requirement | Implementation |
|---|---|---|
| GDPR | Explicit consent for data collection | Opt-in dialog with clear explanation |
| CCPA | Right to delete | User can clear crash logs anytime |
| Apple Privacy | Privacy nutrition label | App Store listing must disclose |
| SOC 2 | Data handling policies | Not applicable (no data collection) |

## 7. Falsifiers

This gate is not PASS until:
1. No crash reports are sent without explicit user consent
2. No PDF content or user data appears in any crash report
3. No external requests occur during normal operation (RG-028)
4. Crash logs are stored locally only (if no external reporting)
5. User can view and delete crash logs at any time
6. Privacy policy (RG-028) is maintained

## 8. Evidence

After implementation, evidence will be recorded in:
- `docs/release-gates.md` RG-124 entry
- `docs/audits/crash-reporting-boundary-evidence-YYYY-MM-DD.md`
- Network-egression assertion results (RG-126)

---

**Status:** This is a boundary document. The actual crash reporting
implementation depends on the product decision: no telemetry (recommended),
opt-in crash reports, or local-only crash logs. This document defines the
boundary for whichever option is chosen.
