{-# LANGUAGE RecordWildCards #-}
module Foreign.JavaScript (
    -- * Synopsis
    -- | A JavaScript foreign function interface (FFI).
    --
    -- This module implements a web server that communicates with
    -- a web browser and allows you to execute arbitrary JavaScript code on it.
    --
    -- Note: This module is used internally by the "Graphics.UI.Threepenny"
    -- library, but the types are /not/ compatible.
    -- Use "Foreign.JavaScript" only if you want to roll your own
    -- interface to the web browser.

    -- * Server
    serve, Config(..), defaultConfig,
    Window, root,
    
    -- * JavaScript FFI
    ToJS(..), FromJS, JSFunction, JSObject,
    FFI, ffi, runFunction, callFunction,
    IsHandler, exportHandler, exportHandler', onDisconnect,
    debug,
    ) where

import qualified Data.Aeson                   as JSON
import           Foreign.JavaScript.EventLoop
import           Foreign.JavaScript.Marshal
import           Foreign.JavaScript.Server
import           Foreign.JavaScript.Types
import           Foreign.RemotePtr            as Foreign

{-----------------------------------------------------------------------------
    Server
------------------------------------------------------------------------------}
-- | Run a "Foreign.JavaScript" server.
serve
    :: Config               -- ^ Configuration options.
    -> (Window -> IO ())    -- ^ Initialization whenever a client connects.
    -> IO ()
serve config init = httpComm config (eventLoop init)

{-----------------------------------------------------------------------------
    JavaScript
------------------------------------------------------------------------------}
-- | Run a JavaScript function, but do not wait for a result.
runFunction :: Window -> JSFunction () -> IO ()
runFunction w f = runEval w (toCode f)

-- | Call a JavaScript function and wait for the result.
callFunction :: Window -> JSFunction a -> IO a
callFunction w f = do
    resultJS <- callEval w (toCode f)
    marshalResult f w resultJS

-- | Export a Haskell function as an event handler.
--
-- WARNING: The event handler will be garbage collected unless you
-- keep a reference to it /on the Haskell side/!
-- Registering it with a JavaScript function will generally /not/
-- keep it alive.
exportHandler :: IsHandler a => Window -> a -> IO JSObject
exportHandler w f = do
    g <- newHandler w (handle f w)
    h <- callFunction w $
        ffi "Haskell.newEvent(%1,%2)" g (convertArguments f)
    Foreign.addReachable h g
    return h

-- | Export a Haskell function as an event handler.
-- Does not do marshalling.
--
-- FIXME: Remove this version!
exportHandler' :: Window -> ([JSON.Value] -> IO ()) -> IO JSObject
exportHandler' w f = do
    g <- newHandler w f
    h <- callFunction w $
        ffi "Haskell.newEvent(%1)" g
    Foreign.addReachable h g
    return h

