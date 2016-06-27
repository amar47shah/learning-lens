_June 13, 2016_

**Artyom:**
if you want, we could begin with lenses (what do you already know about them?)

**amar47shah:**
almost nothing! i have an idea that they can be thought of as a powerful alternative to record syntax.
once i implemented a composition type and wrote instances for Functor and Applicative Functor. and someone said, “that way lies lenses!"

**Artyom:**
they're an alternative to record access/update, yep, but they let you do more things than that

let's begin with something like this
```haskell
map :: (a -> b) -> ([a] -> [b])
```

can you say – without using ghci – what is the type of `map . map . map`?

once you do that:
```haskell
first :: (a -> b) -> (a, x) -> (b, x)
second :: (a -> b) -> (x, a) -> (x, b)
```

what's the type of `first . second`?

**amar47shah:**
worked it out on paper, i’m getting
```haskell
map . map . map :: (a -> b) -> [[[a]]] -> [[[b]]]
```

**Artyom:**
yep, and the second example?

**amar47shah:**
need a few mins

**amar47shah:**
i’m getting
```haskell
first . second :: (a -> b) -> ((x, a), y) -> ((x, b), y)
```

**Artyom:**
yep. note how it changes the _second_ element of the _first_ element

now let's define an auxiliary function:
```haskell
set f b = f (\_ -> b)
```

and observe what we can do now:
```haskell
> set (first.second) 3 $ ((0,0),0)
((0,3),0)
```

or we can do this without any auxiliary functions:
```haskell
> (first.second) (+5) $ ((0,0),0)
((0,5),0)
```

now! how would `first.second.map` behave?

**amar47shah:**
```haskell
first.second.map :: (a -> b) -> ((x,[a]), y) -> ((x,[b]), y)
```
```haskell
> first.second.map (+1) ((0,[1,2,3]), 0)
((0,[2,3,4]), 0)
```

**amar47shah:**
so looks like we can make focused updates to nested product types without needing the verbose overhead of writing and using accessor functions

**Artyom:**
yep. note how you can modify one value, many values, or even no values. for instance, you could write `_Left :: (a -> b) -> Either a x -> Either b x` that would modify the left branch, but only if present.

however, we would also like those composable accessors to do getting, and currently we can't do that. Well, here's a clever (and entirely non-obvious) trick in two parts

Part 1

usually getters have the type `s -> a`

```haskell
fst :: (a, x) -> a
head :: [a] -> a
```

however, we want getters to look more like setters, because ideally they should be _one function_ and therefore their types have to be the same.
so, watch my hands:
```haskell
fst' :: (a -> b) -> ((a, x) -> b)
head' :: (a -> b) -> ([a] -> b)
```

we can easily transform any function to be like this
```haskell
fst' f s = f (fst s)
head' f s = f (head s)
```

these getters are still composable, but in the opposite direction
```haskell
> (fst . head) [(1,2),(3,4)]
1

> (head' . fst') [(1,2),(3,4)]
1
```

(note how the second variant looks like accessor dot from OOP)

**amar47shah:**
yeah i’ve noticed that since i saw you write `first.second` without the space

but where’s `f` in that second example?
```haskell
head' . fst' :: (a -> b) -> [(a, x)] -> b
```

**Artyom:**
currying!

```haskell
fst' f s = f (fst s)
fst' f = \s -> f (fst s)
```

i.e. `fst'` takes a function and produces a function
and `head'` takes a function and produces a function
and, as you can see, their composition, too, takes a function `a -> b` and produces a function `[(a, x)] -> b`
so, `f` is actually the argument that `head' . fst'` will take

**amar47shah:**
right, so shouldn’t it be
```haskell
> (head' . fst') id [(1,2),(3,4)]
1
```

**Artyom:**
_looks_

**Artyom:**
ouch, right. I've misunderstood you
yes, exactly, good catch

**amar47shah:**
no worries, this is fun!

**Artyom:**
now we can write a high-level description of what getters and setters do. let's call `s` – “whole”, and `a` – “part” (e.g. in case of `first` the whole is `(a,x)`, the part is `a`)
* a setter takes a modifying function for a part and turns it into a modifying function for a whole
* a getter takes an accessor function for a part and turns it into an accessor function for a whole

and by using `id` as an accessor, we can extract the part from the whole

**amar47shah:**
this is so badass

