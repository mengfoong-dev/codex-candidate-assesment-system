import { Composition, Still } from "remotion";
import { Hero } from "./Hero";
import { Architecture } from "./Architecture";
import { Scoring } from "./Scoring";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      {/* Animated hero -> rendered to docs/media/hero.gif */}
      <Composition id="Hero" component={Hero} durationInFrames={110} fps={30} width={1280} height={440} />
      {/* Static diagrams -> rendered to PNG stills */}
      <Still id="Architecture" component={Architecture} width={1600} height={1040} />
      <Still id="Scoring" component={Scoring} width={1600} height={900} />
    </>
  );
};
