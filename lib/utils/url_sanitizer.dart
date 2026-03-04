// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

String ensureHttps(String url) {
  final trimmed = url.trim();
  if (trimmed.startsWith('http://')) {
    return 'https://${trimmed.substring(7)}';
  }
  return trimmed;
}