**Artyom:**
however, there's still part 2 ahead! for we can't unify the types yet:
```haskell
fstSetter :: (a -> b) -> ((a, x) -> (b, x))
fstGetter :: (a -> b) -> ((a, x) -> b)
```

**amar47shah:**
ok. but it’s useful to have them different. fstGetter unwraps...

**Artyom:**
it's more useful to have them unified, because then you can combine two setter-and-getters to get another setter-and-getter

**amar47shah:**
aha

**Artyom:**
otherwise you'd have to duplicate everything.

part 2 is just as non-obvious as part 1 (there's a shortcut to it, but I'll reveal it later). the clue is: whenever you want to unify 2 things, a typeclass is lurking nearby

**amar47shah:**
haha nice. should i make this an exercise then?

**Artyom:**
nah, the thing is that despite the clue, it's still nigh unsolvable. orinally the formulation of lenses (this style is called Van Laarhoven lenses) was invented in like 5 steps by half a dozen of people

**amar47shah:**
hahaha well it’s good to know that before i spend a decade on it

**Artyom:**
first, let's introduce a weird type called `Const`
```haskell
data Const a x = Const a
```

i.e. `Const a x` holds a value of type `a` in it, and doesn't hold any values of type `x`, contrary to what an unsuspecting bystander could think

now watch very closely
```haskell
fstGetter :: (a -> b) -> ((a, x) -> b)
-- turns into
fstGetter :: (a -> Const b b) -> ((a, x) -> Const b (b, x))
```

nothing has changed, since `Const b b` is just a wrapper around `b`, and `Const b (b, x)` is, too, a wrapper around `b`

and now I'll do the same transformation with the setter and another type called `Identity`

```haskell
data Identity a = Identity a

fstSetter :: (a -> b) -> ((a, x) -> (b, x))
-- turns into
fstSetter :: (a -> Identity b) -> ((a, x) -> Identity (b, x))
```

they look pretty similar now:
```haskell
fstGetter :: (a -> Const b  b) -> ((a, x) -> Const b  (b, x))
fstSetter :: (a -> Identity b) -> ((a, x) -> Identity (b, x))
```

**Artyom:**
a high-level explanation of this is that both getters and setters now operate on boxes. the setter's box just contains `b` or `(b, x)`. the getter's box _pretends_ to contain that, but it also glues a `b` to the side of the box, and that `b` gets carried out (and the actual box is empty). they look pretty similar now in shape.

the last step is actually using the typeclass for boxes (i.e. `Functor`):
```haskell
fstLens :: Functor f => (a -> f b) -> ((a, x) -> f (b, x))
```

`Identity` is a functor (since it's a box containing a single value)
`Const x` is a functor too, naturally (since `Const x a` contains no values of type `a`, it's trivial to change “all” values inside it and get a `Const x b` for any `a` and `b`)

and hence `fstLens` can be specialised to either `fstGetter` or `fstSetter` at will

**amar47shah:**
hmm. wow

**Artyom:**
here's a simplified way to imagine it all

you have something like
```haskell
fstSetter :: (a -> b) -> ((a, x) -> (b, x))
```

what's the absolute dumbest way to get `a` out of it? why, let's just give it access to IO:
```haskell
fstSetter :: (a -> IO b) -> ((a, x) -> IO (b, x))
fstSetter f = \(a, x) -> do
  b <- f a
  return (b, x)
```

now you can easily do setting with it, but you can also do getting by passing `print` to it. except that now when you do setting, you're stuck in `IO`

**amar47shah:**
yeah we do this silly stuff in ruby all the time. and js, etc

**Artyom:**
so let's instead introduce a class for actions: `IO` will be a getting-action, and `Identity` will be a setting-action. (`Identity` is like `IO` that can be unwrapped and does absolutely nothing – so it's perfect)

```haskell
fstSetter :: Monad m => (a -> m b) -> ((a, x) -> m (b, x))
fstSetter f = \(a, x) -> do
  b <- f a
  return (b, x)
```

now we still can pass `print` to it if we want, but we can also pass a simple modifying `a -> b` if we turn it into `a -> Identity b` (which is easy).
so, we're getting close, but printing stuff is stupid, we don't want to print anything, we want to just carry the value out.
and that's where `Const` comes in – you can think of `Const b x` as of an action that carries a “variable” of type `b` inside itself

the final step is realising that `Monad` is too strong here and reducing it to `Functor`, which requires knowing that `Functor` isn't just a box but can be an action/etc too

that's all for today
