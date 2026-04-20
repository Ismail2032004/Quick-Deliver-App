update public.deliveries
set status = 'accepted'
where status = 'confirmed';

alter table public.deliveries
  alter column status set default 'assigned';

alter table public.deliveries
  drop constraint if exists deliveries_status_check,
  add constraint deliveries_status_check
    check (
      status in (
        'assigned',
        'accepted',
        'picked_up',
        'delivering',
        'delivered_pending_proof_review',
        'delivered',
        'cancelled'
      )
    );
