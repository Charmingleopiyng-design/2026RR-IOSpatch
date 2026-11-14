# RecNetRedirect.framework — iOS framework project

This is a native Objective-C framework **source project** intended to be embedded in a
Rec Room IPA. It is not a precompiled `.framework` binary and has not been tested in
Rec Room or on a device.

## What it currently implements

- Loads as a framework and runs its constructor when the framework is loaded.
- Reads `Data/RecNetRedirect.json` from the main app bundle.
- Intercepts selected `NSURLSession` request-creation methods.
- Rewrites only the exact HTTPS hostname `ns.rec.net` to `ns.recflare.net`.
- Preserves the URL path, query, fragment, and port.
- Does not disable TLS or certificate/hostname verification.
- Writes diagnostic messages to the device unified log.

## Important coverage limitation

This first framework prototype covers requests routed through the hooked
`NSURLSession` APIs. UnityWebRequest/BestHTTP may use Unity's native libcurl or another
transport and therefore may bypass these hooks. This is **not yet proof** that Rec Room's
nameserver requests are intercepted. The actual iOS app executable and runtime behavior
must be inspected before claiming a working redirect.

## Build

Requires macOS with Xcode and the iOS SDK.

1. Open `RecNetRedirect.xcodeproj`.
2. Select the `RecNetRedirect` scheme.
3. Set the deployment target to match the target app.
4. Build for an iOS device (arm64).
5. Embed the resulting `RecNetRedirect.framework` in `RecRoom.app/Frameworks/`.
6. Add the framework load command to the app executable and sign the complete app with
   Sideloadly after packaging.

A framework placed in `Frameworks/` is not automatically loaded merely by existing there.
The app executable must load it, and iOS code signing must remain valid.

## Configuration

Place this file at `RecRoom.app/Data/RecNetRedirect.json`:

```json
{
  "enabled": true,
  "sourceHost": "ns.rec.net",
  "destinationHost": "ns.recflare.net",
  "httpsOnly": true,
  "preservePathAndQuery": true,
  "tlsVerification": "system-default"
}
```

The implementation deliberately hard-codes the permitted host pair as a safety guard;
configuration cannot redirect arbitrary hosts.
