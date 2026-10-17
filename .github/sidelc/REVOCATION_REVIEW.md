# Certificate revocation review — 2026-10-17

Reviewed LiveContainer `3b31a88e` and the pinned SideStore revision
`d21f40465ca53b996ad6fbc687edd29082037474`. This was a source/build review;
no certificates were revoked and no device crash was reproduced.

## Verified

- [LiveContainer build 38994756165](https://github.com/xw-yin/LiveContainer/actions/runs/38994756165)
  succeeded. Its log explicitly reports building SideStore revision `d21f4046…`.
- `resolveRevocation` no longer sets the private `titleTextColor` KVC key.
- Its action handlers no longer explicitly dismiss an alert that UIKit already
  dismisses, and the selection callback weakly captures its action.
- The settings certificate alert checks for `setContentViewController:` before
  setting `contentViewController`.

These confirm the previous patch is included. They do not establish the precise
cause of a device crash without its exception/backtrace.

## Remaining findings

1. **P1: the sign-in revocation dialog still uses private KVC.**
   In `SideStore/Handlers/SignInFlowHandler.swift`, `resolveRevocation` sets
   `contentViewController` unconditionally and updates the read-only action
   `title` using KVC. Removing `titleTextColor` does not remove the other private
   dependencies. An unsupported content key can still raise an Objective-C
   exception, which Swift `do/catch` does not catch. Replace this dialog with a
   public view controller containing the certificate list and explicit buttons;
   preserve the free/paid-account selection behavior and resume its continuation
   exactly once after dismissal.

2. **P1: unsupported custom alert content silently hides a destructive choice.**
   In `SideStore/Views/Settings/Advanced/Certificates/CertificatesView.swift`,
   `presentRevokeAlert` skips custom content when the private setter is absent,
   but still presents Revoke. The hidden `RevokeAlertViewController` defaults
   `isKeepLocalChecked` to `false`; the action still reads this value.
   `CertificatesViewModel.revokeCertificate` then deletes the local certificate
   and may clear the active certificate. A public sheet must always show the
   keep-local control, or offer explicit keep/delete actions when custom content
   cannot be shown. Hiding the choice is not a complete fallback.

3. **P2: free-account cancellation presents another alert during dismissal.**
   `resolveRevocation` calls `self.present(warningAlert)` inside the original
   Cancel handler. `activePresenter` can still refer to the original alert or a
   navigation controller presenting it. If UIKit rejects the new presentation
   during that transition, its OK handler cannot resume the continuation.
   Sequence this warning after the original presentation is fully dismissed;
   verify this separately from the original crash fix.

## Device validation still needed

- Free account: Revoke; Cancel → warning → OK.
- Paid account: no selection; one/multiple selections; Cancel.
- Settings: revoke with and without keeping the local copy, including the active
  certificate and a missing presenting view controller.
- Test both standalone SideStore and the embedded LiveContainer presentation.

This task changes LiveContainer's file deletion/management code. The SideStore
checkout and its pinned revision were left unchanged by this review.
