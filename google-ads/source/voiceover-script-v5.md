# Voiceover script v5 (CollageMagik, about 40 seconds)

Same voice and settings as v3 and v4 ("Amy - Conversational Ad & Commercial", Eleven v3). The name is written "Collage Magic"
so the voice says it naturally; `scripts/merge-words.mjs` turns it back into "CollageMagik" for the captions.

None of the earlier ads say that one collage can hold **photos and videos together**. This one is about exactly that: photos
and up to two videos in the same collage, the videos playing next to the still photos, trimming, sound and music, a
portrait shot fitted with blurred sides, and a smooth video export. About 105 words, so it should land near 40 seconds,
like v4.

Only collages mix photos and videos (a carousel is photos only), so the carousel isn't mentioned.

Paste into ElevenLabs:

```
[excited] Trip's over... and my camera roll is half photos, half videos. [sighs] That usually means two separate posts.
[warm] Not anymore. In Collage Magic, they go in the same collage.
Drop in my photos... then two videos, right next to them.
The beach clip plays while the sunset photo stays still. [curious] Moving and still, side by side.
Trim each video, pick the exact moment... keep the waves, mute the wind, and add a song underneath.
Shot it in portrait? Fit the whole picture, with soft blurred sides.
Add a caption, then export a smooth video for Reels, Stories, or TikTok.
[warm] Photos and videos. One collage. Collage Magic. Free on the App Store.
```

## Scenes to match each line

| Line | On screen |
| --- | --- |
| Half photos, half videos, two separate posts | Camera roll scrolling with photos and video tiles (duration badges) mixed; two plain posts side by side |
| Same collage | App opens on an empty collage layout |
| Drop in photos, then two videos | Photos fill cells from the tray, then two video tiles (film badge) are dragged into the remaining cells |
| Clip plays, photo stays still | Collage playing: the video cells move, the photo cells stay still; a soft glow on each video cell |
| Trim, pick the moment, mute, add a song | Timeline panel: a clip's ends dragged in, Choose part filmstrip; Sound panel: one video's volume to 0, Add music |
| Portrait, fit with blurred sides | A tall photo in a square cell switches from Fill to Fit whole picture; blurred sides fade in |
| Caption, export smooth video | Caption added; export sheet with video selected, progress, then the finished video playing |
| Photos and videos, one collage | Finished collage playing in a Reel frame with likes coming in; logo and App Store badge |

## Rendering

From `google-ads/source`, the same steps as v3 and v4:

1. Save the MP3 as `public/audio/voiceover.mp3`.
2. `npx remotion ffmpeg -y -i public/audio/voiceover.mp3 -ar 16000 -ac 1 assets-raw/voiceover16k.wav`
3. `node scripts/transcribe.mjs && node scripts/merge-words.mjs`
4. Set `VOICE_FRAMES` in `src/ad/cues.ts` to the new length (seconds x 30).
5. Render as `v5` once the scenes above are built.
