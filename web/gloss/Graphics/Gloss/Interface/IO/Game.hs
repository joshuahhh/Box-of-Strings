-- | Browser stand-in for gloss's "Graphics.Gloss.Interface.IO.Game".
module Graphics.Gloss.Interface.IO.Game
        ( module Graphics.Gloss.Data.Display
        , module Graphics.Gloss.Data.Picture
        , module Graphics.Gloss.Data.Color
        , playIO
        , Event (..), Key (..), SpecialKey (..), MouseButton (..), KeyState (..), Modifiers (..)
        ) where

import Graphics.Gloss.Data.Color
import Graphics.Gloss.Data.Display
import Graphics.Gloss.Data.Picture
import Graphics.Gloss.Internals.Backend
import Graphics.Gloss.Internals.Event

playIO  :: Display -> Color -> Int -> world
        -> (world -> IO Picture)
        -> (Event -> world -> IO world)
        -> (Float -> world -> IO world)
        -> IO ()
playIO = runPlayIO
