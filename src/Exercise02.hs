{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE RankNTypes #-}

module Exercise02 where

import BasePrelude
import Data.Functor.Identity

type Traversal s t a b = forall f. Applicative f => (a -> f b) -> s -> f t

-- 1. write `traverse'` that would be a list traversal
-- (without using `traverse`)

traverse' :: Applicative f => (a -> f b) -> [a] -> f [b]
traverse' k (x:xs) = (:) <$> k x <*> traverse' k xs
traverse' _ _      = pure []

-- 2. generalise `view` the way I generalised `over`.
-- Try to apply it to `both` or `_Just`.
-- What happens? When is this `view` useful?

view :: ((a ->  Const a b) -> s ->  Const a t) ->             s -> a
set  :: ((a -> Identity b) -> s -> Identity t) ->       b  -> s -> t
over :: ((a -> Identity b) -> s -> Identity t) -> (a -> b) -> s -> t

view opt = getConst . opt Const
set  opt = (runIdentity .) . opt . const . Identity
over opt = (runIdentity .) . (opt .) (Identity .)

(^.) = \x opt -> view opt x
(.~) = set
(%~) = over

infixl 8 ^.
infixr 4 .~, %~

-- What happens?
--   *Main Exercise01 Exercise02> Exercise01.view _Just $ Just "hello"
--   <interactive>:11:17: Could not deduce (Applicative f) arising from a use of ‘_Just’
--   *Main Exercise01 Exercise02> Exercise02.view _Just $ Just "hello"
--   "hello"
--   *Main Exercise01 Exercise02> Exercise01.view both $ ("hello", "hi")
--   <interactive>:15:17: Could not deduce (Applicative f) arising from a use of ‘both’
--   *Main Exercise01 Exercise02> Exercise02.view both $ ("hello", "hi")
--   "hellohi"
-- When is this `useful`?
--   whenever you are using a traversal,
--   that is, a lens specialized to applicative functors,
--   and you need to retrieve all the data it points to.

-- 3. using `Const` and `First`,
-- write `preview :: Traversal s t a b -> s -> Maybe a`
-- that extracts the first element a traversal points at
-- (or nothing if there isn't one)

preview :: Traversal s t a b -> s -> Maybe a
preview trav = getFirst . getConst . trav (Const . First . Just)

-- 4. write `(^..) :: s -> Traversal s t a b -> [a]`
-- that extracts all values from a traversal

(^..) :: s -> Traversal s t a b -> [a]
(^..) = \x trav -> toListOf trav x

toListOf :: Traversal s t a b -> s -> [a]
toListOf trav = getConst . trav (Const . (:[]))

-- 5. write `filtered :: (a -> Bool) -> Traversal a a a a`
-- that traverses a value only if it satisfies a condition
-- (it's useful for stuff like `[1..10] & each . filtered even .~ 0`)

filtered :: (a -> Bool) -> Traversal a a a a
filtered p = \f -> depends p f pure

depends :: (a -> Bool) -> (a -> b) -> (a -> b) -> a -> b
depends p f _ x | p x = f x
depends _ _ g x       = g x

-- 6. write your own `each` that would work for lists, Maybe,
-- `(a,a)`, `(a,a,a)`, and `(a,a,a,a)`.
-- You'll need a type class and a bunch of extensions.
-- (Don't forget to actually test it.)

class Each s t a b | s -> a, t -> b, s b -> t, t a -> s where
  each :: Traversal s t a b

instance Each [a] [b] a b where
  each = traverse'

instance Each (Maybe a) (Maybe b) a b where
  each = _Just

instance Each (a, a) (b, b) a b where
  each = both

instance Each (a, a, a) (b, b, b) a b where
  each = triple

instance Each (a, a, a, a) (b, b, b, b) a b where
  each = quad

_Just :: Traversal (Maybe a) (Maybe b) a b
_Just f (Just x) = Just <$> f x
_Just _ _        = pure Nothing

both :: Traversal (a, a) (b, b) a b
both f = \(x, y) -> (,) <$> f x <*> f y

triple :: Traversal (a, a, a) (b, b, b) a b
triple f = \(x, y, z) -> (,,) <$> f x <*> f y <*> f z

quad :: Traversal (a, a, a, a) (b, b, b, b) a b
quad f = \(w, x, y, z) -> (,,,) <$> f w <*> f x <*> f y <*> f z

-- Testing
--   *Exercise02> :set -XFlexibleContexts
--   *Exercise02> let test s = s & each . filtered even .~ 0
--   *Exercise02> test [1..10]
--   [1,0,3,0,5,0,7,0,9,0]
--   *Exercise02> test Nothing
--   Nothing
--   *Exercise02> test $ Just 1
--   Just 1
--   *Exercise02> test $ Just 2
--   Just 0
--   *Exercise02> test (0, 0)
--   <interactive>:36:1:
--       No instance for (Integral a10) arising from a use of ‘it’
--       The type variable ‘a10’ is ambiguous
--       Note: there are several potential instances:
--         instance Integral Integer -- Defined in ‘GHC.Real’
--         instance Integral Int -- Defined in ‘GHC.Real’
--         instance Integral Word -- Defined in ‘GHC.Real’
--       In the first argument of ‘print’, namely ‘it’
--       In a stmt of an interactive GHCi command: print it
--   *Exercise02> test (0, 0) :: (Int, Int)
--   (0,0)
--   *Exercise02> test (1, 2) :: (Int, Int)
--   (1,0)
--   *Exercise02> test (2, 1) :: (Int, Int)
--   (0,1)
--   *Exercise02> test (2, 2) :: (Int, Int)
--   (0,0)
--   *Exercise02> test (2, 1, 2) :: (Int, Int, Int)
--   (0,1,0)
--   *Exercise02> test (2, 1, 1, 2) :: (Int, Int, Int, Int)
--   (0,1,1,0)

-- Extras

_head :: Traversal [a] (Maybe b) a b
_head f = \xs -> head' $ f <$> xs

head' :: Applicative f => [f a] -> f (Maybe a)
head' (x:_) = Just <$> x
head' _     = pure Nothing
