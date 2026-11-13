import React from "react";
import { Audio } from "@remotion/media";
import { AbsoluteFill, interpolate, Sequence, staticFile } from "remotion";
import { Background } from "../ad/Background";
import { Captions } from "../ad/Captions";
import { DumpScene } from "../ad/scenes/Story";
import { clamp, fontFamily } from "../ad/theme";
import { TOTAL, VOICE_START, WORDS } from "./cues";
import { BeforeAfterScene, Callouts, CarouselBurst, EndScene, FormatCallouts, Headlines, HookScene, IntroBadge, PhoneStage, RevealScene } from "./Scenes";
import { T } from "./timeline";

/**
 * Music level under the voice (linear gain). v3 used 0.075 (~13.5 LU under the voice); v4 sits about 5 dB louder so the
 * track drives the edit, while the voice still leads. The whole mix is then normalised to -14 LUFS.
 */
const MUSIC_UNDER_VOICE = 0.13;

export const Ad4: React.FC = () => {
  const dumpDur = T.so - T.but + 8;
  return (
    <AbsoluteFill style={{ fontFamily }}>
      <Background />

      <Sequence name="Hook: back from my trip">
        <HookScene />
      </Sequence>
      <Sequence name="Dump: nobody swipes" from={T.but} durationInFrames={dumpDur}>
        <DumpScene dur={dumpDur} />
      </Sequence>
      <Sequence name="App badge">
        <IntroBadge />
      </Sequence>
      <Sequence name="Reveal: collage -> app">
        <RevealScene />
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
      <Sequence name="Carousel burst">
        <CarouselBurst />
      </Sequence>
      <Sequence name="Formats">
        <FormatCallouts />
      </Sequence>
      <Sequence name="Before / after">
        <BeforeAfterScene />
      </Sequence>
      <Sequence name="End card">
        <EndScene />
      </Sequence>

      <Sequence name="Captions">
        <Captions voiceStart={VOICE_START} words={WORDS} portraitTop={0.855} />
      </Sequence>

      <Sequence from={VOICE_START} name="Voiceover">
        <Audio src={staticFile("audio/voiceover-v4.mp3")} volume={1} />
      </Sequence>
      <Audio
        src={staticFile("audio/music.mp3")}
        name="Music"
        volume={(f) =>
          interpolate(f, [0, VOICE_START, TOTAL - 40, TOTAL - 4], [MUSIC_UNDER_VOICE * 0.7, MUSIC_UNDER_VOICE, MUSIC_UNDER_VOICE * 1.6, 0], clamp)
        }
      />
    </AbsoluteFill>
  );
};
