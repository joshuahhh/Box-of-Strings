-- | Browser stand-in for gloss's "Graphics.Gloss.Interface.Pure.Game".
module Graphics.Gloss.Interface.Pure.Game
        ( module Graphics.Gloss.Data.Display
        , module Graphics.Gloss.Data.Picture
        , module Graphics.Gloss.Data.Color
        , play
        , Event (..), Key (..), SpecialKey (..), MouseButton (..), KeyState (..), Modifiers (..)
        ) where

import Graphics.Gloss.Data.Color
import Graphics.Gloss.Data.Display
import Graphics.Gloss.Data.Picture
import Graphics.Gloss.Internals.Backend
import Graphics.Gloss.Internals.Event

play    :: Display -> Color -> Int -> world
        -> (world -> Picture)
        -> (Event -> world -> world)
        -> (Float -> world -> world)
        -> IO ()
play dis bg fps world0 draw handle step =
        runPlayIO dis bg fps world0 (pure . draw) (\e w -> pure (handle e w)) (\t w -> pure (step t w))
