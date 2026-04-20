enum OrderDestinationSource {
  manual,
  currentLocation,
}

OrderDestinationSource orderDestinationSourceFromStorage(String? value) {
  return switch (value) {
    'current_location' => OrderDestinationSource.currentLocation,
    _ => OrderDestinationSource.manual,
  };
}

extension OrderDestinationSourceStorage on OrderDestinationSource {
  String get storageValue {
    return switch (this) {
      OrderDestinationSource.manual => 'manual',
      OrderDestinationSource.currentLocation => 'current_location',
    };
  }

  String get label {
    return switch (this) {
      OrderDestinationSource.manual => 'Typed address',
      OrderDestinationSource.currentLocation => 'Current location snapshot',
    };
  }
}
