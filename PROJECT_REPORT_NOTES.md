# QuickDeliver Project Report Notes

## Frameworks and Libraries

- Flutter
- Material 3
- Riverpod
- go_router
- Google Fonts
- Firebase package scaffolding
- Geolocation, maps, camera, phone, and notification package scaffolding

## Backend Choice

Firebase is the intended backend architecture for this project because it supports authentication, Firestore, storage, notifications, and server-side functions in a student-friendly stack. The current implementation keeps a robust mock/demo mode so the project remains easy to present before full backend setup.

## Security Approach

- Role-aware user model
- Repository boundaries for future backend enforcement
- Firestore rules scaffolded for role and ownership checks
- Storage rules scaffolded for product and proof image uploads
- Cloud Functions skeleton added for protected operations such as status updates and notification dispatch

## Modules Implemented

- Authentication and role selection
- Customer discovery, cart, checkout, order history, order detail, and tracking scaffold
- Business owner profile, product management, order management, and rider assignment
- Rider dispatch, assigned deliveries, delivery detail, proof capture, and history
- Shared mock delivery hub so all roles interact with the same live in-memory data

## Local and Mobile Features Used

- GPS/geolocation scaffold and mock nearby sorting
- Camera flow for proof and product images with safe fallback
- Phone call integration via `tel:` service
- Notification service scaffolding with local notification hooks
- Splash screen
- Offline/demo-first behavior
- Mock live rider location updates and tracking scaffold

## Key Design Decisions

- Preserve the existing Phase 1 and Phase 2 work instead of rebuilding
- Use a shared demo hub so customer, owner, and rider flows stay coherent
- Keep emulator-friendly fallbacks for camera, maps, and backend features
- Separate architecture into app/core/features/shared for maintainability
- Add Firebase-ready repository interfaces before full backend hookup

## Mock and Demo Strategy

- Seeded businesses, products, orders, users, rider locations, and notifications
- Demo users for each role
- Local order creation and lifecycle updates without backend dependency
- Proof image capture falls back to a mock-safe path if device camera is unavailable
- Tracking remains functional as a scaffold even without Maps keys
