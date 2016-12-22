{-# OPTIONS_GHC -Wall #-}

module Util where

import Data.Char

import qualified Data.List



(~.) = flip (.)

(~>) = flip ($)

(>~) = flip map
infix 8 >~


(#)::
    [t] -> Int -> t
--  alias for: `!!` ..for these most common cases, no need to `fold`
(#) (x:_) 0 = x
(#) (_:x:_) 1 = x
(#) (_:_:x:_) 2 = x
(#) (_:_:_:x:_) 3 = x
(#) (_:_:_:_:x:_) 4 = x
(#) (_:_:_:_:_:x:_) 5 = x
(#) (_:_:_:_:_:_:x:_) 6 = x
(#) (_:_:_:_:_:_:_:x:_) 7 = x
(#) (_:_:_:_:_:_:_:_:x:_) 8 = x
(#) (_:_:_:_:_:_:_:_:_:x:_) 9 = x
(#) l i = l!!i
infix 9 #



dropLast 0 l = l
dropLast 1 l = init l
dropLast n l = l~>take (l~>length - n)

endsWith :: (Eq t)=> [t]->[t]->Bool
endsWith = flip Data.List.isSuffixOf

startsWith :: (Eq t)=> [t]->[t]->Bool
startsWith = flip Data.List.isPrefixOf

join = Data.List.intercalate

trim :: String->String
trim = trimEnd . trimStart

trimEnd :: String->String
trimEnd = Data.List.dropWhileEnd Data.Char.isSpace

trimStart :: String->String
trimStart = Data.List.dropWhile Data.Char.isSpace


atOr::
    [t]-> Int-> t->
    t
--  value in `list` at `index`, or `defval`
atOr [] _ defval = defval
atOr (_:[]) 1 defval = defval
atOr (_:[]) 2 defval = defval
atOr (_:[]) 3 defval = defval
atOr (_:[]) 4 defval = defval
atOr (_:[]) 5 defval = defval
atOr (_:_:[]) 2 defval = defval
atOr (_:_:[]) 3 defval = defval
atOr (_:_:[]) 4 defval = defval
atOr (_:_:[]) 5 defval = defval
atOr (_:_:_:[]) 3 defval = defval
atOr (_:_:_:[]) 4 defval = defval
atOr (_:_:_:[]) 5 defval = defval
atOr (_:_:_:_:[]) 4 defval = defval
atOr (_:_:_:_:[]) 5 defval = defval
atOr (_:_:_:_:_:[]) 5 defval = defval
atOr list index defval = if list~>length > index then list#index else defval



indexOfSub _ [] = minBound::Int
indexOfSub sub str@(_:rest)
    |(zip sub str) ~> (all $ (==)~>uncurry)
        = 0
    |otherwise
        = 1+(indexOfSub sub rest)

lastIndexOfSub _ _ [] = minBound::Int
lastIndexOfSub rev sub str
    |(idx<0) = minBound::Int
    |(otherwise) = (str~>length)-(sub~>length)-idx
    where idx = indexOfSub (rev sub) (rev str)


splitBy delim = foldr peritem [[]] where
    peritem _ [] = []
    peritem item items@(item0:rest)
        |(item==delim) = []:items
        |(otherwise) = (item:item0):rest



splitUp::
    [String]-> String-> String->
    [(String,String)]
splitUp [] _ _ = []
splitUp _ "" _ = []
splitUp _ _ "" = []
splitUp beginners end str =
    (tolist pre "") ++ (tolist match beginner) ++
        --  only recurse if we have a good reason:
        (if nomatch && splitat==0 then (tolist rest "") else (splitUp beginners end rest))
    where
        pre = str ~> (take $ if nomatch then splitat else begpos)
        match = if nomatch then "" else str ~> (take endpos) ~> (drop $ begpos+beg0len)
        rest = str ~> (drop $ if nomatch then splitat else endposl)
        beginner = if nomatch then "" else str ~> (take endpos) ~> (drop begpos) ~> take beg0len
        nomatch = endpos<0 || begpos<0
        splitat = if nomatch && endpos>=0 then endposl else 0
        endpos = indexOfSub end str
        begpos = if endpos<0 then -1 else
            let bstr = str ~> (take endpos) ~> reverse
            in maximum $ beginners >~ \eachbeg
                -> lastIndexOfSub id eachbeg bstr
        endposl = endpos+(end~>length)
        beg0len = (beginners#0)~>length
        tolist val beg = if null val then [] else [(val,beg)]
