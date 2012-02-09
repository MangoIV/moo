-- This example uses Moo library to solve linear equation
-- using genetic algorithm.

import Moo.GeneticAlgorithm.Binary
import Moo.GeneticAlgorithm.Run
import Moo.GeneticAlgorithm.Random
import Moo.GeneticAlgorithm.Utilities
import Control.Monad
import Control.Monad.Mersenne.Random
import System.Random.Mersenne.Pure64
import Print (printHistoryAndBest)

n = 4          -- number of equations
range = (0, 9) -- range of coefficients and solution entries

popsize = 200  -- population size
maxiters = 1000 -- maximum number of iterations
elitesize = 2  -- best genomes to keep intact

-- create a random system of linear equations, return matrix and rhs
createSLE :: Int -> Rand ([[Int]], [Int], [Int])
createSLE n = do
  mat <- replicateM n $ replicateM n (getRandomR range) :: Rand [[Int]]
  xs <- replicateM n (getRandomR range)
  let rhs = mat `mult` xs
  return (mat, xs, rhs)

-- convert solution to bit encoding (genome)
toGenome :: [Int] -> [Bool]
toGenome = concatMap (encodeGray range)

-- convert bit encoding (genome) to solution variables
fromGenome :: [Bool] -> [Int]
fromGenome = map (decodeGray range) . splitEvery (bitsNeeded range)

-- fitness function designed to minimize the norm of the residual
-- of the candidate solution.
fitness mat rhs bits _ =
    let xs = fromGenome bits
        residual = norm2 $ (mat `mult` xs) `minus` rhs
    in  negate residual

-- selection: tournament selection
select mat rhs = tournamentSelect 2 (popsize-elitesize)

main = do
  (mat,rhs,solution,(pop, log)) <- runGA $ do
         -- a random SLE problem
         (mat, solution, rhs) <- createSLE n
         -- initial population
         xs0 <- replicateM popsize $ replicateM n (getRandomR range)
         let pop0 = evalFitness (fitness mat rhs) . map toGenome $ xs0
         -- digest function to keep log of evolution
         let digest p = (avgFitness p, maxFitness p)
         -- run for some generations
         r <- loopUntil' (MaxFitness (>= 0)
                         `Or` FitnessStdev (<= 1)
                         `Or` Iteration maxiters)
               digest pop0 $
                nextGeneration elitesize
                               (fitness mat rhs)
                               (select mat rhs)
                               (twoPointCrossover 0.5)
                               (pointMutate 0.25)
         return (mat, rhs, solution, r)
  printHistoryAndBest (show.fromGenome) pop log
  putStr $ unlines
    [ "# system matrix: " ++ show mat
    , "# system right hand side: " ++ show rhs
    , "# system solution: " ++ show solution ]

-- Matrix - vector product.
mult :: (Num a) => [[a]] -> [a] -> [a]
mult rows xs = map (sum . zipWith (*) xs) rows

-- Vector - vector sum and difference.
plus :: (Num a) => [a] -> [a] -> [a]
plus xs ys = zipWith (+) xs ys
minus :: (Num a) => [a] -> [a] -> [a]
minus xs ys = zipWith (-) xs ys

-- Vector norm.
norm2 :: (Num a, Real a) => [a] -> Double
norm2 = sqrt . fromRational . toRational . sum . map (^2)