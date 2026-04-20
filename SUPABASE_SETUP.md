# Supabase Setup

QuickDeliver expects Supabase Auth, Postgres, Realtime, Storage, and optional Edge Functions to be configured before the full production-like flow is available.

## 1. Dart Defines

Required:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Optional:

- `QUICKDELIVER_DEMO_MODE=true`
- `OSM_TILE_URL_TEMPLATE=https://tile.openstreetmap.org/{z}/{x}/{y}.png`
- `OSM_TILE_ATTRIBUTION=OpenStreetMap contributors`
- `OSRM_ROUTE_BASE_URL=https://router.project-osrm.org`
- `SUPABASE_PUSH_FUNCTION_NAME=send-push-notification`

The app reads these through `String.fromEnvironment`, so provide them with `--dart-define` or `--dart-define-from-file`.

## 2. Database Migrations

Apply these migrations in order:

1. `supabase/migrations/20260415_000001_quickdeliver_schema.sql`
2. `supabase/migrations/20260415_000002_push_devices.sql`
3. `supabase/migrations/20260415_000003_order_destination_snapshot.sql`
4. `supabase/migrations/20260416_000004_role_access_and_delivery_review.sql`

Primary tables in use:

- `profiles`
- `businesses`
- `products`
- `orders`
- `order_items`
- `deliveries`
- `rider_locations`
- `notifications`
- `push_devices`

## 3. Storage Buckets

Create or confirm these public buckets:

- `profile-avatars`
- `business-images`
- `product-images`
- `delivery-proofs`

Recommended bucket behavior:

- authenticated uploads only
- public read access for images rendered by the app
- tighter rider/owner write rules for proof assets if you want stricter production security

## 4. Auth Configuration

Enable:

- Email / Password provider
- Confirm email

Recommended:

- disable anonymous auth
- keep the site URL and redirect URLs aligned with your mobile deep links instead of localhost-style placeholders

Add these redirect URLs in Supabase Auth:

- `quickdeliver://auth-callback`
- `quickdeliver://reset-password`

If you later add production universal links or Android app links, also add those exact HTTPS callback URLs here.

What the app now expects in confirm-email mode:

- signup may create the account without returning an authenticated session
- the app shows a verification-pending state instead of treating that as a failure
- the verification email should return to `quickdeliver://auth-callback`
- the first verified session creates the `profiles` row lazily if it does not exist yet
- password reset still uses `quickdeliver://reset-password`

## 5. Auth Deep Link Setup

What the app expects:

- email verification links use `quickdeliver://auth-callback`
- forgot-password emails use `quickdeliver://reset-password`
- the app receives the link
- Supabase auth tokens from that link are exchanged into a session
- password recovery still opens the reset-password flow
- signup confirmation falls back into the standard authenticated app flow

Manual platform setup:

Android:

- keep the `VIEW` intent filter for both `quickdeliver://auth-callback` and `quickdeliver://reset-password`
- if you want verified Android App Links later, add a real HTTPS domain and host `assetlinks.json`

iOS:

- keep the `quickdeliver` URL scheme in `Info.plist`
- if you want universal links later, add Associated Domains and host `apple-app-site-association`

Fallback if deep linking is incomplete:

- signup can still create accounts
- password-reset emails still send
- email verification and logged-out password recovery require the incoming deep link to reach the app successfully

## 6. Password Reset Deep Link Setup

What the app expects:

- forgot-password emails use `quickdeliver://reset-password`
- the app receives the link
- Supabase recovery tokens from that link are exchanged into a recovery session
- the router allows `/reset-password` only for signed-in users or valid recovery context

Manual platform setup:

Android:

- keep the `VIEW` intent filter for `quickdeliver://reset-password`
- if you want verified Android App Links later, add a real HTTPS domain and host `assetlinks.json`

iOS:

- keep the `quickdeliver` URL scheme in `Info.plist`
- if you want universal links later, add Associated Domains and host `apple-app-site-association`

Fallback if deep linking is incomplete:

- reset emails still send
- the reset screen still works for signed-in password changes
- logged-out recovery requires the incoming deep link to reach the app successfully

## 7. Realtime

Enable Realtime for:

- `orders`
- `products`
- `businesses`
- `rider_locations`
- `notifications`

## 8. Push Notifications

### App-side behavior now implemented

- FCM token capture through `firebase_messaging`
- token persistence to `push_devices`
- local notification display for foreground delivery updates
- notification tap routing to customer/rider order screens when feasible
- best-effort push dispatch via a Supabase Edge Function

### Manual mobile setup

Android:

1. Add `google-services.json` to `android/app/`.
2. Install dependencies locally so `firebase_core` and `firebase_messaging` are available.
3. If your Android build requires it, apply the Google Services Gradle plugin in your local environment before testing push.
4. Grant notification permission on Android 13+.

iOS:

1. Add `GoogleService-Info.plist` to `ios/Runner/`.
2. Enable Push Notifications capability in Xcode.
3. Enable Background Modes and check `Remote notifications`.
4. Add/upload your APNs key or certificate in Firebase.
5. Grant notification permission on the device.

