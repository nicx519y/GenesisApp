part of 'origin_editor_pages.dart';

class _OpeningLocationField extends StatelessWidget {
  const _OpeningLocationField({
    required this.loading,
    required this.locationName,
    required this.onTap,
  });

  final bool loading;
  final String locationName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !loading,
      label: 'Select initial location',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: loading
            ? () => showGenesisToast(context, 'Locations are still loading.')
            : null,
        child: InkWell(
          key: const ValueKey<String>('opening-location-field'),
          borderRadius: BorderRadius.circular(8),
          onTap: loading ? null : onTap,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: createFormFieldFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    locationName.isEmpty
                        ? loading
                              ? 'Loading locations...'
                              : 'Select initial location'
                        : locationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: locationName.isEmpty
                          ? createFormHint
                          : createFormText,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: createFormMuted,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpeningInitialCharacters extends StatelessWidget {
  const _OpeningInitialCharacters({required this.names});

  final String names;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey<String>('opening-initial-characters'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(characterStatIconAsset, width: 12, height: 12),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            names,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: createFormText,
              fontSize: 12,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
