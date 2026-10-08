import 'package:web/web.dart' as web;

void redirectBrowser(String url) {
  web.window.location.href = url;
}

void replaceBrowserUrl(String url) {
  web.window.history.replaceState(null, '', url);
}

String displayMode() {
  if (web.window.matchMedia('(display-mode: standalone)').matches) {
    return 'standalone';
  }
  return 'browser';
}
