{-# OPTIONS_GHC -Wall #-}

module Build where

import qualified Bloks
import qualified Defaults
import qualified Files
import qualified Proj
import qualified ProjCfg
import qualified Util
import Util ( (~:) , (>~) , (>>~) , (>>|) , (#) , (~.) )

import qualified System.Directory
import System.FilePath ( (</>) )


data Plan = Plan {
    outFilesAtom :: [OutFileInfo],
    outFilesPage :: [OutFileInfo],
    outFilesStatic :: [OutFileInfo],
    numOutFilesTotal :: Int,
    numSkippedStatic :: Int,
    numSkippedPages :: Int,
    numSkippedAtoms :: Int
}

data OutFileInfo = NoOutFile | OutFileInfo {
    relPath :: FilePath,
    outPathBuild :: FilePath,
    outPathDeploy :: FilePath,
    customDate :: [String],
    srcFile :: Files.File
} deriving (Eq)



copyAllOutputsToDeploy buildplan =
    let perfile file =
            let srcfilepath = file~:outPathBuild
            in System.Directory.doesFileExist srcfilepath >>= \isfile
            -> if isfile
                then Files.copyTo srcfilepath [file~:outPathDeploy]
                else putStrLn ("\t!?\tMissing: `"++srcfilepath++"`")
    in (buildplan~:outFilesStatic) >>~ perfile
    >> (buildplan~:outFilesPage) >>~ perfile
    >> (buildplan~:outFilesAtom) >>~ perfile
    >> return ()



copyStaticFiles buildplan =
    (buildplan~:outFilesStatic) >>~ perfile where
        perfile file =
            Files.copyTo (file~:srcFile~:Files.path) [file~:outPathBuild]



_createIndexHtmlIfNoContentPages ctxmain ctxproj numpagesrcfiles =
    if numpagesrcfiles > 0
        then return NoOutFile
        else let
            sitename = ctxproj~:Proj.projName
            dirpagesrel = (ctxproj~:Proj.setup~:Proj.cfg~:ProjCfg.processPages~:ProjCfg.dirs)#0
            dirbuild = ctxproj~:Proj.dirPathBuild
            htmltemplatemain = ctxproj~:Proj.coreFiles~:Defaults.htmlTemplateMain
        in putStrLn ("\t->\tNo content-source files whatsoever.. making one for you:")
        >> Defaults.writeDefaultIndexHtml
            ctxmain sitename dirpagesrel dirbuild htmltemplatemain
        >>= \ (outfile , outfilerel , pathfinal)
        -> return OutFileInfo {
                        relPath = outfilerel,
                        outPathBuild = pathfinal,
                        outPathDeploy = Util.unlessNullOp (ctxproj~:Proj.dirPathDeploy) (</> outfilerel),
                        customDate = [],
                        srcFile = outfile
                    }



plan ctxmain ctxproj =
    let projsetup = ctxproj~:Proj.setup
        cfg = projsetup~:Proj.cfg
        cfgprocstatic = cfg~:ProjCfg.processStatic
        cfgprocpages = cfg~:ProjCfg.processPages
        cfgprocposts = cfg~:ProjCfg.processPosts
        listallfiles = Files.listAllFiles $ctxproj~:Proj.dirPath
        modtimeproj = ctxproj~:Proj.coreFiles~:Defaults.projectDefault~:Files.modTime
        modtimetmplmain = ctxproj~:Proj.coreFiles~:Defaults.htmlTemplateMain~:Files.modTime
        modtimetmplblok = ctxproj~:Proj.coreFiles~:Defaults.htmlTemplateBlok~:Files.modTime
    in listallfiles (cfgprocstatic~:ProjCfg.dirs) id >>= \allstaticfiles
    -> listallfiles (cfgprocposts~:ProjCfg.dirs) (max modtimeproj) >>= \allpostsfiles
    -> listallfiles (cfgprocpages~:ProjCfg.dirs) (max modtimetmplmain) >>= \allpagesfiles
    -> _createIndexHtmlIfNoContentPages ctxmain ctxproj (allpagesfiles~:length) >>= \ defaultpage
    -> let
        (dynpages,dynatoms) = Bloks.buildPlan (modtimeproj,modtimetmplblok) allpagesfiles $projsetup~:Proj.bloks
        outfileinfostd = _outFileInfo ctxproj id
        outfileinfoatom func = _outFileInfo ctxproj $(Files.ensureFileExt True ".atom")~.func
        outfileinfopost = outfileinfoatom func where
            func|(null relpathpostatoms)= id                                -- no custom dir for posts-derived atoms set up
                |(relpathpostatoms==Defaults.dir_PostAtoms_None)= const ""  -- dont generate atoms -> force "" to discard in _filterOutFiles
                |(otherwise)= (relpathpostatoms </>)                        -- prepend user-specified rel dir to atom out-file name
            relpathpostatoms = cfg~:ProjCfg.relPathPostAtoms
        allatoms = (allpostsfiles>~outfileinfopost) ++ (dynatoms>~(outfileinfoatom id))
        allstatics = allstaticfiles >~ outfileinfostd
        allpagesalmost = (allpagesfiles++dynpages) >~ outfileinfostd
        allpages = if defaultpage==NoOutFile
                    then allpagesalmost else
                        defaultpage:allpagesalmost
    in _filterOutFiles allstatics cfgprocstatic >>= \outstatics
    -> _filterOutFiles allpages cfgprocpages >>= \outpages
    -> _filterOutFiles allatoms cfgprocposts >>= \outatoms
    -> let buildplan = Plan {
                outFilesAtom = outatoms,
                outFilesPage = outpages,
                outFilesStatic = outstatics,
                numOutFilesTotal = outstatics~:length + outpages~:length + outatoms~:length,
                numSkippedStatic = allstatics~:length - outstatics~:length,
                numSkippedPages = allpages~:length - outpages~:length,
                numSkippedAtoms = allatoms~:length - outatoms~:length
            }
    in return buildplan



_outFileInfo ctxproj relpather (relpath,file) =
    let relpathnu = relpather relpath
    in if null relpathnu
        then NoOutFile
        else OutFileInfo {
            relPath = relpathnu,
            outPathBuild = ctxproj~:Proj.dirPathBuild </> relpathnu,
            outPathDeploy = Util.unlessNullOp (ctxproj~:Proj.dirPathDeploy) (</> relpathnu),
            customDate = [],
            srcFile = file
        }



_filterOutFiles fileinfos cfgproc =
    fileinfos >>| shouldbuildfile where
        skipall = ["*"]== cfgproc~:ProjCfg.skip
        forceall = ["*"]== cfgproc~:ProjCfg.force
        shouldbuildfile NoOutFile =
            return False
        shouldbuildfile fileinfo =
            let skipthis = (not skipall) && (matchesany $cfgproc~:ProjCfg.skip)
                forcethis = (not forceall) && (matchesany $cfgproc~:ProjCfg.force)
                matchesany = Files.simpleFileNameMatchAny $fileinfo~:relPath
                outfilepath = fileinfo~:outPathBuild
            in if (forceall && not skipthis) || forcethis
                then return True else
                if (skipall && not forcethis) || skipthis
                    then return False else
                    System.Directory.doesFileExist outfilepath >>= \ isfile
                    -> if not isfile then return True else
                        System.Directory.getModificationTime outfilepath >>= \ outfilemodtime
                        -> return ((fileinfo~:srcFile~:Files.modTime) > outfilemodtime)
