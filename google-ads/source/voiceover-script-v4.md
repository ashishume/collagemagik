# Voiceover script v4 (CollageMagik, about 40 seconds)

Same voice and settings as v3 ("Amy - Conversational Ad & Commercial", Eleven v3). The name is written "Collage Magic" so the
voice says it naturally; `scripts/merge-words.mjs` turns it back into "CollageMagik" for the captions.

This one shows off the collage itself (layouts, dragging photos in, resizing and swapping), a photo on top that locks straight
when turned, caption fonts, the carousel, and sizes for every app. About 110 words; the 95-word draft came out at 35 seconds, so this should land near 40.

Paste into ElevenLabs:

```
[excited] Just got back from my trip... [sighs] but a boring photo dump? Nobody's swiping that.
[warm] So I made a collage in Collage Magic.
Pick a layout, drag my photos in... drag the borders to resize, hold and drag to swap.
Drop one photo on top of another... give it a white instant frame, or a torn paper edge...
then twist it. [curious] Feel that click? Perfectly straight.
Add a caption in a dreamy script font.
[excited] Or make it a carousel, where one photo flows across the slides so they keep swiping.
Post, story, Instagram, TikTok... it fits. Export in crisp HD.
[warm] Same trip. Way better post. Collage Magic. Free on the App Store.
```

## Scenes to match each line

| Line | On screen |
| --- | --- |
| Back from my trip, boring photo dump | Quick travel clips, then a plain photo slideshow a follower scrolls past |
| Made a collage | App opens on an empty collage layout |
| Pick a layout, drag photos in | Layouts flick by; photos dragged from the tray fill the cells |
| Drag the borders, hold and drag to swap | A border between cells dragged to resize; a photo held and dropped on another to swap |
| Photo on top, instant frame, torn edge | Tray photo dropped over the collage; its frame switches from instant to torn paper |
| Twist it, click | Photo on top turned with two fingers; yellow guide lines and badge at 0° |
| Caption in a script font | Caption added and switched to a script font |
| Carousel, flows across slides | Same photos as a carousel; one photo crosses the seam; swipe through the slides |
| Post, story, Instagram, TikTok, HD | Design switching between post and story formats, then the export sheet |
| Same trip, way better post | Finished post with likes coming in; logo and App Store badge |

## Rendering

From `google-ads/source`, the same steps as v3:

1. Save the MP3 as `public/audio/voiceover.mp3`.
2. `npx remotion ffmpeg -y -i public/audio/voiceover.mp3 -ar 16000 -ac 1 assets-raw/voiceover16k.wav`
3. `node scripts/transcribe.mjs && node scripts/merge-words.mjs`
4. Set `VOICE_FRAMES` in `src/ad/cues.ts` to the new length (seconds x 30).
5. `bash scripts/render-videos.sh v4`
