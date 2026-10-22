# Host memory setup

LiveContainer loads guests with `dlopen`. Memory entitlements belong to the
LiveContainer or LiveProcess task, not the guest image. Patching a guest's
signature cannot grant either process more memory.

The build applies `host-memory-sidestore.patch` and
`host-memory-sidesign.patch` after checking out the pinned SideStore and SideSign
revisions. Both patches are checked before either is applied; an incompatible
dependency update stops the build. These patches are maintained here so a
LiveContainer checkout contains the complete change.

## Device verification

1. Install the new LiveContainer+SideStore build with LiveProcess retained.
2. In LiveContainer's settings, open JIT-less diagnostics and copy the Memory
   Diagnostics report. It reads the running task using SecTask, not a guest's
   signature. Available memory is a changing estimate, not a configured limit.
3. In embedded SideStore, long-press an app and choose **Get More RAM for
   LiveContainer**, then **Request Permissions and Reinstall**. The action
   targets the actual installed host, keeps its bundle ID and LiveProcess, and
   uses the existing staged self-reinstall pipeline. It does not modify the
   running installation in place or delete app data.
4. The request requires `increased-memory-limit` and
   `extended-virtual-addressing` in the host and LiveProcess provisioning
   profiles, then verifies both signed binaries before sending the IPA for
   installation. A stripped binary key is restored only when the profile grants
   it. Debugging memory is not required. Missing permissions, missing LiveProcess,
   or an unidentified host stops the operation with an error.
5. Fully reopen LiveContainer and restart guest processes after installation.
   Copy the new diagnostics report. Compare runtime entitlements and measurements
   on the same device and launch mode. Every host/LiveProcess startup also logs
   a `[HostMemory]` report, including PID and physical footprint. A LiveContainer
   report does not prove that a separate LiveProcess has the same runtime grants.

There is no per-guest enabled checkmark. A signed file and a successful install
do not prove a higher effective runtime memory limit. Account/profile support
and device policy still determine the outcome; this change does not bypass them.

The preference `liveContainerHostMemoryRequested` keeps successful explicit
requests enforced on subsequent host signing and refresh. A failed first request
restores the previous preference, so ordinary refresh is not blocked. The same
dialog offers **Resume Ordinary Signing and Refresh** to stop requiring the
permissions for future operations without changing the currently installed app.

## Checks

After applying the patches to an initialized SideStore checkout:

```sh
bash .github/sidelc/verify_integration.sh /path/to/SideStore
python3 .github/tests/run_host_memory_tests.py /path/to/SideStore
```

The Swift tests compile the actual profile validator and signature restoration
guards with portable fixtures. They cover missing, false, and incorrectly typed
permissions, restoring stripped keys from authorized profiles, and restricting
extension propagation to LiveProcess. CI runs them before building SideStore.
An iOS build and device installation are still required to verify the complete
signing/install flow and the runtime effect.
