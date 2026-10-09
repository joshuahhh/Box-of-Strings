-- | Browser stand-in for gloss's "Graphics.Gloss.Data.Color" (same API).
module Graphics.Gloss.Data.Color
        ( Color
        , makeColor, makeColorI, rgbaOfColor
        , mixColors, addColors, dim, bright, light, dark
        , withRed, withGreen, withBlue, withAlpha
        , greyN, black, white
        , red, green, blue
        , yellow, cyan, magenta
        , rose, violet, azure, aquamarine, chartreuse, orange
        ) where

-- | An RGBA colour, components clamped to [0, 1].
data Color = RGBA !Float !Float !Float !Float
        deriving (Show, Eq)

instance Num Color where
        (+) (RGBA r1 g1 b1 _) (RGBA r2 g2 b2 _) = RGBA (r1 + r2) (g1 + g2) (b1 + b2) 1
        (-) (RGBA r1 g1 b1 _) (RGBA r2 g2 b2 _) = RGBA (r1 - r2) (g1 - g2) (b1 - b2) 1
        (*) (RGBA r1 g1 b1 _) (RGBA r2 g2 b2 _) = RGBA (r1 * r2) (g1 * g2) (b1 * b2) 1
        abs (RGBA r g b a)      = RGBA (abs r) (abs g) (abs b) (abs a)
        signum (RGBA r g b a)   = RGBA (signum r) (signum g) (signum b) (signum a)
        fromInteger i           = let f = fromInteger i in RGBA f f f 1

clamp :: Float -> Float
clamp x = min 1 (max 0 x)

makeColor :: Float -> Float -> Float -> Float -> Color
makeColor r g b a = RGBA (clamp r) (clamp g) (clamp b) (clamp a)

makeColorI :: Int -> Int -> Int -> Int -> Color
makeColorI r g b a =
        makeColor (fromIntegral r / 255) (fromIntegral g / 255) (fromIntegral b / 255) (fromIntegral a / 255)

rgbaOfColor :: Color -> (Float, Float, Float, Float)
rgbaOfColor (RGBA r g b a) = (r, g, b, a)

mixColors :: Float -> Float -> Color -> Color -> Color
mixColors m1 m2 (RGBA r1 g1 b1 a1) (RGBA r2 g2 b2 a2) =
        let m12 = m1 + m2
            m1' = m1 / m12
            m2' = m2 / m12
        in  makeColor (m1' * r1 + m2' * r2) (m1' * g1 + m2' * g2) (m1' * b1 + m2' * b2) (m1' * a1 + m2' * a2)

addColors :: Color -> Color -> Color
addColors (RGBA r1 g1 b1 a1) (RGBA r2 g2 b2 a2) =
        normalizeColor (r1 + r2) (g1 + g2) (b1 + b2) ((a1 + a2) / 2)

normalizeColor :: Float -> Float -> Float -> Float -> Color
normalizeColor r g b a =
        let m = maximum [r, g, b]
        in  if m <= 0 then makeColor r g b a else makeColor (r / m) (g / m) (b / m) a

dim, bright, light, dark :: Color -> Color
dim (RGBA r g b a)      = makeColor (r / 1.2) (g / 1.2) (b / 1.2) a
bright (RGBA r g b a)   = makeColor (r * 1.2) (g * 1.2) (b * 1.2) a
light (RGBA r g b a)    = makeColor (r + 0.2) (g + 0.2) (b + 0.2) a
dark (RGBA r g b a)     = makeColor (r - 0.2) (g - 0.2) (b - 0.2) a

withRed, withGreen, withBlue, withAlpha :: Float -> Color -> Color
withRed x (RGBA _ g b a)        = makeColor x g b a
withGreen x (RGBA r _ b a)      = makeColor r x b a
withBlue x (RGBA r g _ a)       = makeColor r g x a
withAlpha x (RGBA r g b _)      = makeColor r g b x

greyN :: Float -> Color
greyN n = makeColor n n n 1

black, white, red, green, blue, yellow, cyan, magenta,
        rose, violet, azure, aquamarine, chartreuse, orange :: Color
black           = makeColor 0 0 0 1
white           = makeColor 1 1 1 1
red             = makeColor 1 0 0 1
green           = makeColor 0 1 0 1
blue            = makeColor 0 0 1 1
yellow          = addColors red green
cyan            = addColors green blue
magenta         = addColors red blue
rose            = addColors red magenta
violet          = addColors magenta blue
azure           = addColors blue cyan
aquamarine      = addColors cyan green
chartreuse      = addColors green yellow
orange          = addColors yellow red
