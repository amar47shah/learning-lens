_June 26, 2016_

**Artyom:**
Before we go further, here are standard operator synonyms for `view`, `set`, and `over`

```
(^.) = flip view
(.~) = set
(%~) = over
```

and `&` is reverse function application

so, in lens-ed code you'll often see stuff like this:

```
tuple ^. _1

tuple & _1 .~ 3

tuple & _1 %~ (*2)
```

A common criticism of this style is that it looks like Perl, and it sort of does, but after a while one gets used to it.

The next step is traversals; a traversal is a “multi-lens”, or a lens that has several targets. Here's how it looks in action:

```
> over both negate (1,2)
(-1,-2)

> (1,2) ^.. both
[1,2]
```

(here `both` is a traversal)

One clue that hints at traversals is the fact that in `(a -> f b) -> s -> f t`, nothing actually prevents us from applying the `a -> f b` function to more than one value (or to no values at all)

the other clue is that there's a well-known `Traversable` class whose methods have suspiciously similar signatures:

```
traverse :: (Applicative f, Traversable t) => (a -> f b) -> t a -> f (t b)
```

```
> traverse (Just . negate) [1,2,3]
Just [-1,-2,-3]
```

for now let's work with `traverse` specialised for lists. It would have the following signature:

```
traverse :: Applicative f => (a -> f b) -> [a] -> f [b]
```

so, these were observations #1 and #2. Observation #3: currently `over` and `set` don't work with `traverse`, but we can make them work with it

the reason they don't work is that `over` is really fine with _any function that works with `Identity`_, not just with lenses

i.e.

* lenses work with `Identity`
* `traverse` works with `Identity` too, because `Identity` is `Applicative`
* however, currently `over` requires a `Lens`, i.e. a function that works with any functor, and `traverse` only works with applicative functors and therefore doesn't fit

here's the most general type of `over`:

```
over :: ((a -> Identity b) -> s -> Identity t) -> (a -> b) -> s -> t
```

and if you edit the signature of `over` to look like this, you'll find that `over traverse` works

observation (or more like question) #4: why does `traverse` only work with applicative functors and not just with any functors?

the answer is 2-part

**a)**

it needs to produce a `f [b]` out of `[a]` even if the list is empty, and with plain functors it's impossible

i.e. functors only provide `fmap` which modifies the innards of an existing functor, but there's no function to wrap something into a functor

however, such function is provided by `Applicative` and is called `pure`:

```
pure :: Applicative f => a -> f a
```

with this function you can, for instance, produce a traversal that traverses the value inside of `Maybe` (which doesn't have to be present)

```
type Traversal s t a b = Applicative f => (a -> f b) -> s -> f t

_Just :: Traversal (Maybe a) (Maybe b) a b
_Just f = \s -> case s of
  Nothing -> pure Nothing
  Just x -> Just <$> f x
```

```
> Just 3 & _Just %~ negate
Just (-3)

> Nothing & _Just %~ negate
Nothing

> Nothing & _Just .~ 3
Nothing
```

`_Just` is impossible to write without `pure`

**b)**

the traversal also needs a way to combine several functors together, and again this is something that non-applicative functors don't provide

let's say you're writing `both`

```
both :: Traversal (a, a) (b, b) a b
both f = \(x1, x2) -> ...
```

you can apply `f` to `x1` and `x2` and get two values of type `f b`

however, with just `fmap` you can't bump them together to get `f (b, b)`

you need `<*>` for that:

```
(<*>) :: f (a -> b) -> f a -> f b
```

```
both f = \(x1, x2) -> (,) <$> f x1 <*> f x2
```

it's easier to understand with an alternative (but equivalent) definition of `Applicative`:

```
class Applicative f where
  pure :: a -> f a
  combine :: (a -> b -> c) -> f a -> f b -> f c
```

it's easy to show that this class is equivalent to the standard one (with `<*>`), but it makes it more obvious why `Applicative` is needed for traversals
