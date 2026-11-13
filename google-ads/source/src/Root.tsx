import { Composition, Folder, Still } from "remotion";
import { Ad } from "./ad/Ad";
import { TOTAL } from "./ad/cues";
import { AdImage, Logo } from "./photos/AdImage";
import { ASSET_SIZES, BANNER_SIZES, THEMES } from "./photos/sizes";
import { PanClip } from "./tools/PanClip";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Folder name="Videos">
        <Composition id="AdVertical" component={Ad} durationInFrames={TOTAL} fps={30} width={1080} height={1920} />
        <Composition id="AdLandscape" component={Ad} durationInFrames={TOTAL} fps={30} width={1920} height={1080} />
        <Composition id="AdSquare" component={Ad} durationInFrames={TOTAL} fps={30} width={1080} height={1080} />
      </Folder>
      <Folder name="Image-assets">
        {THEMES.flatMap((theme) =>
          ASSET_SIZES.flatMap((s) =>
            [true, false].map((withText) => (
              <Still
                key={`${theme}-${s.name}-${withText}`}
                id={`asset-${theme}-${s.name.replace(/\./g, "-")}-${withText ? "text" : "clean"}`}
                component={AdImage}
                width={s.w}
                height={s.h}
                defaultProps={{ theme, withText, w: s.w, h: s.h }}
              />
            )),
          ),
        )}
      </Folder>
      <Folder name="Display-banners">
        {THEMES.flatMap((theme) =>
          BANNER_SIZES.map(([w, h]) => (
            <Still key={`${theme}-${w}x${h}`} id={`banner-${theme}-${w}x${h}`} component={AdImage} width={w} height={h} defaultProps={{ theme, withText: true, w, h }} />
          )),
        )}
      </Folder>
      <Folder name="Tools">
        {/* input clips for recapturing the app screens (scripts/capture-app-screens.sh) */}
        <Composition id="PanClip" component={PanClip} durationInFrames={180} fps={30} width={1080} height={1920} defaultProps={{ photo: "golden-wave" }} />
      </Folder>
      <Folder name="Logos">
        <Still id="logo-square-1x1" component={Logo} width={1200} height={1200} defaultProps={{ w: 1200, h: 1200 }} />
        <Still id="logo-landscape-4x1" component={Logo} width={1200} height={300} defaultProps={{ w: 1200, h: 300 }} />
      </Folder>
    </>
  );
};
