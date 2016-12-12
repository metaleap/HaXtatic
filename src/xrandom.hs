module XRandom where

import Html
import Pages
import Util


type Item = ((String,String),String)
data Cfg = Cfg { cssLink :: String, items :: [Item] } deriving (Read)


rand page =
    (abs $ nowint * year+(l fn)-lb) * (abs$day+month-nowint) * (lt+lb*nowint) * (nowint+(l$fn!!3)+(l$fn!!4)) where
        nowint = Pages.now page ; l = length ; fn = Pages.fname page
        year = Util.readInt $ Util.fnYear fn ; month = Util.readInt $ Util.fnMonth fn ; day = Util.readInt $ Util.fnDay fn
        lt = l (Pages.titles page) ; lb = l (Pages.body page)


ext tagname cfg =
    Pages.X [ Pages.Tmpl tagname apply, Pages.Tmpl tlink apply ] where
        tlink = tagname++"-Link"
        apply subtag _ page
            | subtag==tlink = [ Html.out "a" [("", fst $ fst item),("href",snd $ fst item),("class",cssLink cfg)] [] ]
            | otherwise = [snd item]
            where item = (items cfg)!!index ; index = mod (rand page) $ length (items cfg)