{-# LANGUAGE ScopedTypeVariables #-}
-- | The browser runtime behind the gloss stand-in: an HTML canvas renderer and
--   a requestAnimationFrame-driven event loop. The JavaScript half lives in
--   web/static/glue.js (the global @BoS@ object).
module Graphics.Gloss.Internals.Backend
        ( runPlayIO
        , getScreenSize
        ) where

import Control.Concurrent.MVar
import Control.Exception
import Control.Monad
import Data.IORef
import System.Exit (ExitCode)
import System.IO
import GHC.JS.Prim
import GHC.JS.Foreign.Callback

import Graphics.Gloss.Data.Color
import Graphics.Gloss.Data.Display
import Graphics.Gloss.Data.Picture
import Graphics.Gloss.Internals.Event

-- ---------------------------------------------------------------------------
-- JavaScript imports

foreign import javascript unsafe "((w, h, r, g, b, a) => BoS.gfx.init(w, h, r, g, b, a))"
        js_init :: Int -> Int -> Double -> Double -> Double -> Double -> IO ()
foreign import javascript unsafe "(() => BoS.gfx.screenWidth())"  js_screenWidth  :: IO Int
foreign import javascript unsafe "(() => BoS.gfx.screenHeight())" js_screenHeight :: IO Int
foreign import javascript unsafe "(() => BoS.hookStdout())"       js_hookStdout   :: IO ()
foreign import javascript unsafe "(() => performance.now())"      js_now          :: IO Double
foreign import javascript unsafe "((cb) => requestAnimationFrame(() => cb()))"
        js_requestFrame :: Callback (IO ()) -> IO ()
foreign import javascript unsafe "(() => BoS.gfx.beginFrame())"   js_beginFrame   :: IO ()
foreign import javascript unsafe "(() => BoS.gfx.save())"         js_save         :: IO ()
foreign import javascript unsafe "(() => BoS.gfx.restore())"      js_restore      :: IO ()
foreign import javascript unsafe "((x, y) => BoS.gfx.ctx.translate(x, y))"
        js_translate :: Double -> Double -> IO ()
foreign import javascript unsafe "((d) => BoS.gfx.ctx.rotate(-d * Math.PI / 180))"
        js_rotate :: Double -> IO ()
foreign import javascript unsafe "((x, y) => BoS.gfx.ctx.scale(x, y))"
        js_scale :: Double -> Double -> IO ()
foreign import javascript unsafe "((r, g, b, a) => BoS.gfx.setColor(r, g, b, a))"
        js_setColor :: Double -> Double -> Double -> Double -> IO ()
foreign import javascript unsafe "(() => [])" js_newArray :: IO JSVal
foreign import javascript unsafe "((a, x, y) => { a.push(x, y); })"
        js_push2 :: JSVal -> Double -> Double -> IO ()
foreign import javascript unsafe "((a) => BoS.gfx.polygon(a))" js_polygon :: JSVal -> IO ()
foreign import javascript unsafe "((a) => BoS.gfx.line(a))"    js_line    :: JSVal -> IO ()
foreign import javascript unsafe "((a1, a2, r, t) => BoS.gfx.arc(a1, a2, r, t))"
        js_arc :: Double -> Double -> Double -> Double -> IO ()
foreign import javascript unsafe "((s) => BoS.gfx.text(s))"    js_text    :: JSVal -> IO ()

-- Events are queued by JS as arrays:
--   [type (0 key, 1 motion, 2 resize), keyKind (0 char, 1 special, 2 mouse),
--    keyCode, keyName, state (0 down, 1 up), shift, ctrl, alt, x, y]
foreign import javascript unsafe "(() => BoS.events.shift() || null)" js_popEvent :: IO JSVal
foreign import javascript unsafe "((e, i) => e[i])" js_idxInt    :: JSVal -> Int -> IO Int
foreign import javascript unsafe "((e, i) => e[i])" js_idxDouble :: JSVal -> Int -> IO Double
foreign import javascript unsafe "((e, i) => e[i])" js_idxVal    :: JSVal -> Int -> IO JSVal

foreign import javascript unsafe "((s) => BoS.reportError(s))" js_reportError :: JSVal -> IO ()
foreign import javascript unsafe "(() => BoS.exited())"        js_exited      :: IO ()

-- ---------------------------------------------------------------------------
-- Screen

getScreenSize :: IO (Int, Int)
getScreenSize = (,) <$> js_screenWidth <*> js_screenHeight

-- ---------------------------------------------------------------------------
-- Rendering

render :: Color -> Picture -> IO ()
render col pic = case pic of
        Blank                   -> pure ()
        Polygon ps              -> setColor col >> withPath ps js_polygon
        Line ps                 -> setColor col >> withPath ps js_line
        Circle r                -> setColor col >> js_arc 0 360 (d r) 0
        ThickCircle r t         -> setColor col >> js_arc 0 360 (d r) (d t)
        Arc a1 a2 r             -> setColor col >> js_arc (d a1) (d a2) (d r) 0
        ThickArc a1 a2 r t      -> setColor col >> js_arc (d a1) (d a2) (d r) (d t)
        Text s                  -> setColor col >> js_text (toJSString s)
        Color c p               -> render c p
        Translate x y p         -> local (js_translate (d x) (d y)) (render col p)
        Rotate a p              -> local (js_rotate (d a)) (render col p)
        Scale x y p             -> local (js_scale (d x) (d y)) (render col p)
        Pictures ps             -> mapM_ (render col) ps
  where
        d :: Float -> Double
        d = realToFrac
        local t act = js_save >> t >> act >> js_restore

setColor :: Color -> IO ()
setColor c = let (r, g, b, a) = rgbaOfColor c in
        js_setColor (realToFrac r) (realToFrac g) (realToFrac b) (realToFrac a)

withPath :: Path -> (JSVal -> IO ()) -> IO ()
withPath ps k = do
        arr <- js_newArray
        forM_ ps $ \(x, y) -> js_push2 arr (realToFrac x) (realToFrac y)
        k arr

drawFrame :: Picture -> IO ()
drawFrame pic = do
        js_beginFrame
        js_save
        render black pic
        js_restore

-- ---------------------------------------------------------------------------
-- Events

popEvent :: IO (Maybe Event)
popEvent = do
        e <- js_popEvent
        if isNull e then pure Nothing else Just <$> decode e
  where
        decode e = do
                ty <- js_idxInt e 0
                x  <- realToFrac <$> js_idxDouble e 8
                y  <- realToFrac <$> js_idxDouble e 9
                case ty of
                        1 -> pure (EventMotion (x, y))
                        2 -> pure (EventResize (round x, round y))
                        _ -> do
                                kind  <- js_idxInt e 1
                                code  <- js_idxInt e 2
                                name  <- fromJSString <$> js_idxVal e 3
                                st    <- keyState <$> js_idxInt e 4
                                mods  <- Modifiers <$> (keyState <$> js_idxInt e 5)
                                                   <*> (keyState <$> js_idxInt e 6)
                                                   <*> (keyState <$> js_idxInt e 7)
                                let key = case kind of
                                        0 -> Char (toEnum code)
                                        1 -> SpecialKey (maybe KeyUnknown id (lookup name specialKeys))
                                        _ -> MouseButton (mouseButton code)
                                pure (EventKey key st mods (x, y))
        keyState :: Int -> KeyState
        keyState 0 = Down
        keyState _ = Up
        mouseButton :: Int -> MouseButton
        mouseButton 0 = LeftButton
        mouseButton 1 = MiddleButton
        mouseButton 2 = RightButton
        mouseButton 3 = WheelUp
        mouseButton 4 = WheelDown
        mouseButton n = AdditionalButton n

specialKeys :: [(String, SpecialKey)]
specialKeys = [ (show k, k) | k <- [minBound .. maxBound] ]

-- ---------------------------------------------------------------------------
-- Main loop

data Stop = Stop

-- | Run an action; if it throws, report the error and fall back to @old@.
--   Exit requests stop the loop (signalled with 'Left').
guarded :: IORef String -> a -> IO a -> IO (Either Stop a)
guarded lastErr old act = do
        r <- try (act >>= evaluate)
        case r of
                Right x -> pure (Right x)
                Left e
                  | Just (_ :: ExitCode) <- fromException e -> pure (Left Stop)
                  | otherwise -> do
                        let msg = displayException e
                        prev <- readIORef lastErr
                        when (msg /= prev) $ do
                                writeIORef lastErr msg
                                js_reportError (toJSString msg)
                        pure (Right old)

runPlayIO
        :: forall world. Display -> Color -> Int -> world
        -> (world -> IO Picture)
        -> (Event -> world -> IO world)
        -> (Float -> world -> IO world)
        -> IO ()
runPlayIO display bg fps world0 draw handle step = do
        hSetBuffering stdout LineBuffering
        hSetBuffering stderr LineBuffering
        js_hookStdout
        (lw, lh) <- case display of
                InWindow _ sz _ -> pure sz
                FullScreen      -> getScreenSize
        let (r, g, b, a) = rgbaOfColor bg
        js_init lw lh (realToFrac r) (realToFrac g) (realToFrac b) (realToFrac a)

        frameVar <- newEmptyMVar
        onFrame  <- asyncCallback (void (tryPutMVar frameVar ()))
        lastErr  <- newIORef ""
        t0       <- js_now

        let dt = 1 / fromIntegral (max 1 fps) :: Double

            -- Apply all queued input events.
            drainEvents w = popEvent >>= \me -> case me of
                    Nothing -> pure (Right w)
                    Just ev -> guarded lastErr w (handle ev w) >>= either (pure . Left) drainEvents

            -- Advance the simulation in fixed steps, like gloss does.
            steps :: Int -> world -> IO (Either Stop world)
            steps 0 w = pure (Right w)
            steps n w = guarded lastErr w (step (realToFrac dt) w) >>= either (pure . Left) (steps (n - 1))

            loop goodWorld goodPic lastT acc = do
                    js_requestFrame onFrame
                    takeMVar frameVar
                    now <- js_now
                    -- Cap catch-up, e.g. after the tab was in the background.
                    let acc' = acc + min 0.25 ((now - lastT) / 1000)
                        n    = floor (acc' / dt) :: Int
                    res <- drainEvents goodWorld >>= either (pure . Left) (steps n)
                    case res of
                        Left Stop -> js_exited
                        Right w -> do
                            -- Only keep worlds that render; otherwise roll back.
                            ok <- guarded lastErr Nothing (draw w >>= \p -> drawFrame p >> pure (Just p))
                            case ok of
                                Left Stop       -> js_exited
                                Right (Just p)  -> loop w p now (acc' - fromIntegral n * dt)
                                Right Nothing   -> do
                                        _ <- guarded lastErr () (drawFrame goodPic)
                                        loop goodWorld goodPic now (acc' - fromIntegral n * dt)

        pic0 <- draw world0
        drawFrame pic0
        loop world0 pic0 t0 0
