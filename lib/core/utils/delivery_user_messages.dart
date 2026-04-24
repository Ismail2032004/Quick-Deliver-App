String deliveryUserMessage(
  Object error, {
  required String fallback,
}) {
  final raw = error.toString();
  final normalized = raw.toLowerCase();

  if (normalized.contains('deliveries_status_check') ||
      (normalized.contains('check constraint') &&
          normalized.contains('deliveries'))) {
    return 'The Supabase deliveries schema is outdated for the current rider workflow. Apply the delivery status alignment migration, then try again.';
  }
  if (normalized.contains('accepted') &&
      normalized.contains('postgrestexception')) {
    return 'Rider acceptance is failing because the backend does not yet allow the accepted delivery status. Apply the delivery status alignment migration, then try again.';
  }
  if (normalized.contains('postgrestexception') ||
      normalized.contains('postgres') ||
      normalized.contains('check constraint')) {
    return fallback;
  }
  if (normalized.contains('not eligible') ||
      normalized.contains('can no longer be assigned')) {
    return 'This delivery can\'t be assigned right now.';
  }
  if (normalized.contains('not approved')) {
    return 'This workspace is not approved for that action.';
  }
  if (normalized.contains('not found') ||
      normalized.contains('no longer available')) {
    return 'This delivery is no longer available. Refresh and try again.';
  }
  if (normalized.contains('proof')) {
    return 'Proof upload failed. Please try again.';
  }
  if (normalized.contains('no image') ||
      normalized.contains('selected image is empty') ||
      normalized.contains('selected image is no longer available')) {
    return 'No image was captured. Please try again.';
  }
  if (normalized.contains('row-level security') ||
      normalized.contains('new row violates row-level security') ||
      normalized.contains('permission denied for table objects') ||
      normalized.contains('access denied')) {
    return 'Proof upload is blocked by Supabase Storage permissions. Apply the storage policies migration, then try again.';
  }
  if (normalized.contains('storage') || normalized.contains('bucket')) {
    return 'Supabase Storage rejected the proof upload. Confirm the delivery-proofs bucket and storage policies are applied, then try again.';
  }
  if (normalized.contains('location')) {
    return 'We couldn\'t update the rider location right now. Please try again.';
  }
  if (normalized.contains('permission')) {
    return 'QuickDeliver needs the required permission before that action can continue.';
  }
  if (normalized.contains('cannot move') ||
      normalized.contains('can only')) {
    return 'This delivery can\'t move to that stage right now.';
  }

  return fallback;
}
