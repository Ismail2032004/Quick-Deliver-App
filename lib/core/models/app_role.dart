enum AppRole {
  customer(
    label: 'Customer',
    description: 'Browse local businesses, place orders, and track deliveries.',
  ),
  rider(
    label: 'Rider',
    description: 'Accept deliveries, manage pickups, and complete drop-offs.',
  ),
  owner(
    label: 'Business Owner',
    description: 'Manage your storefront, products, and incoming orders.',
  );

  const AppRole({required this.label, required this.description});

  final String label;
  final String description;
}
