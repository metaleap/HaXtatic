{-# OPTIONS_GHC -Wall #-}

module ProjDefaults where

import qualified Files
import Util ( (>~) , (~>) )

import qualified Data.Char
import qualified System.FilePath


--  the basic default input files
data CoreFiles = CoreFiles {
    projectDefault :: Files.File,
    projectOverwrites :: Files.File,
    htmlTemplateMain :: Files.File,
    htmlTemplateBlok :: Files.File
}



loadOrCreate ctx projname projfilename custfilename =
    let projfilecontent = _proj projname
        setupname = setupName projfilename
    in Files.readOrCreate ctx custfilename "" ""
    >>= \ custfile
    -> Files.readOrCreate ctx projfilename "" projfilecontent
    >>= \ projfile
    -> Files.readOrCreate ctx (setupname++"-main.haxtmpl.html") "default-main.haxtmpl.html" _tmplmain
    >>= \ tmplmainfile
    -> Files.readOrCreate ctx (setupname++"-blok.haxtmpl.html") "default-blok.haxtmpl.html" _tmplblok
    >>= \ tmplblokfile
    -> return (CoreFiles projfile custfile tmplmainfile tmplblokfile)


rewriteTemplates corefiles tmplrewriter =
    let cfgmodtime = corefiles~>projectDefault~>Files.modTime~>max$
                        corefiles~>projectOverwrites~>Files.modTime
        tmplmodtime = cfgmodtime~>max$
                        corefiles~>htmlTemplateMain~>Files.modTime
        rewrite modtime rw file = Files.rewrite file modtime$
                            rw $file~>Files.content
    in CoreFiles {
        projectDefault = rewrite cfgmodtime id $corefiles~>projectDefault,
        projectOverwrites = rewrite cfgmodtime id $corefiles~>projectOverwrites,
        htmlTemplateMain = rewrite cfgmodtime tmplrewriter $corefiles~>htmlTemplateMain,
        htmlTemplateBlok = rewrite tmplmodtime tmplrewriter $corefiles~>htmlTemplateBlok
    }


setupName = System.FilePath.takeBaseName


dir_Out = "build"
dir_Static = "static"
dir_Pages = "pages"
dir_Posts = "posts"


_proj name =
    "T::SiteTitle: "++(name >~ Data.Char.toUpper)++"-Site\n"


_tmplblok =
    "<h1>{B{Title:_}}</h1>\n\
    \<p>{B{Desc:_}}</p>\n\
    \<p>\n\
    \For a neat overview listing of all your <code>pages/{B{Name:_}}.*.html</code> (and/or <code>pages/{B{Name:_}}/*.html</code>)\n\
    \articles on this page, check out the <code>{X{Listings}}</code> tag type in the HaXtatic docs.\n\
    \</p>"


_tmplmain =
    "<!DOCTYPE html><html lang=\"en\"><head>\n\
    \    <meta content=\"text/html;charset=utf-8\" http-equiv=\"Content-Type\" />\n\
    \    <title>{P{Title}} - {T{SiteTitle}}</title><style type=\"text/css\">\n\
    \        h3 { text-align: center; color: CaptionText; background: ActiveCaption; padding: 0.66em; letter-spacing: 0.33em; font-size: 1.44em; border-radius: 1em; border: 0.123em dotted Background; }\n\
    \        small { display: block; background-color: InfoBackground; color: InfoText; text-align: right; font-style: italic; padding: 0.3em; margin: 0.3em; }\n\
    \        body { font-family: sans-serif; background: ButtonFace; color: ButtonText; line-height: 1.44em; }\n\
    \        code { background-color: Highlight; color: HighlightText; }\n\
    \        h1 { color: Background; }\n\
    \        div { padding: 1.23em; margin: 1.23em; background-color: Window; color: WindowText; border: 0.123em ButtonShadow inset; }\n\
    \    </style><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n\
    \</head><body>\n\
    \    <h3>{T{SiteTitle}}</h3>\n\
    \    <div><!-- begin {P{FileName}} content generated from {P{OrigPath}} -->\n\n\n\
    \{P{Body}}\n\n\
    \    </div><!-- end of generated content -->\n\
    \    <hr/><small>Generated with <a href=\"http://github.com/HaXtatic\">{P{%demo_hax}}</a> on {P{Date}}</small>\n\
    \</body></html>"
