// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:web/web.dart' as web;

// EN: Sets Page Title.
// AR: تضبط Page Title.
void setPageTitle(String title) {
  web.document.title = title;
}

// EN: Sets Meta Description.
// AR: تضبط Meta Description.
void setMetaDescription(String description) {
  final existing =
      web.document.head?.querySelector('meta[name="description"]');

  if (existing != null) {
    existing.setAttribute('content', description);
    return;
  }

  final meta = web.HTMLMetaElement()
    ..name = 'description'
    ..content = description;
  web.document.head?.append(meta);
}
