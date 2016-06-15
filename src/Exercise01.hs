{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE RankNTypes #-}

module Exercise01 where

import BasePrelude  -- from base-prelude
import Data.Functor.Identity

type Lens s t a b = forall f. Functor f => (a -> f b) -> (s -> f t)

_1 :: Lens (a, x) (b, x) a b
_1 = \k s -> flip (,) (snd s) <$> k (fst s)

view :: Lens s t a b -> s -> a
view = undefined

set :: Lens s t a b -> b -> s -> t
set = undefined

over :: Lens s t a b -> (a -> b) -> (s -> t)
over = undefined