### Supabase Edge Function setup

Deploy:

- `supabase/functions/send-push-notification`

Set these function secrets:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `FCM_PROJECT_ID`
- `FCM_CLIENT_EMAIL`
- `FCM_PRIVATE_KEY`

The edge function uses those secrets to:

- read active device tokens from `push_devices`
- request an OAuth access token for FCM HTTP v1
- send push notifications to target devices
- deactivate invalid FCM tokens when FCM reports they are unregistered

Fallback when push is not configured:

- the app still stores in-app history in `notifications`
- local foreground notifications still work
- push registration and dispatch fail gracefully instead of crashing the app

## 9. Maps And Directions

QuickDeliver now renders maps with `flutter_map` on OpenStreetMap-compatible raster tiles, so no native Google Maps SDK setup is required for Android or iOS.

For routed polylines you can optionally keep an OSRM-compatible routing endpoint:

- default: `https://router.project-osrm.org`
- override locally or in production with `OSRM_ROUTE_BASE_URL`

Fallback behavior when directions are unavailable:

- the app first retries timed-out/failed requests once, then falls back to direct-line polylines
- lightweight route caching is used to avoid unnecessary repeated fetches when the rider has not moved meaningfully
- map screens stay usable
- no crash occurs if route fetch fails

Tile usage note:

- the default `tile.openstreetmap.org` server is fine for lightweight development/testing, not for heavy production use
- move to a dedicated tile provider and update `OSM_TILE_URL_TEMPLATE` plus `OSM_TILE_ATTRIBUTION` before broader deployment

## 10. Rider Tracking

Implemented in this pass:

- live tracking session start/stop
- persisted active-session recovery after app reopen
- duplicate-stream protection
- throttled location writes to Supabase
- stronger permission and device-service error messages
- Android ongoing tracking notification while a live delivery is active
- native Android foreground-service location tracking for active rider deliveries
- native Android writes still target the same `rider_locations` table and realtime flow
- one-time live update fallback

Not implemented in this pass:

- guaranteed tracking after the app/service is force-stopped by the user or heavily restricted by the OEM
- iOS always-on background delivery tracking

If you want true background delivery tracking later, you will need deeper native platform work and a different operational/privacy review.

Manual Android setup to verify locally:

1. Grant foreground location permission.
2. On Android 10+, allow background location if you want the strongest behavior available in this project.
3. On Android 13+, allow notifications so the ongoing live-tracking notification can stay visible.
4. Disable or relax battery optimization for the app on devices that aggressively limit background work.
5. Expect device and OEM battery-management rules to still affect long-running background reliability.

## 11. Seed Flow

`supabase/seed.sql` assumes sample auth users already exist for:

- `customer@quickdeliver.demo`
- `owner@quickdeliver.demo`
- `rider@quickdeliver.demo`

Recommended order:

1. Create the auth users in Supabase Auth.
2. Run the migrations.
3. Run `supabase/seed.sql`.
4. Sign in through the Flutter app.

## 12. Role Approval And Delivery Review Data

This pass adds:

- `profiles.approved_roles`
- `profiles.owner_application_status`
- `profiles.rider_application_status`
- `profiles.owner_application_data`
- `profiles.rider_application_data`
- `orders.status = delivered_pending_proof_review`
- `deliveries.status = delivered_pending_proof_review`

Practical meaning:

- every user still has customer access by default
- owner and rider access should only be treated as active when included in `approved_roles`
- role applications can remain pending until your internal review process approves them
- rider proof upload now stops one step before the final delivered state so the business can review and confirm

## 13. Final QA Pass

Use this final end-to-end checklist:

1. Register.
2. Confirm the account from the verification email on the same device.
3. Login.
4. Update profile.
5. Create or edit a business.
6. Add or edit a product.
7. Checkout an order.
8. Move owner statuses through confirmed, preparing, and ready.
9. Assign a rider.
10. Accept the job as the rider.
11. Start rider live tracking and verify customer tracking refreshes.
12. Upload pickup proof.
13. Move the order to delivering.
14. Upload final delivery proof.
15. Confirm the business can review proof and mark the order fully delivered.
16. Confirm in-app notifications appear and linked order navigation works.
17. Confirm push notifications if Firebase + Edge Function setup is present.
18. Trigger forgot password and open the recovery email on the same device.
19. Confirm the reset-password screen opens and the new password works.

## 14. Known Limitations

- Owner push taps currently route to the owner dashboard because there is no owner-specific order-detail screen yet.
- Foreground rider tracking is stronger now, but it is still not full background tracking.
- Push delivery depends on Firebase files plus deployed function secrets.
- Universal links / Android app links still require a real domain and hosted association files.
- Confirm-email and reset-password flows still depend on the mobile deep links being configured exactly in both Supabase and the native apps.
- Owner/rider application approval still needs manual data review or a future admin workspace.
- Payment methods are still account-management scaffolding only, not a live processor integration.
