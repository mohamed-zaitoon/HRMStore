// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'dart:html' as html;

// EN: Sets Page Title.
// AR: تضبط Page Title.
void setPageTitle(String title) {
  html.document.title = title;
}

// EN: Sets Meta Description.
// AR: تضبط Meta Description.
void setMetaDescription(String description) {
  final metaList =
      html.document.head?.querySelectorAll('meta[name="description"]') ?? [];

  if (metaList.isNotEmpty) {
    metaList.first.setAttribute('content', description);
  } else {
    final meta = html.MetaElement()
      ..name = 'description'
      ..content = description;
    html.document.head?.append(meta);
  }
}
