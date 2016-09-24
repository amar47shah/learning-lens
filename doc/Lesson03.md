_August 23, 2016_

**Artyom**

At last, exercise feedback!

1. writing `traverse`: nice
2. generalising `view`: nice

  A remark: `view` only works on traversals when the result is a `Monoid`, because

  ```
  instance Monoid a => Applicative (Const a) where
  pure = Const mempty
  Const a <*> Const b = Const (a <> b)
  ```

  Lots of people actually dislike this behavior:

  ```
  data Foo = Foo {_x :: String} | Bar {_x, _y :: String}
  makeLenses ''Foo
  ```

  will generate `x :: Lens' Foo String` and `y :: Traversal' Foo String`
  and now when you try to do `Foo "hi" ^. y`, instead of an error you'd get `""`

  Edward Kmett likes this, however, and so it's a `wontfix` (I'm not sure it can even be fixed, tho)
  (By the way, have I already explained what `makeLenses` does?)

3. writing `preview`: nice
4. writing `toListOf`: nice, but note that it can be more efficient. The problem with `:[]` is that traversing it left-to-right will end up in this:

  ```
  ((1:[]) <> (2:[])) <> (3:[]) ...
  ```

  and `<>`/`++` are O(n), where n is length of the left argument
  so you'll get O(n²) in the end

  to avoid this, you can use the `Endo` monoid:

  ```
  newtype Endo a = Endo (a -> a)
  ```

  (which basically lets you get a difference list)

  ```
  Endo (1:) <> Endo (2:) <> Endo (3:)  ===  Endo (\x -> 1:2:3:x)
  ```

  so you build an `Endo` “list” and then you turn it into an ordinary list by applying it to `[]`

  ```
  appEndo :: Endo a -> a -> a
  appEndo (Endo f) a = f a

  toListOf :: Getting (Endo [a]) s a -> s -> [a]
  toListOf l = (`appEndo` []) . getConst . l (\x -> Const (Endo (x:)))
  ```

5. writing `filtered`: nice but usually it's done without `depends` like this:

  ```
  filtered p f x
    | p x = f x
    | otherwise = pure x
  ```

6. writing `each`: nice

  A remark: lens uses slightly different instances to make type inference nicer:

  ```
  instance (a~b, q~r) => Each (a,b) (q,r) a q where
  each f ~(a,b) = (,) <$> f a <*> f b
  ```

  This means “GHC, choose this instance whenever you see _any_ 2-tuple, but then add an “a=b” constraint”
  it allows `test (0, 0)` to work without a type signature

  (because in your case GHC is wondering “what if the types don't match, what if I should resolve the first `0` to `Int` and the second `0` to `Integer`, and then I'd have to choose a different instance and the behavior of the code would be different, oh no”)

  (and it doesn't matter to GHC that there's no “different instance” in scope, because by default – i.e. without `{-# LANGUAGE IncoherentInstances #-}` – GHC tries to make sure that your code can't go from “compiles” to “doesn't compile” if a new valid instance is introduced from elsewhere)

  Another remark: the `~` in front of `(a,b)` makes tuple deconstruction non-strict:

  ```
  > undefined & yourEach .~ 3
  undefined

  > undefined & lensEach .~ 3
  (3,3)
  ```

  it's called a “lazy pattern” and it turns into the following code:

  ```
  each f x = (,) <$> f (fst x) <*> f (snd x)
  ```

  which doesn't fail if `x` is `undefined` as long as `f` isn't strict
  this behavior is rarely useful and was added to conform to lens laws (`view x (set x v) == x`)
  lenses without lazy patterns fail the law when `v=undefined`, lenses with lazy patterns don't
  (as far as I know, this violation actually won't lead to any harm, tho)

7. writing `_head`: that's an interesting take but you should know that the `_head` from lens sacrifices a bit of safety for usability

  with lens's `_head` you can do `"foo" & _head %~ toUpper`, for instance, and with yours you'll get `Just 'F'` which is not what you usually want
