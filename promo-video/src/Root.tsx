import "./index.css";
import { Composition } from "remotion";
import { VellemPromo } from "./VellemPromo";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="VellemPromo"
        component={VellemPromo}
        durationInFrames={1320}
        fps={30}
        width={1280}
        height={720}
      />
    </>
  );
};
