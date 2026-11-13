# Voiceover script (CollageMagik, used by the re-rendered v3 videos)

Same words, timing and voice as the original v3 ("Amy - Conversational Ad & Commercial", Eleven v3), with the app name changed from
"Insta Collage" to CollageMagik. The name is written "Collage Magic" so the voice says it naturally; it sounds the same, and
`scripts/merge-words.mjs` turns it back into "CollageMagik" for the on-screen captions.

Paste into ElevenLabs:

```
[excited] Just got back from the best trip ever... and I have, like, four hundred photos and videos. [laughs]
[sighs] But dumping them all at once? Nobody's swiping through that.
So I put it all in Collage Magic.
[excited] Photos and videos, playing together, side by side.
I trim each clip, pick the exact moment, add my song...
drop a caption on top... drag it, twist it, done.
[curious] Want more? Turn it into a carousel where every photo flows into the next slide, so people keep swiping.
Then export it in crisp HD. No blurry mess.
[warm] Same trip. Way better post.
Collage Magic. And yeah, everything is free. Download now on the App Store.
```

Then, from `google-ads/source`:

1. Save the MP3 as `public/audio/voiceover.mp3` (replace the old one).
2. `npx remotion ffmpeg -y -i public/audio/voiceover.mp3 -ar 16000 -ac 1 assets-raw/voiceover16k.wav`
3. `node scripts/transcribe.mjs && node scripts/merge-words.mjs`
4. Set `VOICE_FRAMES` in `src/ad/cues.ts` to the new length (seconds x 30).
5. `bash scripts/render-videos.sh v4`
