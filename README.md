# Neon Pulse

Native macOS Metal rhythm-platformer test game. Original content, one level, one-button movement.

## Run

Requires macOS with Metal and Swift 6.

```sh
swift run
```

Build local `.app` bundle:

```sh
swift build -c release
rm -rf "Neon Pulse.app"
mkdir -p "Neon Pulse.app/Contents/MacOS" "Neon Pulse.app/Contents/Resources"
cp .build/release/NeonPulse "Neon Pulse.app/Contents/MacOS/NeonPulse"
cp AppInfo.plist "Neon Pulse.app/Contents/Info.plist"
cp -R .build/release/NeonPulse_NeonPulse.bundle "Neon Pulse.app/Contents/Resources/NeonPulse_NeonPulse.bundle"
cp .build/release/NeonPulse_NeonPulse.bundle/NeonShaders.metal "Neon Pulse.app/Contents/Resources/NeonShaders.metal"
chmod +x "Neon Pulse.app/Contents/MacOS/NeonPulse"
open "Neon Pulse.app"
```

GitHub Actions uploads same `.app` as workflow artifact.

Press Space or click to jump. Press R to restart.

## Rendering

- MetalKit render loop
- Runtime MetalFX capability probe
- Runtime ray-tracing capability probe
- Shader fallback for Macs without newer GPU features
- Original procedural geometry and colors

Metal 4, MetalFX, ray tracing, and path tracing require compatible Apple silicon, macOS, and Xcode SDK versions. GitHub Actions validates build and tests; hosted CI does not replace local GPU validation.

## License

Source code: MIT. Game content is original and not affiliated with Geometry Dash or RobTop Games.
