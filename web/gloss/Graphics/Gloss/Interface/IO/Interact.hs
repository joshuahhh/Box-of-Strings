-- | Browser stand-in for gloss's "Graphics.Gloss.Interface.IO.Interact".
--   (Only the event types are provided; 'interactIO' and 'Controller' are not.)
module Graphics.Gloss.Interface.IO.Interact
        ( module Graphics.Gloss.Data.Display
        , module Graphics.Gloss.Data.Picture
        , module Graphics.Gloss.Data.Color
        , Event (..), Key (..), SpecialKey (..), MouseButton (..), KeyState (..), Modifiers (..)
        ) where

import Graphics.Gloss.Data.Color
import Graphics.Gloss.Data.Display
import Graphics.Gloss.Data.Picture
import Graphics.Gloss.Internals.Event
