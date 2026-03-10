const List<String> supportedPromoPlatforms = <String>[
  'tiktok',
  'facebook',
  'instagram',
];

String normalizePromoPlatform(String rawPlatform) {
  switch (rawPlatform.trim().toLowerCase()) {
    case 'facebook':
      return 'facebook';
    case 'instagram':
      return 'instagram';
    default:
      return 'tiktok';
  }
}

bool isPromoProductType(String productType) {
  final normalized = productType.trim().toLowerCase();
  return normalized == 'tiktok_promo' ||
      normalized == 'facebook_promo' ||
      normalized == 'instagram_promo';
}

String promoPlatformFromProductType(String productType) {
  switch (productType.trim().toLowerCase()) {
    case 'facebook_promo':
      return 'facebook';
    case 'instagram_promo':
      return 'instagram';
    case 'tiktok_promo':
      return 'tiktok';
    default:
      return '';
  }
}

String promoProductTypeForPlatform(String platform) {
  switch (normalizePromoPlatform(platform)) {
    case 'facebook':
      return 'facebook_promo';
    case 'instagram':
      return 'instagram_promo';
    default:
      return 'tiktok_promo';
  }
}

String promoPlatformLabel(String platform) {
  switch (normalizePromoPlatform(platform)) {
    case 'facebook':
      return 'فيسبوك';
    case 'instagram':
      return 'إنستجرام';
    default:
      return 'تيك توك';
  }
}

String promoOrderTitleForPlatform(String platform) {
  final normalized = normalizePromoPlatform(platform);
  if (normalized == 'facebook') {
    return 'ترويج منشور أو فيديو ${promoPlatformLabel(normalized)}';
  }
  return 'ترويج فيديو ${promoPlatformLabel(normalized)}';
}

String promoOrderTitleFromProductType(String productType) {
  final platform = promoPlatformFromProductType(productType);
  if (platform.isEmpty) return 'ترويج محتوى';
  return promoOrderTitleForPlatform(platform);
}

String promoEntryTitleForPlatform(String platform) {
  final normalized = normalizePromoPlatform(platform);
  if (normalized == 'facebook') {
    return 'ترويج محتوى ${promoPlatformLabel(normalized)}';
  }
  return promoOrderTitleForPlatform(normalized);
}

String promoLinkLabelForPlatform(String platform) {
  final normalized = normalizePromoPlatform(platform);
  if (normalized == 'facebook') {
    return 'رابط المنشور أو الفيديو';
  }
  return 'رابط الفيديو';
}

String promoLinkLabelFromProductType(String productType) {
  final platform = promoPlatformFromProductType(productType);
  if (platform.isEmpty) return 'رابط المحتوى';
  return promoLinkLabelForPlatform(platform);
}

String promoChatLinkTextForPlatform(String platform) {
  final normalized = normalizePromoPlatform(platform);
  if (normalized == 'facebook') {
    return 'رابط المنشور أو الفيديو الترويجي على فيسبوك';
  }
  return 'رابط الفيديو الترويجي على ${promoPlatformLabel(normalized)}';
}

String promoLinkHintForPlatform(String platform) {
  switch (normalizePromoPlatform(platform)) {
    case 'facebook':
      return 'https://www.facebook.com/...';
    case 'instagram':
      return 'https://www.instagram.com/...';
    default:
      return 'https://www.tiktok.com/...';
  }
}

bool isValidPromoLinkForPlatform(String platform, String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasAuthority) return false;

  final host = _normalizePromoHost(uri.host);
  switch (normalizePromoPlatform(platform)) {
    case 'facebook':
      return host == 'facebook.com' ||
          host.endsWith('.facebook.com') ||
          host == 'fb.watch';
    case 'instagram':
      return host == 'instagram.com' || host.endsWith('.instagram.com');
    default:
      return host == 'tiktok.com' || host.endsWith('.tiktok.com');
  }
}

String _normalizePromoHost(String rawHost) {
  var host = rawHost.trim().toLowerCase();
  while (host.startsWith('www.')) {
    host = host.substring(4);
  }
  while (host.startsWith('m.')) {
    host = host.substring(2);
  }
  return host;
}
