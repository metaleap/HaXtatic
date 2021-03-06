module Defaults where

import Base
import qualified Lst

import qualified Files
import qualified Util

import qualified Data.Char
import qualified Data.Time.Format
import qualified System.FilePath
import System.FilePath ( (</>) )


--  the basic default input files
data Files
    = DefaultFiles {
        projectDefault :: Files.File,
        projectOverwrites :: [Files.File],
        htmlTemplateMain :: Files.File,
        htmlSnippets :: [Files.File]
    }



loadOrCreate ctxmain projname projfilename custfilenames =
    let projfiledefcontent = _proj projname
        setupname = ctxmain-:Files.setupName
        relpathtmplmain = "tmpl" </> (setupname++ ".haxtmpl.html")
        relpathtmplmain' = "tmpl" </> (fileName_Pref ".haxtmpl.html")
        relpathsnipblok = "tmpl" </> ("_hax_blokindex.haxsnip.html")
        foreach relfilepath =
            Files.readOrDefault False ctxmain relfilepath "" ""
    in Files.readOrDefault True ctxmain projfilename fileName_Proj projfiledefcontent
    >>= \projfile
    -> Files.readOrDefault True ctxmain relpathtmplmain relpathtmplmain' _tmpl_html_main
    >>= \tmplmainfile
    -> Files.readOrDefault True ctxmain relpathsnipblok "" _tmpl_html_blok
    *> Files.listAllFiles (ctxmain-:Files.dirPath) ["tmpl"] id >>= \tmplfileinfos
    -> let
        snipfileinfos = tmplfileinfos ~|(Lst.isSuffixOf ".haxsnip.html").fst
        snipmodtime = if null snipfileinfos then Util.dateTime0 else maximum$ snipfileinfos>~(snd ~. Files.modTime)
    in (snipfileinfos>~(("tmpl" </>).fst)   ) >>~ foreach
    >>= \snipfiles
    -> custfilenames >>~ foreach
    >>= \custfiles
    -> let
        custmodtime = max snipmodtime (if null custfiles then Util.dateTime0 else maximum $custfiles>~Files.modTime)
        cfgmodtime = max custmodtime (projfile-:Files.modTime)
        tmplmodtime = max cfgmodtime (tmplmainfile-:Files.modTime)
        redated cmpmodtime file
            = file { Files.modTime = max cmpmodtime $file-:Files.modTime }
        redatedcfg = redated cfgmodtime
        redatedtmpl = redated tmplmodtime
    in pure DefaultFiles {
        projectDefault = projfile~>redatedcfg,
        projectOverwrites = custfiles>~redatedcfg,
        htmlTemplateMain = tmplmainfile~>redatedtmpl,
        htmlSnippets = snipfiles>~redatedcfg
    }




writeDefaultIndexHtml ctxmain projname dirpagesrel dirbuild htmltemplatemain =
    let
        dircur = ctxmain-:Files.curDir
        dirproj = ctxmain-:Files.dirPath
        dirpages = dirproj </> dirpagesrel
        dstfilepath = dirpages </> fileName_IndexHtml
        dstfpathrel = dirpagesrel </> fileName_IndexHtml
        pathtmpl = htmltemplatemain-:Files.path
        pathfinal = dirbuild </> fileName_IndexHtml
        dstfile = Files.FileInfo dstfilepath (ctxmain-:Files.nowTime)
        filecontent = pure ( _index_html
                                    dircur projname dirproj dirpages dstfilepath pathtmpl pathfinal,
                                (dstfile , fileName_IndexHtml , pathfinal) )
    in Files.writeTo dstfilepath dstfpathrel filecontent


setupName = System.FilePath.takeBaseName



dateTimeFormat = Data.Time.Format.iso8601DateFormat Nothing
dir_Out = "build"
dir_Deploy =""
dir_Static = "static"
dir_Pages = "pages"
dir_Posts = "posts"
dir_PostAtoms = dir_PostAtoms_None
dir_PostAtoms_None = ":"
fileName_IndexHtml = "index.html"
fileName_Proj = fileName_Pref ".haxproj"
fileName_Pref = ("default"++)


