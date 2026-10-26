# Apple login identity and clone signing

The Apple login overlays apply after the existing host-memory overlays. They
adapt the Mac ADI approach from SideStore PR #1683 without importing its Windows
identity rewriting, changing the signing API, or replacing the signer dependency.

## Login

- A one-time migration selects remote Mac ADI, disables automatic rotation and
  discards the old ADI provisioning blob. It preserves the installation/device
  identifier, account, developer certificate and private key. Legacy identity
  overrides are cleared without deleting other Anisette configuration fields.
- A user can explicitly select on-device Anisette again after migration.
- Every remote server attempt fetches that server's client information. Old
  macOS 10.12 identities are upgraded to the modern Mac identity; Windows/Android
  metadata is rejected instead of being mixed with Mac provisioning.
- The persisted ADI blob and remote cache are scoped to the selected server and
  resolved identity. A fallback does not inherit the first server's metadata.
- GrandSlam and 2FA requests retain the negotiated client information and agent.
  HTTP 429/503 receive at most two retries with the original request. The request
  body, JSON content type and security-code header survive retries. Long or
  unrecognized Retry-After values stop retries, and HTTP 401/403 are not retried.
- SMS challenges use a JSON PUT with a numeric trusted-phone identifier. Existing
  pushed-code / hsc=409 handling is retained. Authentication failures do not
  revoke or rotate signing certificates.

## Certificate recovery and trust

Embedded SideStore must recover its signing P12 from the real LiveContainer
bundle, not the ad-hoc SideStore guest framework. The running host's certificate
is preferred when it is still listed on the portal and its private key can be
loaded. The active cached certificate is the next option. A P12 that decrypts
but has a different serial number is rejected.

Revoking a certificate and reinstalling with a newly issued one changes the
signing identity even when the Apple account stays the same. This fix does not
restore a revoked certificate or bypass system developer trust. Reuse applies
only to still-valid portal certificates with available private keys.

## LiveContainer2 startup

LiveContainerSwiftUI now links SideStoreSupport.framework. Clone export used to
delete this framework together with the embedded SideStore guest, leaving a
required dyld dependency missing. The plain LiveContainer IPA packaging also
removed this dependency. Both IPA variants and clone export now keep it while
still removing the guest app and its metadata. Recreate/reinstall a clone from
the updated primary app to get the corrected payload, retaining its bundle ID.

The clone dependency check inspects the actual archived Mach-O load commands
against the production clone removal policy. It also has a synthetic fixture
that reproduces and rejects the original deletion behavior.

## Verification

```sh
python3 .github/tests/run_apple_login_tests.py /path/to/patched/SideStore
python3 .github/tests/run_host_memory_tests.py /path/to/patched/SideStore
python3 .github/tests/verify_clone_runtime.py --self-test
```

The login tests compile extracted production policies, request builders and
retry code against fake responses. They use no Apple credentials and perform no
network authentication. CI additionally checks the real archived host's clone
dependencies and compiles both apps. Device testing is still needed for Apple
authentication, trust prompts, and the final LiveContainer2 launch.
