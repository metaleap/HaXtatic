{-# OPTIONS_GHC -Wall #-}
module XSnippets where

import qualified Pages
import qualified Util


type Args = (String,Util.KeyVals)
type Cfg = Util.KeyVals


ext::
    String-> Util.KeyVals->
    Pages.X
ext tagname cfg = Pages.X [ Pages.Tmpl tagname apply ] where
    apply _ argstr _ =
        [ Util.replaceIn (Util.keyVal cfg (fst args) "") vars ] where
            args = (read ("("++argstr++")") :: Args)
            vars = map (\(k,v) -> ("{%"++k++"}",v)) $ snd args