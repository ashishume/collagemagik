import React from "react";
import { Audio } from "@remotion/media";
import { AbsoluteFill, interpolate, Sequence, staticFile } from "remotion";
import { Background } from "./Background";
import { Captions } from "./Captions";
import { cue, TOTAL, VOICE_START } from "./cues";
import { AppPhone } from "./scenes/AppPhone";
import { BeforeAfterScene, EndScene, FeatureOverlays, RevealScene } from "./scenes/AppScenes";
import { DumpScene, IntroScene, StoryBadge } from "./scenes/Story";
import { clamp, fontFamily } from "./theme";

/**
 * Music level under the voice (linear gain). Measured: voice -19.6 LUFS; music at 0.075 is about -33 LUFS, so it sits
 * ~13.5 LU under the voice: audible and fun, while every word stays clear. (v1 used 0.05, ~17 LU under.)
 */
const MUSIC_UNDER_VOICE = 0.075;

export const Ad: React.FC = () => {
  const dumpAt = cue("but");
  const revealAt = cue("so");
  return (
    <AbsoluteFill style={{ fontFamily }}>
      <Background />

      {/* Story: the voice doesn't name the app yet, but the app badge and a peek of its screens are already on screen */}
      <Sequence name="Intro: back from the trip" durationInFrames={dumpAt + 12}>
        <IntroScene dur={dumpAt + 12} />
      </Sequence>
      <Sequence name="Dump: nobody swipes" from={dumpAt} durationInFrames={revealAt - dumpAt + 8}>
        <DumpScene dur={revealAt - dumpAt + 8} />
      </Sequence>
      <Sequence name="App badge (intro)" durationInFrames={revealAt + 6}>
        <StoryBadge dur={revealAt + 6} switchAt={dumpAt} />
      </Sequence>

      {/* App: one phone that stays on screen, with headlines and stickers timed to the words */}
      <Sequence name="Reveal: app name">
        <RevealScene />
      </Sequence>
      <Sequence name="App phone">
        <AppPhone />
      </Sequence>
      <Sequence name="Feature overlays">
        <FeatureOverlays />
      </Sequence>
      <Sequence name="Before / after">
        <BeforeAfterScene />
      </Sequence>
      <Sequence name="End card">
        <EndScene />
      </Sequence>

      <Sequence name="Captions">
        <Captions voiceStart={VOICE_START} />
      </Sequence>

      {/* Audio */}
      <Sequence from={VOICE_START} name="Voiceover">
        <Audio src={staticFile("audio/voiceover.mp3")} volume={1} />
      </Sequence>
      <Audio
        src={staticFile("audio/music.mp3")}
        name="Music"
        volume={(f) =>
          interpolate(
            f,
            [0, VOICE_START, TOTAL - 40, TOTAL - 4],
            [MUSIC_UNDER_VOICE * 0.5, MUSIC_UNDER_VOICE, MUSIC_UNDER_VOICE * 1.6, 0],
            clamp,
          )
        }
      />
    </AbsoluteFill>
  );
};
