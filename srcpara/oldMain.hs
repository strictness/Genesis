{-# LANGUAGE BangPatterns #-}

import Rewrite
import Profiling
import GeneAlg
import Config
------
import GA
import Data.BitVector (BV, fromBits, toBits, size, ones)
import Data.Int
import System.Environment
import System.Process
import Control.DeepSeq

main :: IO () 
main = do 
-- move pop, gen, arch to config
  [projDir, pop, gen, arch] <- getArgs
  gmain projDir (read pop, read gen, read arch)

reps :: Int64
reps = runs

fitness :: FilePath -> BangVec -> IO Time
fitness projDir bangVec = do
  -- Read original
    let mainPath = projDir ++ "/Main.hs"
    prog  <- readFile mainPath
  -- Rewrite according to gene
    prog' <- editBangs mainPath (toBits bangVec) 
    rnf prog `seq` writeFile mainPath prog'
  -- Benchmark new
    buildProj projDir
    newTime <- benchmark projDir reps
  -- Recover original
    writeFile mainPath prog
    return newTime

{-
  -- Random seed; credit to Cyrus Cousins
    randomSeed <- (getStdRandom random)
  -- TODO parse CLI arguments here.  Need to determine runs and cliSeed.  
  -- Also parse options for genetic algorithm?
    let (useCliSeed, cliSeed) = (False, 0 :: Int)
        seed = if useCliSeed then cliSeed else randomSeed 
-}

gmain :: String -> (Int, Int, Int) -> IO ()
gmain projDir (pop, gens, arch) = do 
    putStrLn ">>>>>>>>>>>>>>>START OPTIMIZATION>>>>>>>>>>>>>>>"
    putStrLn $ "pop: " ++ show pop 
    putStrLn $ "gens: " ++ show gens
    putStrLn $ "arch: " ++ show arch 
  -- Configurations
    let cfg = GAConfig pop arch gens 
                       crossRate 
                       muteRate 
                       crossParam 
                       muteParam 
                       checkpoint 
                       rescoreArc
  -- Get base time and pool. 
  -- Obtain base time: compile & run
    buildProj projDir
    baseTime <- benchmark projDir reps
    let mainPath = projDir ++ "/Main.hs" -- TODO assuming only one file per project
    -- putStr "Basetime is: "; print baseTime
    putStr "Basetime is: "; print baseTime

  -- Pool: bit vector representing places to strict w/ all bits on
    prog <- readFile mainPath
    -- vecSize <- rnf prog `seq` placesToStrict mainPath
    bs <- readBangs mainPath
    let vecPool = rnf prog `seq` fromBits bs

  -- Do the evolution!
  -- Note: if either of the last two arguments is unused, just use () as a value
    es <- evolveVerbose g cfg vecPool (baseTime, fitness projDir)
    let e = snd $ head es :: BangVec
    prog' <- editBangs mainPath (toBits e)

  -- Write result
    --putStrLn $ "best entity (GA): " ++ (printBits $ toBits e)
    --putStrLn prog'
    writeFile mainPath prog
    putStrLn ">>>>>>>>>>>>>>FINISH OPTIMIZATION>>>>>>>>>>>>>>>"
