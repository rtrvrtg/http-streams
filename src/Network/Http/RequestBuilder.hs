--
-- HTTP client for use with io-streams
--
-- Copyright © 2012 Operational Dynamics Consulting, Pty Ltd
--
-- The code in this file, and the program it is a part of, is
-- made available to you by its authors as open source software:
-- you can redistribute it and/or modify it under the terms of
-- the BSD licence.
--

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Network.Http.RequestBuilder (
    RequestBuilder,
    buildRequest,
    http,
    setHostname,
    setAccept,
    ContentType,
    setContentType,
    setHeader
) where 

import Data.ByteString (ByteString)
import Data.ByteString.Char8 ()
import Control.Monad.State

import Network.Http.Types
import Network.Http.Connection

--
-- | The RequestBuilder monad allows you to abuse do notation to conveniently build up
--
newtype RequestBuilder a = RequestBuilder (State Request a)
  deriving (Monad, MonadState Request)

-- | Run a RequestBuilder, yielding a Request object you can use on the
-- given connection.
--
-- > q <- buildRequest c $ do
-- >     http POST "/api/v1/messages"
-- >     setContentType "application/json"
-- >     setAccept "text/html; q=1.0, */*; q=0.0"
-- >     setHeader "X-WhoDoneIt" "The Butler"
--
-- Obviously it's up to you to later actually /send/ JSON data.
--
buildRequest :: Connection -> RequestBuilder a -> IO Request
buildRequest c mm = do
    let (RequestBuilder s) = (mm)
    let h = cHost c
    let q = Request {
        qHost = h,
        qMethod = GET,
        qPath = "/",
        qHeaders = emptyHeaders
    }
    return $ execState s q


-- | Begin constructing a Request, starting with the request line.
--

http :: Method -> String -> RequestBuilder ()
http m p = do
    q <- get
    let h0 = qHeaders q
    let h1 = updateHeader h0 "User-Agent" "http-streams/0.1.1"
    let h2 = updateHeader h1 "Accept-Encoding" "gzip"

    put q {
        qMethod = m,
        qPath = p,
        qHeaders = h2
    }

--
-- | Set the [virtual] hostname for the request. In ordinary conditions
-- you won't need to call this, as the @Host:@ header is a required
-- header in HTTP 1.1 and is set directly from the name of the server
-- you connected to when calling 'Network.Http.Connection.openConnection'.
--
setHostname :: ByteString -> RequestBuilder ()
setHostname v = do
    q <- get
    put q {
        qHost = v
    }

-- | Set a generic header to be sent in the HTTP request.
setHeader :: ByteString -> ByteString -> RequestBuilder ()
setHeader k v = do
    q <- get
    let h0 = qHeaders q
    let h1 = updateHeader h0 k v
    put q {
        qHeaders = h1
    }

--
-- | Indicate the content type you are willing to receive in a reply
-- from the server. For more complex @Accept:@ headers, use
-- 'setAccept\''
--
setAccept :: ByteString -> RequestBuilder ()
setAccept v = do
    setHeader "Accept" v

type ContentType = ByteString

--
-- | Set the MIME type corresponding to the body of the request you are
-- sending. Defaults to @\"text\/plain\"@, so usually you need to set
-- this if 'PUT'ting.
--
setContentType :: ContentType -> RequestBuilder ()
setContentType v = do
    setHeader "Content-Type" v

