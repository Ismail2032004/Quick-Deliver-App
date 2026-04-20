# QuickDeliver

QuickDeliver is a Riverpod-based Flutter delivery app with three production-oriented workspaces:

- `customer`: discover businesses, place orders, and track deliveries
- `owner`: manage a storefront, products, order flow, and rider assignment
- `rider`: accept deliveries, upload proof, and share live location updates

The primary backend path now runs through Supabase Auth, Postgres, Realtime, Storage, deep-link password recovery, email-confirmation callbacks, optional push notifications, and OpenStreetMap-compatible delivery tracking.

## Architecture

- `lib/app`: app shell and router bootstrap
- `lib/core`: config, repositories, shared providers, services
- `lib/features/auth`: auth, onboarding, password reset, profile
- `lib/features/customer`: browsing, cart, checkout, tracking
- `lib/features/business_owner`: business profile, inventory, order operations
- `lib/features/rider`: rider workflow, proof capture, live tracking
- `lib/features/operations`: shared delivery hub and tracking providers
- `supabase/migrations`: schema and RLS policies
- `supabase/functions/send-push-notification`: optional edge-function push delivery

## Implemented

- Supabase email/password auth with persisted sessions and production-style email confirmation support
- Forgot-password email dispatch plus deep-link recovery handling for `quickdeliver://reset-password`
- Email-verification callback handling for `quickdeliver://auth-callback`
- Reset-password routing that works for signed-in users and valid recovery sessions
- Supabase-backed businesses, products, orders, rider locations, and notification history
- Realtime order, notification, and rider-location updates
- Device-token registration in Supabase through `push_devices`
- Foreground/local notification display, remote push tap routing, and optional Supabase edge-function push dispatch
- Stronger rider live tracking with throttling, persistent recovery, Android native foreground-service tracking, and single-session protection
- OpenStreetMap tile rendering through `flutter_map` on the existing customer/rider tracking screens
- OSRM-compatible routed polylines when available, with direct-line fallback when not
- Delivery proof uploads and tracking maps preserved in the existing UI structure
- Persistent in-app settings for dark mode, readable text mode, reduced motion, high contrast, push toggles, and notification sound/vibration preferences
- Polished account menus with role-aware account center, saved addresses, payment-method scaffolding, and settings access across customer, owner, and rider workspaces
- Approved-role workspace switching with owner/rider application states instead of open-ended role swapping
- Post-order destination edits before pickup only, plus delivery-proof review before final delivery closeout

## Required Dart Defines

Required:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Optional:

- `QUICKDELIVER_DEMO_MODE=true`
- `OSM_TILE_URL_TEMPLATE=https://tile.openstreetmap.org/{z}/{x}/{y}.png`
- `OSM_TILE_ATTRIBUTION=OpenStreetMap contributors`
- `OSRM_ROUTE_BASE_URL=https://router.project-osrm.org`
- `SUPABASE_PUSH_FUNCTION_NAME=send-push-notification`

Example:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=OSM_TILE_URL_TEMPLATE=https://tile.openstreetmap.org/{z}/{x}/{y}.png \
  --dart-define=OSRM_ROUTE_BASE_URL=https://router.project-osrm.org \
  --dart-define=SUPABASE_PUSH_FUNCTION_NAME=send-push-notification
```

Or:

```bash
flutter run --dart-define-from-file=dart_defines.example.json
```

## Native Setup Summary

Android:

- add `google-services.json` if you want FCM push delivery
- keep both `quickdeliver://auth-callback` and `quickdeliver://reset-password` deep links mapped to the main activity
- ensure notification and location permissions are granted on the test device
- for stronger rider tracking on Android, allow background location, allow notifications, and keep the ongoing tracking notification enabled during active deliveries

iOS:

- add `GoogleService-Info.plist` if you want FCM push delivery
- keep the `quickdeliver` URL scheme enabled for both email confirmation and password reset recovery
- enable Push Notifications and Background Modes > Remote notifications if you want production-like push behavior
- ensure location permission is granted on the test device

Detailed platform and Supabase steps live in [SUPABASE_SETUP.md](/c:/Users/liams/Documents/projects/quickdeliver/SUPABASE_SETUP.md).

## Auth Flow

What now works:

- signup no longer assumes Supabase will return an authenticated session immediately
- when confirm-email is enabled, account creation succeeds and the app stays in a clear "check your email" state
- the app can resend verification emails from the auth UI
- opening `quickdeliver://auth-callback` on the device exchanges the verification link into a Supabase session
- the first verified session now creates the profile row lazily if it does not exist yet
- users who try to log in before confirming their email see a friendlier message instead of a generic auth failure

What still depends on manual setup:

- enabling email confirmation in Supabase Auth
- adding both `quickdeliver://auth-callback` and `quickdeliver://reset-password` to Supabase Auth redirect URLs
- Android/iOS deep-link registration in your local project
- optional universal links / Android app links if you want production-grade web-domain redirects instead of only the custom scheme

## Password Reset Flow

What now works:

- forgot-password emails still use Supabase Auth
- the redirect target stays `quickdeliver://reset-password`
- the app listens for the incoming deep link and exchanges the recovery URL into a Supabase session
- `/reset-password` is allowed for signed-in users and for valid recovery context
- invalid direct visits fall back cleanly instead of silently behaving like a normal logged-in route

