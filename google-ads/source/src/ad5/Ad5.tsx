import React from "react";
import { Audio } from "@remotion/media";
import { AbsoluteFill, interpolate, Sequence, staticFile } from "remotion";
import { Background } from "../ad/Background";
import { clamp, fontFamily } from "../ad/theme";
import { ZoomCaptions } from "./Captions";
import { TOTAL, VOICE_START, WORDS } from "./cues";
import { Callouts, EndScene, FinalScene, FloatingBits, Headlines, HookScene, IntroBadge, PhoneStage, PlatformScene, SplitScene } from "./Scenes";

/** Music under the voice: the same track and level as v4. */
const MUSIC_UNDER_VOICE = 0.13;

/** v5: photos and videos in one collage. */
export const Ad5: React.FC = () => (
  <AbsoluteFill style={{ fontFamily }}>
    <Background />
    <FloatingBits />
    <Sequence name="Hook: half photos, half videos">
      <HookScene />
    </Sequence>
    <Sequence name="Two posts -> not anymore">
      <SplitScene />
    </Sequence>
    <Sequence name="App badge">
      <IntroBadge />
    </Sequence>
    <Sequence name="Headlines">
      <Headlines />
    </Sequence>
    <Sequence name="Editor phone">
      <PhoneStage />
    </Sequence>
    <Sequence name="Callouts">
      <Callouts />
    </Sequence>
    <Sequence name="Reels, Stories, TikTok">
      <PlatformScene />
    </Sequence>
    <Sequence name="One collage">
      <FinalScene />
    </Sequence>
    <Sequence name="End card">
      <EndScene />
    </Sequence>
    <Sequence name="Subtitles">
      <ZoomCaptions voiceStart={VOICE_START} words={WORDS} />
    </Sequence>
    <Sequence from={VOICE_START} name="Voiceover">
      <Audio src={staticFile("audio/voiceover-v5.mp3")} volume={1} />
    </Sequence>
    <Audio
      src={staticFile("audio/music.mp3")}
      name="Music"
      loop
      volume={(f) => interpolate(f, [0, VOICE_START, TOTAL - 40, TOTAL - 4], [MUSIC_UNDER_VOICE * 0.7, MUSIC_UNDER_VOICE, MUSIC_UNDER_VOICE * 1.6, 0], clamp)}
    />
  </AbsoluteFill>
);
