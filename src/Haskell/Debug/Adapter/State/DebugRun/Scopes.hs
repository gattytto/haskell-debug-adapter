{-# LANGUAGE MultiParamTypeClasses #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Haskell.Debug.Adapter.State.DebugRun.Scopes where

import Control.Monad.IO.Class
import qualified System.Log.Logger as L
import qualified Text.Read as R
import Control.Monad.Except

import qualified Haskell.DAP as DAP
import Haskell.Debug.Adapter.Type
import Haskell.Debug.Adapter.Constant
import qualified Haskell.Debug.Adapter.Utility as U
import qualified Haskell.Debug.Adapter.GHCi as P
import qualified Haskell.Debug.Adapter.State.Utility as SU


-- |
--  Any errors should be sent back as False result Response
--
instance StateActivityIF DebugRunStateData DAP.ScopesRequest where
  action _ (ScopesRequest req) = do
    liftIO $ L.debugM _LOG_APP $ "DebugRunState ScopesRequest called. " ++ show req
    app req

-- |
--
app :: DAP.ScopesRequest -> AppContext (Maybe StateTransit)
app req = flip catchError errHdl $ do

  let args = DAP.argumentsScopesRequest req
      dap = ":dap-scopes "
      cmd = dap ++ U.showDAP args
      dbg = dap ++ show args

  P.command cmd
  U.debugEV _LOG_APP dbg
  P.expectPmpt >>= SU.takeDapResult >>= dapHdl

  return Nothing

  where

    -- |
    --
    dapHdl :: String -> AppContext ()
    dapHdl str = case R.readEither str of
      Left err -> errHdl err >> return ()
      Right (Left err) -> errHdl err >> return ()
      Right (Right body) -> do
        resSeq <- U.getIncreasedResponseSequence
        let res = DAP.defaultScopesResponse {
                  DAP.seqScopesResponse = resSeq
                , DAP.request_seqScopesResponse = DAP.seqScopesRequest req
                , DAP.successScopesResponse = True
                , DAP.bodyScopesResponse = body
                }

        U.addResponse $ ScopesResponse res

    -- |
    --
    errHdl :: String -> AppContext (Maybe StateTransit)
    errHdl msg = do
      liftIO $ L.errorM _LOG_APP msg
      resSeq <- U.getIncreasedResponseSequence
      let res = DAP.defaultScopesResponse {
                DAP.seqScopesResponse = resSeq
              , DAP.request_seqScopesResponse = DAP.seqScopesRequest req
              , DAP.successScopesResponse = False
              , DAP.messageScopesResponse = msg
              }

      U.addResponse $ ScopesResponse res
      return Nothing

