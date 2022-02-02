module Harser.Combinators (
    Alternative(..),
    (<?>),
    zeroOrOne,
    zeroOrMore,
    oneOrMore,
    try,
    exactly,
    option,
    splits, splits',
    atLeast,
    atMost,
    count,
    skip,
    skips, skips',
    skipn,
    skipUntil,
    skipBtwn,
    choose, choose',
    select, select',
    maybeP,
    boolP,
    wrap,
    between
) where

import Control.Applicative (Alternative(..))

import Harser.Parser (
        Parser(..),
        ParseState(..),
        fulfill,
        runP,
        (<?>)
    )
import Harser.Stream (Stream(..))


zeroOrOne :: Parser s u a -> Parser s u (Maybe a)
zeroOrOne (Parser a) = Parser (\s -> case a s of
    (s', Failure _) -> (s', Success Nothing)
    (s', Success x) -> (s', Success (Just x)))


zeroOrMore :: Parser s u a -> Parser s u [a]
zeroOrMore = many


oneOrMore :: Parser s u a -> Parser s u [a]
oneOrMore = some


-- |If the given parser fails, resets the current
-- state. Does not consume input on failure.
try :: Parser s u a -> Parser s u a
try (Parser f) = Parser (\s -> case f s of
    (_, Failure e)  -> (s, Failure e)
    (s', Success x) -> (s', Success x))


-- |@'exactly' t@ is equivalent to @'fulfill'
-- (== t)@
exactly :: (Eq t, Stream s t) => t -> Parser s u t
exactly t = fulfill (== t)


-- |Takes a parser and a default value. Upon failure,
-- succeeds with the default value.
option :: Parser s u a -> a -> Parser s u a
option (Parser a) d = Parser (\s -> case a s of
    (s', Failure _) -> (s', Success d)
    (s', Success x) -> (s', Success x))


-- |@delim `'splits'` psr@ parses one or more
-- @psr@'s, seperated by @delim@. Typically used
-- in infix for readability purposes.
splits :: Parser s u a -> Parser s u b -> Parser s u [b]
splits s p = (:) <$> p <*> zeroOrMore (s *> p)


-- |Same as 'splits', but parses zero or more.
splits' :: Parser s u a -> Parser s u b -> Parser s u [b]
splits' s p = splits s p <?> pure []


-- |@'atLeast' n p@ parses @n@ or more instances of
-- @p@
atLeast :: Int -> Parser s u a -> Parser s u [a]
atLeast 0 p = zeroOrMore p
atLeast 1 p = oneOrMore p
atLeast n p = (++) <$> (count n p) <*> zeroOrMore p


-- |@'atMost' n p@ parses at most @n@ instances of @p@
atMost :: Int -> Parser s u a -> Parser s u [a]
atMost 0 _ = pure []
atMost 1 p = fmap (:[]) p
atMost n p@(Parser a) = Parser (\s -> case a s of
    (s', Failure _) -> (s', Success [])
    (s', Success x) -> case runP (atMost (n - 1) p) s' of
        (s'', Failure _)  -> (s'', Success [x])
        (s'', Success xs) -> (s'', Success (x:xs)))


-- |@'count' n p@ parses exactly @n@ instances of @p@
count :: Int -> Parser s u a -> Parser s u [a]
count 0 _ = return []
count n p = (:) <$> p <*> (count (n - 1) p)


-- |@'skip' p@ parses @p@ (consuming input), and
-- returns @()@
skip :: Parser s u a -> Parser s u ()
skip (Parser a) = Parser (\s -> case a s of
    (s', Failure e) -> (s', Failure e)
    (s', Success _) -> (s', pure ()))


-- |@'skips' p@ runs p zero or more times, then
-- returns @()@
skips :: Parser s u a -> Parser s u ()
skips p = zeroOrMore p >> pure ()


-- |@'skips' p@ runs p one or more times, then
-- returns @()@
skips' :: Parser s u a -> Parser s u ()
skips' p = oneOrMore p >> pure ()


-- |@'skipn' n p@ skips exactly @n@ instances of
-- @p@
skipn :: Int -> Parser s u a -> Parser s u ()
skipn n p = count n p >> pure ()


skipUntil :: Parser s u a -> Parser s u ()
skipUntil p = Parser $ \s -> case runP p s of
        (s', Failure _) -> (s', pure ())
        (s', Success _) -> runP (skipUntil p) s'


skipBtwn :: Parser s u a -> Parser s u b
         -> Parser s u ()
skipBtwn a b = skip a >> skipUntil b


choose :: [Parser s u a] -> Parser s u a
choose [] = fail "choose"
choose (p:ps) = foldr (<?>) p ps


-- | choose without backtracking
choose' :: [Parser s u a] -> Parser s u a
choose' [] = fail "choose'"
choose' (p:ps) = foldr (<|>) p ps


select :: (a -> Parser s u a) -> [a] -> Parser s u a
select _ [] = fail "select"
select p (x:xs) = foldr (<?>) (p x) (fmap p xs)


-- | select without backtracking
select' :: (a -> Parser s u a) -> [a] -> Parser s u a
select' _ [] = fail "select'"
select' p (x:xs) = foldr (<|>) (p x) (fmap p xs)


maybeP :: Parser s u a -> Parser s u (Maybe a)
maybeP p = Parser $ \s -> case runP p s of
    (s', Success a) -> (s', pure $ Just a)
    (_, Failure _)  -> (s, pure Nothing)


boolP :: Parser s u a -> Parser s u a
      -> Parser s u b -> Parser s u a
boolP fp tp bp = Parser $ \s -> case runP bp s of
    (s', Failure _) -> runP fp s'
    (s', Success _) -> runP tp s'


wrap :: Parser s u a -> Parser s u b -> Parser s u b
wrap s p = s *> p <* s


between :: Parser s u a -> Parser s u b
        -> Parser s u c -> Parser s u b
between ls p rs = ls *> p <* rs



