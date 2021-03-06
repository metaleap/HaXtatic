module X.HtmlLinks where

import Base
import qualified Lst
import qualified Str

import qualified Files
import qualified Html
import qualified Tmpl
import qualified X

import qualified System.FilePath


data Tag =
    Cfg {
        attr :: Str.Pairs,
        itemsFirst :: Str.Pairs,
        itemsLast :: Str.Pairs,
        wrapHref :: (String , String)
    }
    | Args {
        items :: Str.Pairs,
        attr :: Str.Pairs
    }
    deriving Read



registerX _ xreg =
    let
    renderer (maybectxpage , argstr) =
        if waitforpage then Nothing
            else Just$ cfgitemscombine allitems
        where
        allitems = htmlout (args-:attr ++ cfghtmlatts) (args-:items)
        args = X.tryParseArgs xreg argstr
                {-empty-} (Just Args { items = [], attr = [] })
                {-error-} (Args { items = ["#"=:""], attr = X.htmlErrAttsArgs (xreg , Str.teaser 23 argstr) })

        htmlout attribs argitems =
            argitems >>= (foreach Nothing attribs)
        foreach maybname attribs (('&':burl) , btext) =
            case maybectxpage of
                Nothing -> foreach maybname attribs (burl , btext)
                Just ctxpage ->
                    let blokname = ctxpage-:Tmpl.blokName
                    in if null blokname
                        then foreach maybname attribs (burl , btext)
                        else foreach (Just "") attribs (blokname++".html" , blokname)
        foreach maybname attribs (url,text) =
            Html.out cfg_htmltagname
                        (attribs >=~ (outattr maybectxpage))
                            [ Html.T "a" [  "" =: text,
                                            "id" =: "__hax_htmlLinks__" ++ (dstbaseuri -|= maybname),
                                            "href" =: cfgwraphref url] [] ]
            where
            dstlinkuri = Files.sanitizeUriRelPathForJoin url
            dstbaseuri = System.FilePath.takeBaseName dstlinkuri
            outattr (Just ctxpage) (('&':name) , value) =
                if pathmatch then Just (name , value) else Nothing
                where
                pathmatch = (has pagebfname && Lst.isPrefixed pagebfname (dstbaseuri++"."))
                                || (has pagediruri && Lst.isPrefixed dstlinkuri pagediruri) || (dstlinkuri == pagediruri)
                pagebfname = ((ctxpage-:Tmpl.pTagHandler) "fileBaseName") ~> ((++ ".") =|- "")
                pagediruri = ((ctxpage-:Tmpl.pTagHandler) "dirUri") ~> (Files.sanitizeUriRelPathForJoin =|- "")
            outattr _ other =
                Just other

        cfgitemscombine = (cfgitemspre++).(++cfgitemspost)
        cfgitemspre = htmlout cfghtmlatts $cfg-:itemsFirst
        cfgitemspost = htmlout cfghtmlatts $cfg-:itemsLast

        waitforpage =
            (X.hasNoPageContext maybectxpage) && (needpage4cfg || needpage4args)
            where
            needpage4args = (X.htmlAttsNeedPage $args-:attr) || (needpage $args-:attr)

    in X.EarlyOrWait renderer
    where


    needpage =
        any ispathconditional where
        ispathconditional (('&':_),_) = True
        ispathconditional _ = False
    needpage4cfg = X.htmlAttsNeedPage cfghtmlatts || needpage cfghtmlatts
    (cfg_htmltagname , cfg_parsestr) = xreg-:X.cfgSplitOnce
    cfghtmlatts =  cfg-:attr
    cfgwraphref = cfg-:wrapHref ~> \(w1,w2) -> (w1++).(++w2)
    cfg = X.tryParseCfg xreg cfg_parsestr (Just defcfg) errcfg where
        defcfg = Cfg { attr = [], itemsFirst = [], itemsLast = [], wrapHref = ("","") }
        errcfg = Cfg { attr = X.htmlErrAttsCfg xreg,
                        itemsFirst = ["#"=:""], itemsLast = [], wrapHref = ("","") }
