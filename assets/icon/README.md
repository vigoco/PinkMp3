# Pink Player App Icon

To use the custom Pink Player app icon:

1. Place your app icon image file (recommended: 1024x1024 PNG) in this directory as `pink_player_icon.png`
2. The icon should be square and high-resolution for best results
3. Recommended design: a white or magenta music note on a gradient background matching PinkSpotifyTheme.magentaGradient (colors: #FF3CAC to #784BA0)
4. After adding your icon, run:
   ```
   flutter pub get
   flutter pub run flutter_launcher_icons:main
   ```

This will generate all the necessary icon files for Android, iOS, and Web platforms with the adaptive icon background color set to `#2E003E` (matching PinkSpotifyTheme.bgBottom).

**Note:** The icon file should be named `pink_player_icon.png` and placed in this directory (`assets/icon/pink_player_icon.png`).

