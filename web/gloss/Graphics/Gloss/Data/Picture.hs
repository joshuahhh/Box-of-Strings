-- | Browser stand-in for gloss's "Graphics.Gloss.Data.Picture" (same API, minus bitmaps).
module Graphics.Gloss.Data.Picture
        ( Picture (..)
        , Point, Vector, Path
        , blank, polygon, line, circle, thickCircle, arc, thickArc, text
        , color, translate, rotate, scale, pictures
        , lineLoop, circleSolid, arcSolid, sectorWire
        , rectanglePath, rectangleWire, rectangleSolid
        , rectangleUpperPath, rectangleUpperWire, rectangleUpperSolid
        ) where

import Graphics.Gloss.Data.Color

type Point  = (Float, Float)
type Vector = Point
type Path   = [Point]

data Picture
        = Blank
        | Polygon       Path
        | Line          Path
        | Circle        Float
        | ThickCircle   Float Float
        | Arc           Float Float Float
        | ThickArc      Float Float Float Float
        | Text          String
        | Color         Color Picture
        | Translate     Float Float Picture
        | Rotate        Float Picture
        | Scale         Float Float Picture
        | Pictures      [Picture]
        deriving (Show, Eq)

instance Semigroup Picture where
        a <> b = Pictures [a, b]

instance Monoid Picture where
        mempty = Blank

blank :: Picture
blank = Blank

polygon :: Path -> Picture
polygon = Polygon

line :: Path -> Picture
line = Line

circle :: Float -> Picture
circle = Circle

thickCircle :: Float -> Float -> Picture
thickCircle = ThickCircle

arc :: Float -> Float -> Float -> Picture
arc = Arc

thickArc :: Float -> Float -> Float -> Float -> Picture
thickArc = ThickArc

text :: String -> Picture
text = Text

color :: Color -> Picture -> Picture
color = Color

translate :: Float -> Float -> Picture -> Picture
translate = Translate

rotate :: Float -> Picture -> Picture
rotate = Rotate

scale :: Float -> Float -> Picture -> Picture
scale = Scale

pictures :: [Picture] -> Picture
pictures = Pictures

lineLoop :: Path -> Picture
lineLoop []       = Line []
lineLoop (x : xs) = Line ((x : xs) ++ [x])

circleSolid :: Float -> Picture
circleSolid r = thickCircle (r / 2) r

arcSolid :: Float -> Float -> Float -> Picture
arcSolid a1 a2 r = thickArc a1 a2 (r / 2) r

sectorWire :: Float -> Float -> Float -> Picture
sectorWire a1 a2 r =
        let toRad a = a * pi / 180
            p a = (r * cos (toRad a), r * sin (toRad a))
        in  Pictures [Arc a1 a2 r, Line [(0, 0), p a1], Line [(0, 0), p a2]]

rectanglePath :: Float -> Float -> Path
rectanglePath sizeX sizeY =
        let sx = sizeX / 2
            sy = sizeY / 2
        in  [(-sx, -sy), (-sx, sy), (sx, sy), (sx, -sy)]

rectangleWire :: Float -> Float -> Picture
rectangleWire sizeX sizeY = lineLoop (rectanglePath sizeX sizeY)

rectangleSolid :: Float -> Float -> Picture
rectangleSolid sizeX sizeY = Polygon (rectanglePath sizeX sizeY)

rectangleUpperPath :: Float -> Float -> Path
rectangleUpperPath sizeX sy =
        let sx = sizeX / 2
        in  [(-sx, 0), (-sx, sy), (sx, sy), (sx, 0)]

rectangleUpperWire :: Float -> Float -> Picture
rectangleUpperWire sizeX sizeY = lineLoop (rectangleUpperPath sizeX sizeY)

rectangleUpperSolid :: Float -> Float -> Picture
rectangleUpperSolid sizeX sizeY = Polygon (rectangleUpperPath sizeX sizeY)
