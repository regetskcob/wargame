{{flutter_js}}
{{flutter_build_config}}

// Nothing from Google: CanvasKit comes from the build itself
// (flutter build web --no-web-resources-cdn), and the fallback fonts the
// engine would fetch from fonts.gstatic.com for glyphs no bundled font has
// point at our own server instead. That folder is empty on purpose: such a
// glyph shows as a box rather than sending the player's address to Google
// (privacy notice, lib/src/legal/legal_text.dart).
_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: 'assets/fallback-fonts/',
  },
});
