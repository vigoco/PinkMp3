# Pink Player Splash Screen

This directory contains the splash screen assets for the Pink Player app.

## Required Files

### 1. `pink_gradient_bg.png`
- This should be a full-screen gradient background image matching the PinkSpotifyTheme background gradient
- Gradient colors: 
  - Top: `#000000` (PinkSpotifyTheme.bgTop)
  - Bottom: `#2E003E` (PinkSpotifyTheme.bgBottom)
- Recommended size: Match your target device screen resolutions (e.g., 1080x1920 for Android, 1242x2688 for iPhone)
- The gradient should flow from top to bottom (topCenter to bottomCenter alignment)

## Usage

After creating the splash background image:

1. Place `pink_gradient_bg.png` in this directory (`assets/splash/pink_gradient_bg.png`)
2. Ensure `pink_player_icon.png` exists in `assets/icon/`
3. Run the following commands:
   ```
   flutter pub get
   flutter pub run flutter_native_splash:create
   ```

The splash screen will display:
- Background: `pink_gradient_bg.png` (pink neon gradient)
- Foreground: `pink_player_icon.png` (centered logo)
- Smooth fade transition to the main app once initialization completes

## Design Guidelines

- The splash screen uses the same gradient as the app's main background for visual consistency
- The app icon appears centered on the gradient background
- Colors match PinkSpotifyTheme for a cohesive brand experience
