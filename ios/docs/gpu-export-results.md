| Case | Engine | Resolution/fps | Seconds | Peak MB | SSIM overall | SSIM min frame |
|---|---|---|---:|---:|---:|---:|
| rounded | cpu | 1080×1920/30 | 88.724 | 783.1 | - | - |
| rounded | gpu | 1080×1920/30 | 34.122 | 676.5 | 0.992726 | 0.989312 |
| frame-torn | cpu | 1080×1920/30 | 41.543 | 650.3 | - | - |
| frame-torn | gpu | 1080×1920/30 | 41.026 | 622.3 | 0.991278 | 0.989863 |
| frame-tape | cpu | 1080×1920/30 | 118.689 | 647.7 | - | - |
| frame-tape | gpu | 1080×1920/30 | 21.114 | 635.1 | 0.991472 | 0.990278 |
| frame-film | cpu | 1080×1920/30 | 31.910 | 647.7 | - | - |
| frame-film | gpu | 1080×1920/30 | 31.410 | 622.4 | 0.991359 | 0.990242 |
| frame-stamp | cpu | 1080×1920/30 | 33.761 | 651.3 | - | - |
| frame-stamp | gpu | 1080×1920/30 | 37.152 | 622.6 | 0.991605 | 0.990387 |
| frame-gallery | cpu | 1080×1920/30 | 15.636 | 647.0 | - | - |
| frame-gallery | gpu | 1080×1920/30 | 12.501 | 635.7 | 0.992021 | 0.991221 |
| frame-date | cpu | 1080×1920/30 | 21.057 | 651.2 | - | - |
| frame-date | gpu | 1080×1920/30 | 17.450 | 632.4 | 0.990377 | 0.989067 |
| frame-neon | cpu | 1080×1920/30 | 23.953 | 647.3 | - | - |
| frame-neon | gpu | 1080×1920/30 | 15.833 | 631.6 | 0.990491 | 0.989181 |
| frame-instant | cpu | 1080×1920/30 | 20.211 | 650.1 | - | - |
| frame-instant | gpu | 1080×1920/30 | 33.290 | 624.2 | 0.991864 | 0.990823 |
| frame-circle | cpu | 1080×1920/30 | 37.483 | 650.2 | - | - |
| frame-circle | gpu | 1080×1920/30 | 38.159 | 625.7 | 0.993105 | 0.991985 |
| frame-heart | cpu | 1080×1920/30 | 40.384 | 649.1 | - | - |
| frame-heart | gpu | 1080×1920/30 | 21.960 | 624.6 | 0.994326 | 0.993189 |
| frame-arch | cpu | 1080×1920/30 | 161.239 | 650.6 | - | - |
| frame-arch | gpu | 1080×1920/30 | 39.206 | 625.8 | 0.991569 | 0.990276 |
| tilt-overlays | cpu | 1080×1920/30 | 82.079 | 672.2 | - | - |
| tilt-overlays | gpu | 1080×1920/30 | 54.955 | 648.7 | 0.994780 | 0.993989 |
| fit-looks | cpu | 1080×1920/30 | 68.196 | 655.0 | - | - |
| fit-looks | gpu | 1080×1920/30 | 25.056 | 622.4 | 0.989950 | 0.987439 |
| living-weekend | cpu | 1080×1920/30 | 160.370 | 716.2 | - | - |
| living-weekend | gpu | 1080×1920/30 | 28.984 | 750.7 | 0.994893 | 0.990278 |
| 4k60-heavy | cpu | 2160×3840/60 | 981.816 | 2298.8 | - | - |
| 4k60-heavy | gpu | 2160×3840/60 | 661.607 | 2221.4 | 0.994425 | 0.989074 |
| HDR HD smoke test | gpu | 1080×1920/30 | 37.760 | 401.5 | - | - |
| Forced first GPU frame failure | cpu | 1080×1920/30 | 14.875 | 513.8 | - | - |

- S1 Pending. 16/31 CPU/GPU cases measured and within both SSIM thresholds.
- S2 Fail. 4K60 GPU time was 67.4% of CPU time (target ≤ 40%).
- S3 Fail. 4K60 GPU peak footprint was 96.6% of CPU footprint (target ≤ 60%).
- S4 Pass at HD. FFprobe read HEVC, `yuv420p10le`, `arib-std-b67` and BT.2020 from the GPU MP4.
- S5 Pass. Forced a failure before the first frame and verified a completed 30-frame MP4 and the CPU fallback log.
- S6 Pass. Generic iOS Simulator build succeeded with no new warnings in the touched Swift files.

Observed small pixel differences around resampled detail and clip edges. CPU is on the left in the [rounded-edge crop](/tmp/collagemagik-export-comparison/rounded/edge-compare.png).

Branch commits `a0d2987 Reuse moving print artwork and limit large Core Image renders`, `785906b Bound GPU mask storage and harden export verification`, `fe08d8b Compose SDR and HLG video frames with Metal and shared print layers`, `930c3d1 Share timeline selection between image and Metal buffer readers`, `0723bf6 Add a simulator matrix and instrument CPU video exports`

Changed files `CLAUDE.md`, `ios/CollageMagik/CollageMagik/DebugHarness.swift`, `ios/CollageMagik/CollageMagik/Export/CollageRenderer.swift`, `ios/CollageMagik/CollageMagik/Export/Exporter.swift`, `ios/CollageMagik/CollageMagik/Export/GPUFrameComposer.swift`, `ios/CollageMagik/CollageMagik/Model/PhotoLook.swift`, `ios/README.md`, `ios/docs/gpu-export-results.md`, `ios/scripts/compare_export_engines.sh`.

CPU output matched its pre-refactor baseline exactly on rounded and torn cases. The debug readers matched all 450 timestamps in the three-video case. Tests used five-second excerpts of the plan’s ad clips.
The full matrix remains in progress.
