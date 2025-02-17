import qualified Data.ByteString.Lazy.Char8 as L
import GenerationalGC
import EtParser
import System.Environment (getArgs)
import qualified Data.IntSet as S
import qualified Data.IntMap as M
import qualified Graph as G
import qualified Data.List as List
import Machine
import qualified Codec.Compression.GZip as GZip


gb = 1024*1024*1024
mb = 1024*1024

{--initMachine = Machine {
			       nursery = S.empty
                             , nursery_size = 0
                             , nursery_limit = 4*mb
                             , rem_set = S.empty
                             , heap_size = 0
                             , heap_limit = 4*gb --4 GB
                             , heap = G.empty
                             , roots = S.empty
                             , stacks = M.empty
                             , alloc = 0
                             , chunks = []
                             , marks = 0
            	           } --}

simulate::[Record]->(Machine)
simulate rs = List.foldl' simStep initMachine{heap_limit=4000*Machine.mb} rs


main = do
	 args <- getArgs
	 contents <- if(List.isSuffixOf ".gz" (args !! 0)) then
		       fmap GZip.decompress $ L.readFile (args !! 0)
		     else
			L.readFile (args !! 0)

	 let m = simulate initMachine $! map (f.readRecord) $! L.lines contents
	 let survivalRate = (fromIntegral $ promotions m) / (fromIntegral $ alloc_obj m)

	 putStrLn "GcGen Sim"
	 putStrLn $   "Input trace:" ++ (args !! 0)
	 putStrLn $ "Nursery Limit: " ++ (show $ nursery_limit m) ++ " bytes"
	 putStrLn $ "Heap Limit: " ++ (show $ heap_limit m) ++ " bytes"
	 putStrLn $ "Nursery Collections: " ++ (show $ nursery_collections m)
	 putStrLn $ "Whole heap collections: " ++ (show $ whole_heap_collections m)
	 putStrLn $! "Allocations : " ++ show (alloc_obj m) ++ " Marks: " ++ show (marks m) ++ " Promotions: " ++ show (promotions m) 
		   ++ " Nursery Survival Rate: " ++ show survivalRate
	 where
	      f::Maybe (Record,L.ByteString) -> Record
	      f  (Just (r,_))   = r
	      f      _        = error "We are all going to die."
