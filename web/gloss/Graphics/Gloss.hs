-- | Browser stand-in for the gloss library: same API as "Graphics.Gloss",
--   rendering to an HTML canvas (see "Graphics.Gloss.Internals.Backend").
module Graphics.Gloss
        ( module Graphics.Gloss.Data.Picture
        , module Graphics.Gloss.Data.Color
        , Display (..)
        , display
        , animate
        , play
        ) where

import Graphics.Gloss.Data.Color
import Graphics.Gloss.Data.Display
import Graphics.Gloss.Data.Picture
import Graphics.Gloss.Interface.Pure.Game (play)
import Graphics.Gloss.Internals.Backend

display :: Display -> Color -> Picture -> IO ()
display dis bg pic =
        runPlayIO dis bg 60 () (\_ -> pure pic) (\_ w -> pure w) (\_ w -> pure w)

animate :: Display -> Color -> (Float -> Picture) -> IO ()
animate dis bg frame =
        runPlayIO dis bg 60 0 (pure . frame) (\_ t -> pure t) (\dt t -> pure (t + dt))