What still depends on manual setup:

- Android/iOS deep-link registration in your local project
- adding `quickdeliver://reset-password` to Supabase Auth redirect URLs
- optional universal links/app links if you want production-grade web-domain redirects instead of only the custom scheme

## Push Notifications

What now works:

- `notifications` remains the source of in-app history
- `push_devices` stores per-device FCM tokens in Supabase
- local notifications still cover foreground UX
- FCM tap handling can route customers to order detail and riders to delivery detail
- the delivery hub now attempts push dispatch for:
  - order placed
  - order confirmed
  - rider assigned
  - picked up
  - delivering
  - delivered
- push dispatch is best-effort through `supabase/functions/send-push-notification`

What still depends on manual setup:

- Firebase config files on Android/iOS
- FCM credentials for the Supabase edge function
- deploying the edge function and setting its secrets

If push is not configured, the app still keeps:

- in-app notification history
- foreground/local notification UX
- no-crash push registration fallback

## Maps And Routing

What now works:

- customer, rider, and rider detail screens now render with `flutter_map` on OpenStreetMap-compatible tiles
- business, customer/drop-off, and rider markers remain visible in the existing tracking UI
- the app tries OSRM-compatible road routing first, with timeout, retry, and lightweight cache reuse for repeated route legs
- rider route segments now switch more cleanly between rider to pickup and rider to drop-off
- route fetch failures now fall back intentionally to direct lines instead of leaving the UI without a line
- OpenStreetMap attribution is shown directly in the map UI

What you still need:

- run `flutter pub get` locally after pulling these changes
- keep a tile source configured; the default OpenStreetMap tile server is suitable for light development/testing only
- switch `OSM_TILE_URL_TEMPLATE`, `OSM_TILE_ATTRIBUTION`, and optionally `OSRM_ROUTE_BASE_URL` to your own provider before production or heavier usage

## Role Access And Approval

What now works:

- every account always starts with customer access
- owner and rider workspaces are treated as approved roles, not casual mode switches
- role selection now shows only approved workspaces plus owner/rider application states
- owner and rider applications are stored on the profile with realistic pending/approved/rejected/suspended states
- if only one role is approved, the app no longer pushes a silly role-switch flow at sign-in

What still depends on your product process:

- there is no admin review dashboard in this pass
- approval and rejection are data-model ready, but manual database updates or internal tooling are still needed to review applications

## Settings And Account UX

What now works:

- every workspace can open a proper Settings screen with a back button
- settings persist locally on-device
- customer account center includes saved addresses and payment-method scaffolding
- owner and rider account centers include support contact actions and role-aware summaries
- avatar actions are now routed through a polished account sheet with profile, settings, workspace switching, and logout confirmation

## Delivery Proof And Destination Rules

What now works:

- customers can update the delivery destination only before rider pickup
- once pickup starts, the order destination is locked and the UI says so clearly
- rider delivery proof now moves the order into a `delivered_pending_proof_review` state
- business owners can review the proof image and confirm the final delivery closeout

What still depends on current scope:

- customer payment methods remain scaffolded placeholders, not live payment rails
- destination edits still happen from the order detail flow, not from a separate customer support workflow

## Rider Tracking

What now works:

- riders can start a live-tracking session from an active delivery
- only valid active deliveries can publish live location
- duplicate streams are prevented by a single tracking service
- updates are throttled to avoid noisy Supabase writes
- active tracking sessions are persisted and can auto-resume after the app is reopened
- on Android, an ongoing notification is shown and a native foreground service now publishes rider locations to the same Supabase `rider_locations` flow
- riders can still send a one-time live update manually

What is not implemented in this pass:

- guaranteed always-on tracking after the app or service is force-stopped by the user or the OEM
- iOS native always-on background delivery tracking

## QA Checklist

1. Register a new customer account.
2. Confirm the account from the verification email on the same device.
3. Log out and log back in.
4. Update profile name and phone number.
5. Create or edit a business profile as an owner.
6. Add and edit products.
7. Place a checkout order as a customer.
8. Confirm, prepare, and mark the order ready as the owner.
9. Assign a rider.
10. Accept the delivery as the rider.
11. Start live tracking and confirm customer tracking updates appear.
12. Upload pickup proof.
13. Move the order to `delivering`.
14. Upload delivery proof or finish the delivery flow.
15. Confirm the business can review proof and close the delivery.
16. Open the in-app notification center and verify linked order routing.
17. Test a push notification if Firebase + edge-function config is present.
18. Trigger forgot password, open the reset email on the same device, and confirm the app opens the reset-password flow.
19. Reset the password, then sign back in with the new password.

## Known Limitations

- Push delivery is environment-dependent until Firebase config files, FCM credentials, and the Supabase edge function are fully deployed.
- Road routing falls back to direct lines when the configured OSRM-compatible router is unavailable or rate-limited.
- Rider tracking is robust in the foreground, but not full native background tracking.
- Owner push taps currently fall back to the owner dashboard because there is no dedicated owner order-detail route yet.
- Owner/rider application review still needs either direct Supabase updates or a future admin tool.
- Payment methods are still UX/data scaffolding only and do not charge real cards or wallets.
- Universal links / Android app links are not fully production-ready until you bind a real domain and host the association files.
