const String genesisStaticImageCdnHost = 'cdn-001.worldo.ai';

const Set<String> genesisHttp3CapableHosts = <String>{
  genesisStaticImageCdnHost,
  'api.worldo.ai',
  'dev.hushie.ai',
  'collect.worldo.ai',
  'af.hushie.ai',
};

final Uri genesisStaticImageCdnWarmUpUri = Uri.https(
  genesisStaticImageCdnHost,
  '/robots.txt',
);

bool isGenesisTilemapImageUri(Uri uri) {
  if (uri.scheme.toLowerCase() != 'https' ||
      uri.host.toLowerCase() != genesisStaticImageCdnHost) {
    return false;
  }
  final path = uri.path.toLowerCase();
  return path.startsWith('/predata/tiles/') &&
      (path.endsWith('.png') || path.endsWith('.webp'));
}