_proj name =
    "|T|SiteTitle:\n\t" ++(name >~ Data.Char.toUpper)++ "-Site"


_index_html dircur sitename dirproj dirpages pathpage pathtmpl pathfinal =
    let l = 1+(length dirproj) ; x s = "{P|demo_dirpath|}<b>" ++(drop l s)++ "</b>" in
        "<h1>Greetings..</h1>\n\
            \{%P|demo_hax=<b>HaXtatic</b>|%}\n\
            \{%P|demo_dirpath=" ++dirproj++[System.FilePath.pathSeparator]++ "|%}\n\
            \<p>Looks like for now I&apos;m the home page of your static site <code>" ++sitename++ "</code>! How did this come about?</p>\n\
            \<p>When you ran {P|demo_hax|} from <code>" ++dircur++ "</code>, specifying project-directory <code><b>{P|demo_dirpath|}</b></code>:</p>\n\
            \<ul>\n\
            \    <li>I was generated at <code>" ++(x pathfinal)++ "</code> by</li>\n\
            \    <li>..applying the <code>" ++(x pathtmpl)++ "</code> template (ready for your tinkering)</li>\n\
            \    <li>..to my &apos;<i>content source page</i>&apos; stored at <code>" ++(x pathpage)++ "</code> (dito)</li>\n\
            \    <li>..which in turn {P|demo_hax|} pre-created for you just-beforehand &mdash; <b>but <i>only</i></b> because <code>" ++(x dirpages)++[System.FilePath.pathSeparator]++ "</code> was totally devoid of any files: otherwise it won&apos;t ever write to your content source directories.</li>\n\
            \</ul>"


_tmpl_html_blok =
    "vars = [(\"bname\",\"\")],\n\
    \content=>\n\
    \<h1>{B|title:{%bname%}|}</h1>\n\
    \<p>{B|desc:{%bname%}|}</p>\n\
    \<p>\n\
    \An overview listing of all your <code>pages/{%bname%}.*.html</code> (and/or <code>pages/{%bname%}/*.html</code>)\n\
    \might fit well on this page! Check out HaXtatic Docs / Basics / Bloks for details.\n\
    \</p>"


_tmpl_html_main =
    "<!DOCTYPE html><html lang=\"en\"><head>\n\
    \    <meta content=\"text/html;charset=utf-8\" http-equiv=\"Content-Type\" />\n\
    \    <title>{P|title|} - {T|SiteTitle|}</title><style type=\"text/css\">\n\
    \        h3 { text-align: center; color: CaptionText; background: ActiveCaption; padding: 0.66em; letter-spacing: 0.33em; font-size: 1.44em; border-radius: 1em; border: 0.123em dotted Background; }\n\
    \        small { display: block; background-color: InfoBackground; color: InfoText; text-align: right; font-style: italic; padding: 0.3em; margin: 0.3em; }\n\
    \        body { font-family: sans-serif; background: ButtonFace; color: ButtonText; line-height: 1.44em; }\n\
    \        code { background-color: Highlight; color: HighlightText; }\n\
    \        h1 { color: Background; }\n\
    \        div { padding: 1.23em; margin: 1.23em; background-color: Window; color: WindowText; border: 0.123em ButtonShadow inset; }\n\
    \    </style><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n\
    \</head><body>\n\
    \    <h3>{T|SiteTitle|}</h3>\n\
    \    <div><!-- begin {P|fileUri|} content generated from {P|srcPath|} -->\n\n\n\
    \{P|:content:|}\n\n\
    \    </div><!-- end of generated content -->\n\
    \    <hr/><small>Generated with <a href=\"http://metaleap.github.io/haxtatic\">{P|demo_hax|}</a> on {P|date|}</small>\n\
    \</body></html>"
