{-# OPTIONS_GHC -Wall -fno-warn-missing-signatures -fno-warn-type-defaults #-}
module X.PageAnchors where

import Base
import qualified Html
import qualified Tmpl
import qualified Util
import qualified X


data Tag
    = Cfg {
        considerEmpty :: Int,
        htmlIfEmpty :: String
    }
    | Args {
        htmlAtts :: Util.StringPairs
    }
    deriving Read



registerX _ xreg =
    let
    renderer (Just pagectx , argstr)
        | ((cfg-:considerEmpty) == (maxBound::Int))
            || null tagmatches
            || (tagmatches~>length) <= (cfg-:considerEmpty)
        = Just$ cfg-:htmlIfEmpty
        | otherwise
        = Just$ concat$ tagmatches>~foreach
        where

        tagmatches = (pagectx-:Tmpl.htmlInners) cfg_gathertagname
        foreach tagmatch =
            Html.out args_tagname (args-:htmlAtts)
                        [Html.T "a" ["" =: tagmatch , "href" =: "#"++(Html.escape tagmatch)] []]
        (args_tagname , args_parsestr) = Util.splitOn1st_ ':' argstr
        args = X.tryParseArgs xreg args_parsestr
                (Just Args { htmlAtts = [] })
                (Args { htmlAtts = X.htmlErrAttsArgs (xreg , Util.excerpt 23 argstr) })

    renderer _ =
        Nothing

    in X.WaitForPage renderer
    where

    (cfg_gathertagname , cfg_parsestr ) = xreg-:X.cfgSplitOnce
    cfg = X.tryParseCfg xreg cfg_parsestr Nothing errcfg where
        errcfg = Cfg { htmlIfEmpty = X.htmlErr$ X.clarifyParseCfgError xreg , considerEmpty = maxBound::Int }
