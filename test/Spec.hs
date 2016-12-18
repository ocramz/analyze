{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE TypeSynonymInstances #-}

import           Analyze.Common           ((<&>))
import qualified Analyze.Conversions      as AC
import qualified Analyze.Decoding         as AD
import qualified Analyze.RFrame           as ARF
import           Analyze.Values
import           Control.Monad.Catch
import qualified Data.HashMap.Strict      as HM
import qualified Data.HashSet             as HS
import           Data.Text                (Text)
import qualified Data.Text                as T
import           Data.Vector              (Vector)
import qualified Data.Vector              as V
import           Datasets
import           Fixtures
import           Generation
import           Test.QuickCheck
import qualified Test.QuickCheck.Property as P
import           Test.Tasty
import           Test.Tasty.HUnit
import           Test.Tasty.QuickCheck

-- Boilerplate

propertyIO :: Assertion -> Property
propertyIO action = ioProperty tester
  where
    tester :: IO P.Result
    tester = catch (action >> return P.succeeded) handler
    handler (HUnitFailure err) = return P.failed { P.reason = err }

testPropertyIO :: TestName -> Gen a -> (a -> Assertion) -> TestTree
testPropertyIO name g t = testProperty name (propertyIO . t <$> g)

-- Aux

getUpdateFixture :: Text -> IO (ARF.RFrameUpdate Text Value)
getUpdateFixture name =
  case HM.lookup name fixtures of
    Just u  -> return u
    Nothing -> error ("fixture not found: " ++ (T.unpack name))


getFrameFixture :: Text -> IO (ARF.RFrame Text Value)
getFrameFixture name = ARF.fromUpdate =<< getUpdateFixture name

-- Tests

testFixture :: TestTree
testFixture = testCase "fixture" $ do
  frame <- getFrameFixture "full"
  (ARF._rframeKeys frame) @?= exampleHeader
  (ARF.numRows frame) @?= 2
  (ARF.numCols frame) @?= 3

testRowDecode :: TestTree
testRowDecode = testCase "rowDecode" $ do
  frame <- getFrameFixture "full"
  let decoder = AD.requireWhere "score" floating <&> (*2)
  result <- sequenceA =<< ARF.decode decoder frame
  V.fromList [10.0, 6.0] @?= result

testDrop :: TestTree
testDrop = testCase "drop" $ do
  original <- getFrameFixture "full"
  expected <- getFrameFixture "noName"
  (ARF.numCols original) @?= 3
  (ARF.numCols expected) @?= 2
  let actual = ARF.dropCols (HS.singleton "name") original
  (ARF._rframeKeys actual) @?= (ARF._rframeKeys expected)

testKeep :: TestTree
testKeep = testCase "keep" $ do
  original <- getFrameFixture "full"
  expected <- getFrameFixture "noName"
  (ARF.numCols original) @?= 3
  (ARF.numCols expected) @?= 2
  let actual = ARF.keepCols (HS.fromList ["id", "score"]) original
  (ARF._rframeKeys actual) @?= (ARF._rframeKeys expected)

testUpdateEmpty :: TestTree
testUpdateEmpty = testCase "update empty" $ do
  update <- getUpdateFixture "full"
  empty <- ARF.fromUpdate =<< getUpdateFixture "empty"
  expected <- ARF.fromUpdate update
  actual <- ARF.update update empty
  actual @?= expected

testUpdateEmpty2 :: TestTree
testUpdateEmpty2 = testCase "update empty 2" $ do
  frame <- getFrameFixture "full"
  update <- getUpdateFixture "empty"
  actual <- ARF.update update frame
  actual @?= frame

testUpdateAdd :: TestTree
testUpdateAdd = testCase "update add" $ do
  frame <- getFrameFixture "full"
  update <- getUpdateFixture "color"
  expected <- getFrameFixture "fullColor"
  actual <- ARF.update update frame
  actual @?= expected

testUpdateOverlap :: TestTree
testUpdateOverlap = testCase "update overlap" $ do
  frame <- getFrameFixture "full"
  update <- getUpdateFixture "overlap"
  expected <- getFrameFixture "fullOverlap"
  actual <- ARF.update update frame
  actual @?= expected

testTitanic :: TestTree
testTitanic = testCase "load titanic" $ do
  frame <- datasetWithHeader "titanic" "test"
  let expectedCols = V.fromList
        [ "PassengerId"
        , "Pclass"
        , "Name"
        , "Sex"
        , "Age"
        , "SibSp"
        , "Parch"
        , "Ticket"
        , "Fare"
        , "Cabin"
        , "Embarked"
        ]
  ARF._rframeKeys frame @?= expectedCols
  ARF.numRows frame @?= 418

-- Runner

tests :: TestTree
tests = testGroup "Tests"
  [ testFixture
  , testRowDecode
  , testDrop
  , testKeep
  , testUpdateEmpty
  , testUpdateEmpty2
  , testUpdateAdd
  , testUpdateOverlap
  , testTitanic
  ]

main :: IO ()
main = defaultMain tests
