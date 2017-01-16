{-# OPTIONS_GHC -Wall -fno-warn-missing-signatures -fno-warn-type-defaults #-}
module Pages where

import Base
import qualified Bloks
import qualified Build
import qualified Files
import qualified Html
import qualified Posts
import qualified Proj
import qualified ProjC
import qualified Tmpl
import qualified Util

import Control.Applicative ( (<|>) )
import qualified Data.List
import qualified Data.Time.Clock
import qualified System.FilePath



processAll ctxmain ctxproj buildplan =
    let filenameexts = buildplan-:Build.outPages >~ filenameext
        filenameext = Build.srcFile ~. Files.path ~. System.FilePath.takeExtension
        ctxtmpl = ctxproj-:Proj.setup-:Proj.ctxTmpl
        ctxbuildinitial = Posts.BuildContext (const Nothing) (buildplan-:Build.allPagesFiles)
                            (ctxproj-:Proj.setup-:Proj.bloks) (ctxproj-:Proj.setup-:Proj.posts) cfgproj
        cfgproj = ctxproj-:Proj.setup-:Proj.cfg

    in Tmpl.loadAll ctxmain ctxtmpl (ctxproj-:Proj.coreFiles)
                    filenameexts (cfgproj-:ProjC.htmlEquivExts) >>= \tmplfinder
    -> let
        processpage done [] =
            return done
        processpage (prevwarns , ctxbuildprev) (thisjob:morejobs) =
            processPage ctxmain ctxbuildprev ctxtmpl tmplfinder thisjob
            >>= \(maybewarning , ctxbuildnext)
            -> let nextwarns = case maybewarning of Nothing -> prevwarns ; Just w -> w:prevwarns
            in processpage (nextwarns , ctxbuildnext) morejobs

    in processpage ([] , ctxbuildinitial) (buildplan-:Build.outPages)



processPage ctxmain ctxbuild ctxtmpl tmplfinder outjob =
    Files.writeTo dstfilepath (outjob-:Build.relPath) processcontent
    >>= \(outsrc , ctxpage , mismatches)
    -> Tmpl.warnIfTagMismatches ctxmain srcfilepath mismatches
    >> let
        outjobsrcfilepath = outjob-:Build.srcFile-:Files.path
        lookupcachedpagerender = ctxbuild-:Posts.lookupCachedPageRender
        cachelookup filepath
            |(filepath==outjobsrcfilepath)= Just ctxpage
            |(otherwise)= lookupcachedpagerender filepath
        i1 = Util.indexOfSub outsrc "|!}" ; i2 = Util.indexOfSub outsrc "{!|"
    in return ( (i2 < 0 || i1 < i2) |? Nothing |! (Just$ outjob-:Build.relPath),
                    Posts.BuildContext cachelookup (ctxbuild-:Posts.allPagesFiles)
                            (ctxbuild-:Posts.projBloks) (ctxbuild-:Posts.projPosts) (ctxbuild-:Posts.projCfg) )

    where
    dstfilepath = outjob-:Build.outPathBuild
    srcfilepath = outjob-:Build.srcFile-:Files.path

    loadsrccontent =
        let blokindexname = Bloks.blokNameFromIndexPagePath srcfilepath
        in if has blokindexname
            then return ((0,0) , "{X|_hax_blokindex: vars=[(\"bname\",\""++blokindexname++"\")], content=\"\" |}")
            else readFile srcfilepath >>= \rawsrc
                    -> return (Tmpl.tagMismatches rawsrc , rawsrc)

    processcontent =
        Data.Time.Clock.getCurrentTime >>= \nowtime
        -> loadsrccontent >>= \(mismatches , pagesrcraw)
        -> let
            randseed' = (Util.dtInts nowtime)
                            ++ (Util.dtInts $outjob-:Build.srcFile-:Files.modTime)
                                ++ [ length $ctxbuild-:Posts.allPagesFiles , pagesrcraw~>length ]
            ctxpage htmlsrc thandler = Tmpl.PageContext {
                                            Tmpl.blokName = outjob-:Build.blokName,
                                            Tmpl.pTagHandler = thandler,
                                            Tmpl.pVars = pagevars,
                                            Tmpl.pDate = pagedate,
                                            Tmpl.htmlInners = htmlinners htmlsrc,
                                            Tmpl.htmlInner1st = htmlinner1st htmlsrc,
                                            Tmpl.tmpl = tmpl,
                                            Tmpl.cachedRenderSansTmpl = pagesrcproc,
                                            Tmpl.lookupCachedPageRender = ctxbuild-:Posts.lookupCachedPageRender,
                                            Tmpl.allPagesFiles = ctxbuild-:Posts.allPagesFiles,
                                            Tmpl.randSeed = randseed' >~ ((+) (pagesrcraw~>length * randseed'@!1))
                                        }
            ctxpageprep = ctxpage pagesrcraw (taghandler ctxpageprep)
            ctxpageproc = ctxpage pagesrcproc (taghandler ctxpageproc)
            (pagevars , pagedate , pagesrcchunks) = pageVars (ctxbuild-:Posts.projCfg) pagesrcraw $outjob-:Build.contentDate
            taghandler pagectx = tagHandler (ctxbuild-:Posts.projCfg) pagectx ctxtmpl outjob
            tmpl = tmplfinder$ System.FilePath.takeExtension dstfilepath
            pagesrcproc = Tmpl.processSrcFully ctxtmpl (Just ctxpageprep)
                            (null pagevars |? pagesrcraw |! (concat pagesrcchunks))
            applied = Tmpl.apply tmpl ctxpageproc pagesrcproc
            --  annoyingly, thanks to nested-nestings there may *still* be fresh/pending haXtags,
            --  now that we did only-the-page-src AND the so-far unprocessed {P|'s in tmpl, so once more with feeling:
            outsrc = Tmpl.processSrcFully ctxtmpl (Just ctxpageproc) applied
            htmlinners htmlsrc tagname =
                Html.findInnerContentOfTags tagname htmlsrc
            htmlinner1st htmlsrc tagname defval =
                defval -|= (htmlinners htmlsrc tagname)@?0

        in return (outsrc , (outsrc , ctxpageproc , mismatches))



pageVars cfgproj pagesrc contentdate =
    (pagevars , pagedate , pagesrcchunks)
    where
    chunks = (Util.splitUp Util.trim ["{%P|"] "|%}" pagesrc)
    pagevars = chunks>=~foreach
    pvardates = pagevars>=~maybedate
    pagedate = contentdate -|= pvardates@?0
    pagesrcchunks = (chunks ~|null.snd) >~ fst -- ~|is

    foreach (pvarstr , "{%P|") =
        let nameandval = (Util.splitOn1st '=' pvarstr) ~> Util.bothTrim
        in Just nameandval
    foreach _ =
        Nothing

    maybedate (varname,varval) =
        let (dtpref , dtfname) = Util.bothTrim (Util.splitOn1st ':' varname)
        in if dtpref /= "date" then Nothing
            else ProjC.dtStr2Utc cfgproj dtfname varval



tagHandler cfgproj ctxpage ctxtmpl outjob ptagcontent
    | Util.startsWith ptagcontent "X|"
        = Just$ Tmpl.processXtagDelayed xtaghandler (drop 2 ptagcontent)
    | ptagcontent == "date"
        = fordate "" contentdate
    | dtfprefix == "date"
        = fordate dtfname contentdate
    | otherwise
        = (Data.List.lookup ptagcontent (ctxpage-:Tmpl.pVars)) <|> (for ptagcontent)

    where
    xtaghandler = (ctxtmpl-:Tmpl.xTagHandler) (Just ctxpage)
    contentdate = ctxpage-:Tmpl.pDate
    (dtfprefix,dtfname) = Util.bothTrim (Util.splitOn1st ':' ptagcontent)
    fordate dtfn datetime =
        Just$ ProjC.dtUtc2Str cfgproj dtfn datetime
    for ('/':path) =
        let newrelpath = take (Util.count '/' (outjob-:Build.relPathSlashes)) infinity
            infinity = iterate (++ "../") "../"
        in Just$ ( null newrelpath |? path |! ((last newrelpath) ++ path) )
    for name =
        let (dtfp,dtfn) = Util.bothTrim (Util.splitOn1st ':' name)
        in if dtfp=="srcTime"
            then fordate dtfn (outjob-:Build.srcFile-:Files.modTime)
            else Data.List.lookup name pvals
    pvals = let reldir = Util.butNot "." "" (System.FilePath.takeDirectory$ outjob-:Build.relPath)
                reldir' = Util.butNot "." "" (System.FilePath.takeDirectory$ outjob-:Build.relPathSlashes)
            in  [ "title" =: (ctxpage-:Tmpl.htmlInner1st) "h1" ""
                , "fileBaseName" =: (System.FilePath.takeBaseName$ outjob-:Build.relPath)
                , "fileName" =: (System.FilePath.takeFileName$ outjob-:Build.relPath)
                , "fileUri" =: '/':(outjob-:Build.relPathSlashes)
                , "filePath" =: outjob-:Build.relPath
                , "dirName" =: Util.ifIs reldir System.FilePath.takeFileName
                , "dirUri" =: '/':(Util.ifIs reldir' (++"/"))
                , "dirPath" =: Util.ifIs reldir (++[System.FilePath.pathSeparator])
                , "srcPath" =: outjob-:Build.srcFile-:Files.path
                , "outBuild" =: outjob-:Build.outPathBuild
                , "outDeploy" =: outjob-:Build.outPathDeploy
                ]



writeSitemapXml ctxproj buildplan =
    let xmlsitemapfull xmlinneritems =
            "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n\
            \<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd\">\n\
            \    "++(concat xmlinneritems)++"\n\
            \</urlset>"
        xmlsitemapitem domain relpath moddate priority =
            "<url>\n\
            \        <loc>http://"++domain++"/"++relpath++"</loc>\n\
            \        <lastmod>"++(ProjC.dtUtc2Str (ctxproj-:Proj.setup-:Proj.cfg) "" moddate)++"</lastmod>\n\
            \        <priority>"++(take 3 (show priority))++"</priority>\n\
            \    </url>"
        foreach pageinfo =
            skip |? "" |!
                xmlsitemapitem (ctxproj-:Proj.domainName) relpath (pageinfo-:Build.contentDate) priorel
            where
            maybeblok = Bloks.blokByName (ctxproj-:Proj.setup-:Proj.bloks) (pageinfo-:Build.blokName)
            skip = case maybeblok of
                    Just blok -> not$ blok-:Bloks.inSitemap
                    Nothing -> False
            relpath = pageinfo-:Build.relPathSlashes
            priorel = max 0.0 (priobase - priodown)

            priodown = 0.1 * (fromIntegral$ (Util.count '/' relpath) + (Util.count '.' relpath) - 1) :: Float
            priobase
                | relpath=="index.html" || relpath=="index.htm"
                = 1.0
                | Util.endsWith relpath "/index.html" || Util.endsWith relpath "/index.htm"
                = 0.88
                | otherwise
                = 0.66
        (outjob , pagefileinfos) = buildplan-:Build.siteMap
        xmlitems = (pagefileinfos >~foreach)
        xmloutput = return (xmlsitemapfull xmlitems , ())
    in if outjob == Build.NoOutput
        then return ()
        else Files.writeTo
                (outjob-:Build.outPathBuild)
                (outjob-:Build.relPath)
                xmloutput
            >> return ()