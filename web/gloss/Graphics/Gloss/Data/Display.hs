-- | Browser stand-in for gloss's "Graphics.Gloss.Data.Display".
module Graphics.Gloss.Data.Display (Display (..)) where

data Display
        -- | Window title, size and position. In the browser, the size sets the
        --   logical drawing area, which is scaled to fit the page.
        = InWindow String (Int, Int) (Int, Int)
        -- | Use the whole page.
        | FullScreen
        deriving (Eq, Read, Show)
