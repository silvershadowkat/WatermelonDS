# ModDeck additions

Based on WatermelonDS 0.8.0.rc3, upstream commit
`9bd6a0db59f944cda961e1df7f6e692eb6d4e65b`.
The melonDS core revision is unchanged. The application ID is
`me.magnum.melondualds.moddeck`, so installation preserves the original app.
ROMs, BIOS, firmware and third-party drivers are not included in the APK.

## Video settings

Choose **Settings → Video → Renderer → Vulkan**, then **Filter**:

- 2D xBR 50% + pixel-aware
- 2D xBR 100% + pixel-aware
- 2D xBR 50%
- 2D xBR 100%

Start with 50% + pixel-aware. Internal resolution still controls 3D rendering;
it does not have to be increased just to filter 2D artwork. For a full-width
DS screen on a 1080-pixel-wide portrait display, 4× is a sensible starting
point. Raising it further does not improve native-resolution 2D assets.

**Video → DS LCD grid** independently selects Off, Subtle, Medium or Strong.
It overlays a 256×192-cell LCD pattern after the selected built-in Vulkan
filter, including over high-resolution 3D. Grid spacing follows each DS screen,
not the phone's resolution or the 3D resolution setting. The smooth aperture
follows [libretro's NDS LCD1x model](https://github.com/libretro/slang-shaders/blob/master/handheld/shaders/lcd1x_nds.slang),
without its colour correction. Each aperture is integrated across the physical
display-pixel footprint. The mask fades before the Nyquist limit instead of
aliasing into broad bands when fractional scaling is used. It fades when a screen is too small to
resolve it cleanly. Android controls and menus are not filtered. Off preserves
the previous output. The option defaults to Off and does not add a GPU pass
or a buffered frame. RetroArch presets keep their own display effects.

The final faithful compositor marks certified 2D pixels in the display
image's otherwise-unused alpha channel, only for these opt-in presets.
The presenter reconstructs those pixels with Hyllian's MIT-licensed xBR-lv2
kernel and optionally sharp-bilinear grid correction. Uncertain pixels,
3D, captured-3D and mixed neighborhoods retain the original renderer output.
Artwork drawn by a game as 3D geometry is therefore not automatically treated
as 2D. Existing whole-image filters remain available for that alternative.

There are no extra temporal frames, GPU render targets, readbacks or emulator
timing changes in this filter. It adds GPU work to the existing presentation
pass, so performance must still be checked on each device. All original
filter modes retain their existing behavior. Screenshot alpha is made opaque;
the internal provenance tag is not exported as transparency.

Pixel-aware resampling reuses one xBR edge analysis for subpixels belonging
to the same native DS pixel. Provenance is checked during the existing color
fetches instead of a second neighborhood scan. This preserves the four-tap
resampling and reduces duplicated shader work.

The existing Adreno driver chooser is also routed through the standard
preference-dialog callback, preventing two stacked dialogs from leaving the
selected driver unchanged. Driver ZIP import remains the upstream mechanism.

## Touch controls

Portrait defaults place the top screen at the top and the touchscreen directly
below, preserving 4:3 with no gap. Controls occupy the remaining area. Shorter
displays reduce both screens uniformly to leave room for controls.

The DS-style D-pad tilts toward the thumb. Its four short arm lines turn red
for active directions; diagonals light two lines. ABXY uses a compact cluster
with overlapping two-button zones. Separate pointers are combined, and
releasing one pointer preserves inputs held by the others. The original input
processor and physical-controller mappings are unchanged.

Use **Settings → Input → Layouts** to create/edit a layout and move or resize
the pad, button cluster and screens. Existing haptic-feedback settings apply.
The artwork is drawn at display resolution and is independent of DS filters.

## Maintaining the fork

The feature is contained in the Android frontend; no game-specific hooks or
core patches are required. When merging upstream, review these seams:

1. Keep filter enum values 0–8 stable. The new modes append values 9–12.
   Both JNI mappings must agree: `MelonDSAndroidConfiguration.cpp` and
   `MelonDSAndroidJNI.cpp`.
2. Preserve the faithful compositor's 16-byte push-constant range and initialize
   the provenance flag for every command buffer, including debug composition.
3. Preserve the new GLSL include in both shader regeneration dependency lists.
   Regenerate the two changed frontend shader headers after changing GLSL.
   Do not replace the core submodule's generated shaders merely because a
   different local compiler produces different binaries.
4. Keep the touch resolver pure Kotlin. The artwork view and two component
   builders use the existing layout editor and touch-handler infrastructure.

Optional build properties `androidAbis`, `androidNdkVersion`, `rustToolchain`
and `nativeJobs` allow local toolchain selection and bounded compilation.
Their defaults preserve upstream multi-ABI/toolchain choices.

Example local release build (supply your own ignored signing configuration):

```text
gradlew :app:assembleGitHubProdRelease :app:testGitHubProdReleaseUnitTest \
  -PandroidAbis=arm64-v8a -PandroidNdkVersion=29.0.14206865 \
  -PrustToolchain=1.92.0 -PnativeJobs=2 --max-workers=2
```

Device checks and their limits are recorded with the delivered APK. Rhythm
Heaven is the user's audio/input timing reference. Stable FPS and audio
telemetry are not a measurement of physical touch-to-speaker latency.
