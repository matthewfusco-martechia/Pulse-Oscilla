# Pulse Oscilla iOS

This folder contains the SwiftUI client source for the iOS app. The code is organized as an app module with feature folders and a `Core` layer for transport, protocol models, and pairing security.

The next packaging step is to add these sources to an Xcode iOS application target with:

- deployment target: iOS 26
- Swift language mode: Swift 6
- Local Network privacy description in `Info.plist`
- camera permission if QR scanning is enabled with a live scanner

