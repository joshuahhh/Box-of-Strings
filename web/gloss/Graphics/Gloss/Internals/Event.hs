-- | Input event types, mirroring gloss's "Graphics.Gloss.Interface.IO.Game".
module Graphics.Gloss.Internals.Event
        ( Event (..), Key (..), SpecialKey (..), MouseButton (..)
        , KeyState (..), Modifiers (..)
        ) where

data Event
        = EventKey    Key KeyState Modifiers (Float, Float)
        | EventMotion (Float, Float)
        | EventResize (Int, Int)
        deriving (Eq, Show)

data Key
        = Char        Char
        | SpecialKey  SpecialKey
        | MouseButton MouseButton
        deriving (Show, Eq, Ord)

data MouseButton
        = LeftButton
        | MiddleButton
        | RightButton
        | WheelUp
        | WheelDown
        | AdditionalButton Int
        deriving (Show, Eq, Ord)

data KeyState
        = Down
        | Up
        deriving (Show, Eq, Ord)

data Modifiers
        = Modifiers
        { shift :: KeyState
        , ctrl  :: KeyState
        , alt   :: KeyState
        }
        deriving (Show, Eq, Ord)

data SpecialKey
        = KeyUnknown
        | KeySpace
        | KeyEsc
        | KeyF1 | KeyF2 | KeyF3 | KeyF4 | KeyF5 | KeyF6 | KeyF7 | KeyF8 | KeyF9
        | KeyF10 | KeyF11 | KeyF12 | KeyF13 | KeyF14 | KeyF15 | KeyF16 | KeyF17
        | KeyF18 | KeyF19 | KeyF20 | KeyF21 | KeyF22 | KeyF23 | KeyF24 | KeyF25
        | KeyUp
        | KeyDown
        | KeyLeft
        | KeyRight
        | KeyTab
        | KeyEnter
        | KeyBackspace
        | KeyInsert
        | KeyNumLock
        | KeyBegin
        | KeyDelete
        | KeyPageUp
        | KeyPageDown
        | KeyHome
        | KeyEnd
        | KeyShiftL
        | KeyShiftR
        | KeyCtrlL
        | KeyCtrlR
        | KeyAltL
        | KeyAltR
        | KeyPad0 | KeyPad1 | KeyPad2 | KeyPad3 | KeyPad4
        | KeyPad5 | KeyPad6 | KeyPad7 | KeyPad8 | KeyPad9
        | KeyPadDivide
        | KeyPadMultiply
        | KeyPadSubtract
        | KeyPadAdd
        | KeyPadDecimal
        | KeyPadEqual
        | KeyPadEnter
        deriving (Show, Eq, Ord, Enum, Bounded)
