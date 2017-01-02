module Analyze.Ops
  ( oneHot
  ) where

import Analyze.Common (Data)
import Analyze.RFrame (RFrame(..), RFrameUpdate(..), col, splitCols, update)
import Control.Monad.Catch (MonadThrow(..))
import qualified Data.HashSet as HS
import qualified Data.Vector as V
import Data.Vector (Vector)

uniq :: Data k => Vector k -> Vector k
uniq ks = V.reverse (V.fromList newKsR)
  where
    acc (hs, uks) k =
      if HS.member k hs
        then (hs, uks)
        else (HS.insert k hs, k:uks)
    (_, newKsR) = V.foldl acc (HS.empty, []) ks

match :: Eq k => Vector k -> v -> v -> k -> Vector v
match ks yesVal noVal tk = V.map (\k -> if k == tk then yesVal else noVal) ks

oneHot :: (Data k, MonadThrow m) => (k -> v -> k) -> k -> v -> v -> RFrame k v -> m (RFrame k v)
oneHot combine key yesVal noVal frame = do
  let (target, cold) = splitCols (== key) frame
  rawVs <- col key target
  let cookedKs = V.map (combine key) rawVs
      newKs = uniq cookedKs
      newVs = V.map (match newKs yesVal noVal) cookedKs
      hot = RFrameUpdate newKs newVs
  update hot cold


-- unHot :: (Data k, MonadThrow m) => (k -> m (Maybe (k, v))) -> k -> RFrame k v -> RFrame k v
-- unHot = undefined