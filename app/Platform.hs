{-# LANGUAGE CPP #-}
-- | The few side effects that differ between the desktop build and the
--   browser build (compiled with GHC's JavaScript backend, see web/).
--
--   In the browser there is no real file system: files live in a virtual
--   file system (web/static/glue.js) that is pre-loaded with the "input"
--   folder and keeps the user's changes in the browser's local storage.
module Platform
    ( readFile
    , writeFile
    , doesFileExist
    , getDirectoryContents
    , promptLine
    , quitApp
    ) where

#if defined(javascript_HOST_ARCH)

import Prelude hiding (readFile, writeFile)
import GHC.JS.Prim
import System.IO.Error (mkIOError, doesNotExistErrorType)

foreign import javascript unsafe "((p) => BoS.fs.read(p))"          js_read   :: JSVal -> IO JSVal
foreign import javascript unsafe "((p, s) => BoS.fs.write(p, s))"   js_write  :: JSVal -> JSVal -> IO ()
foreign import javascript unsafe "((p) => BoS.fs.exists(p))"        js_exists :: JSVal -> IO Bool
foreign import javascript unsafe "((p) => BoS.fs.list(p))"          js_list   :: JSVal -> IO JSVal
foreign import javascript unsafe "((m) => BoS.prompt(m))"           js_prompt :: JSVal -> IO JSVal

readFile :: FilePath -> IO String
readFile path = do
    v <- js_read (toJSString path)
    if isNull v
        then ioError (mkIOError doesNotExistErrorType "openFile" Nothing (Just path))
        else return (fromJSString v)

writeFile :: FilePath -> String -> IO ()
writeFile path content = js_write (toJSString path) (toJSString content)

doesFileExist :: FilePath -> IO Bool
doesFileExist path = js_exists (toJSString path)

getDirectoryContents :: FilePath -> IO [FilePath]
getDirectoryContents path = do
    v <- js_list (toJSString path)
    if isNull v
        then ioError (mkIOError doesNotExistErrorType "getDirectoryContents" Nothing (Just path))
        else map fromJSString <$> fromJSArray v

-- | Ask the user for a line of text (a dialog box in the browser).
promptLine :: String -> IO String
promptLine msg = do
    putStrLn msg
    v <- js_prompt (toJSString msg)
    return (if isNull v then "" else fromJSString v)

-- | Quitting is not meaningful inside a web page, so it does nothing.
quitApp :: IO ()
quitApp = return ()

#else

import Prelude (IO, String, putStrLn, getLine, (>>), readFile, writeFile)
import System.Directory (doesFileExist, getDirectoryContents)
import System.Exit (exitSuccess)

-- | Ask the user for a line of text on the terminal.
promptLine :: String -> IO String
promptLine msg = putStrLn msg >> getLine

quitApp :: IO ()
quitApp = exitSuccess

#endif
