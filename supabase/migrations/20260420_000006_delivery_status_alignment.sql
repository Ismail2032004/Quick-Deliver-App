alter table public.deliveries
  drop constraint if exists deliveries_status_check,
  add constraint deliveries_status_check
    check (
      status in (
        'assigned',
        'accepted',
        'confirmed',
        'picked_up',
        'delivering',
        'delivered_pending_proof_review',
        'delivered',
        'cancelled'
      )
    );
