# CrossGuard

CrossGuard is a pedestrian safety app I made for the Congressional App Challenge. It warns kids when they get close to dangerous spots on the street, like places where people cross in the middle of the road.

## How it works

A parent enters a PIN to unlock "parent mode." In parent mode, they can add zones on the map by tapping a spot or using their current location, then pick a size and give it a name.

When the kid gets within 50 meters of a zone, the app sends a notification and says a warning out loud. If they walk into the zone, they get another notification, a voice warning, and a vibration.

The app keeps checking your location in the background, and everything is saved only on the phone. There are no accounts and nothing gets sent to a server.

## Features

- Opens in child mode by default, so kids can't change the zones
- Parent mode locks itself after 2 minutes of no activity
- PIN is saved in the phone's encrypted storage, and you get locked out for 30 seconds after 5 wrong tries
- Works on both Android and iOS
- Light and dark mode

## How to run it

1. Run `flutter pub get`
2. Add your own Google Maps API key in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/AppDelegate.swift` (otherwise the map is just a gray screen)
3. Run `flutter run` with an emulator or a real phone plugged in
4. To run the tests, use `flutter test`

## What's in each folder

- `lib/zones/` - the map screen and saving/loading zones
- `lib/geofence/` - the code that checks if you're near a zone
- `lib/alerts/` - notifications, voice warnings, and vibration
- `lib/auth/` - the parent PIN and parent mode
- `test/` - tests for the zone logic and the PIN

## Things I want to add later

- Zones that can be any shape, not just circles
- Letting parents get a notification when their kid enters a zone
- Letting families in the same neighborhood share zones

## Known problems

- If you force quit the app, it stops checking your location
- You need to allow location "Always" for alerts to work in the background
