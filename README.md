# NFC Review Writer

A Flutter app that writes a link (e.g. a Google Maps review link) to an NFC card.
Anyone who taps the card with their phone is prompted to open the link — no app needed to read it.

## Usage

1. Open the app and paste your review link (e.g. `https://g.page/r/XXXX/review`).
2. Tap **Write to Card** and hold the card near the top of your iPhone.

## Run on iPhone

1. `flutter pub get`
2. `open ios/Runner.xcworkspace`, then in **Signing & Capabilities** pick your Team, set a unique Bundle ID,
   and add the **Near Field Communication Tag Reading** capability.
3. `flutter run`

Requires an iPhone 7 or newer (writing needs iOS 13+). Also works on Android phones with NFC.
