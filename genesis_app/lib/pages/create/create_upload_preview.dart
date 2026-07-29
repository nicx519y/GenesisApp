part of 'create_form_library.dart';

class _EmptyUpload extends StatelessWidget {
  const _EmptyUpload(
    this.label,
    this.iconSize,
    this.labelFontWeight,
    this.labelFontSize,
    this.iconLabelGap,
  );

  final String label;
  final double iconSize;
  final FontWeight labelFontWeight;
  final double labelFontSize;
  final double iconLabelGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          color: createFormGreen,
          size: iconSize,
        ),
        SizedBox(height: iconLabelGap),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: createFormMuted,
            fontSize: labelFontSize,
            fontWeight: labelFontWeight,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.imageUrl,
    required this.imageBytes,
    required this.isUploading,
    required this.isProcessing,
    required this.progress,
    required this.alignment,
  });

  final String imageUrl;
  final Uint8List? imageBytes;
  final bool isUploading;
  final bool isProcessing;
  final double progress;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    final bytes = imageBytes;
    return LayoutBuilder(
      builder: (context, constraints) {
        final selectedUrl = selectGenesisImageUrl(
          url,
          logicalWidth: constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : null,
          logicalHeight: constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : null,
          devicePixelRatio: MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
        );
        final Widget image = bytes != null
            ? Image.memory(
                bytes,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: alignment,
              )
            : selectedUrl.isEmpty
            ? const _PreviewPlaceholder(showSpinner: false)
            : selectedUrl.startsWith('assets/')
            ? Image.asset(
                selectedUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: alignment,
                errorBuilder: (_, error, ___) {
                  return const _PreviewErrorIcon();
                },
              )
            : GenesisStaticNetworkImage(
                imageUrl: selectedUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                alignment: alignment,
                onImageLoaded: () {
                  debugPrint(
                    '[CreateUploadBox] static image ready: "$selectedUrl"',
                  );
                },
                placeholder: (_) {
                  debugPrint(
                    '[CreateUploadBox] static image loading: "$selectedUrl"',
                  );
                  return const _PreviewPlaceholder(showSpinner: false);
                },
                errorWidget: (_, error) {
                  debugPrint(
                    '[CreateUploadBox] static image failed: '
                    'url="$selectedUrl", error="$error"',
                  );
                  return const _PreviewErrorIcon();
                },
              );
        return Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (isUploading)
              GenesisUploadProgressOverlay(
                progress: progress,
                processing: isProcessing,
              ),
          ],
        );
      },
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({this.showSpinner = true});

  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEFEFF2),
      child: showSpinner
          ? const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: createFormGreen,
                ),
              ),
            )
          : const SizedBox.expand(),
    );
  }
}

class _PreviewErrorIcon extends StatelessWidget {
  const _PreviewErrorIcon();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEFEFF2),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: createFormGreen,
          size: 34,
        ),
      ),
    );
  }
}
