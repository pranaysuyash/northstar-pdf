# Error taxonomy and recovery contract

**Status:** canonical provider/UI contract
**Scope:** native macOS and web reader/editor lanes

Errors are user-visible states, not log-only details. Every failed operation must
leave the source bytes untouched, avoid publishing an unvalidated destination,
and provide a recovery action appropriate to the failure class.

## Stable classes

| Class | Native mapping | Web mapping | Recovery contract |
|---|---|---|---|
| Missing input | `inputMissing` | missing `File`/unavailable source | Choose another file; no session mutation |
| Input too large | `inputTooLarge` | size/page safety rejection | Reduce scope or use an approved larger-limit lane |
| Unopenable/corrupt | `cannotOpen` | PDF.js load failure | Preserve source; offer retry or diagnostic export |
| Password required | `passwordRequired` | `password-required` + password prompt | Prompt without persisting the password |
| Password incorrect | `passwordIncorrect` | `password-incorrect` | Retry with bounded attempts; never fall through as unlocked |
| Invalid page/operation | `invalidPage`, `invalidOperation` | `invalid-operation` with a contract code such as `staleSourceDigest`, `unsupportedOperation`, `destructiveOperation`, `unknownValidationState`, or `coordinateMismatch` | Remove or revise only the rejected operation; pdf-lib is not invoked |
| Provider/export failure | `exportFailed` | `export-failed` | Keep draft and source; retry to a new destination |
| Validation rejection | `exportFailed` with validation detail | output validation failure | Do not publish output; inspect report and use another provider |
| Runtime unavailable | provider runtime status | `runtime-unavailable` | Disable editing/export, keep reading/retry after runtime recovery |
| Unsupported feature | capability warning | `unsupported` | Explain the provider boundary; do not imply preservation |

## Export transaction invariant

Native export follows this order:

1. Read and fingerprint the source.
2. Apply operations in memory.
3. Write a uniquely named sibling staging file.
4. Reopen and validate the staging file against the source and operation contract.
5. Publish only when validation is not `failed`.
6. Replace an existing destination through the file-manager replacement path, or
   move a new destination into place.
7. Remove staging material on every failure path.

The source is never an export target. A failed validation must not leave a new
file at the requested destination, and must not delete an existing destination.

The browser has the same transaction boundary in memory. It hashes the current
source bytes and runs the operation, coordinate, and validation-state gate
before `PDFDocument.load()` is reached. A stale digest, unsupported operation,
destructive or non-reversible operation, unknown validation state, or coordinate
mismatch is retained in the edit session and shown as `invalid-operation`; no
pdf-lib export callback or browser download is allowed.

The native provider-local validator checks reopenability, page geometry and
rotation, field identity/geometry/choices, extracted text, and requested native
field/overlay retention. It does **not** prove PDF syntax validity, PDF/UA, visual
fidelity, signatures, XFA, or preservation of arbitrary objects. Independent
validator gates remain mandatory.

## Recovery and observability

The UI should retain the edit session and operation ledger after export failure,
show the failed class and provider message, and offer “retry as new copy” rather
than silently retrying over the source. Logs may include source/output digests and
provider identifiers, but must not include passwords or document contents.

See [release-gates.md](release-gates.md), [capability-matrix.md](capability-matrix.md),
and [runbooks/release-gates.md](runbooks/release-gates.md) for the evidence gates
that remain required before an unrestricted release claim.
