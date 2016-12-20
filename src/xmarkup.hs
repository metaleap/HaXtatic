{-# OPTIONS_GHC -Wall #-}
module XMarkup where

import Pages


{-
    simply rewrites occurences such as `{X{C: foo}}` or `{X{BQ: bar}}`
    out into markup such as `<code>foo</code>` or `<blockquote>bar</blockquote>`
    with one-off single-line definitions in `haxtatic.config` such as:
    `X:Markup:C:code` and `X:Markup:BQ:blockquote` etc.
    Not useful or advisable for 'all markup everywhere' (no attributes for once),
    just convenient for those certain elements of verbose repetetive clutter.
-}
ext::
    String-> String->
    X
ext tname fulltag = Pages.X [ Pages.Tmpl tname apply ] where
    apply _ argstr _ = [ "<"++fulltag++">"++argstr++"</"++fulltag++">" ]
    --  could also do instead:
    --      Html.out fulltag [("",argstr)] []
    --  but let's keep this as a lean template showcasing the simplicity of custom-coded X-tag providers
