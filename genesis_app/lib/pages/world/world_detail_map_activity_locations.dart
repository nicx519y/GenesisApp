Set<String> worldDetailEventLocationIds(
  Iterable<Map<String, dynamic>> locations,
) {
  return Set<String>.unmodifiable(
    locations
        .where(
          (location) =>
              (location['location_paragraph']?.toString().trim() ?? '')
                  .isNotEmpty,
        )
        .map(
          (location) =>
              (location['location_id'] ?? location['id'])?.toString().trim() ??
              '',
        )
        .where((locationId) => locationId.isNotEmpty),
  );
}
