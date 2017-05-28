{-# LANGUAGE AutoDeriveTypeable #-}
{-# LANGUAGE CPP                #-}
{-# LANGUAGE DeriveGeneric      #-}
{-# LANGUAGE LambdaCase         #-}
{-# LANGUAGE OverloadedStrings  #-}

#include "version-compatibility-macros.h"

-- | Conversion of the linked-list-like 'SimpleDocStream' to a tree-like
-- 'SimpleDocTree'.
module Data.Text.Prettyprint.Doc.Render.Util.SimpleDocTree (

    -- * Type and conversion
    SimpleDocTree(..),
    treeForm,

    -- * Manipulating annotations
    unAnnotateST,
    reAnnotateST,

    -- * Common use case shortcut definitions
    renderSimplyDecorated,
    renderSimplyDecoratedA,
) where



import           Control.Applicative
import           Data.Text           (Text)
import qualified Data.Text           as T
import           GHC.Generics

import Data.Text.Prettyprint.Doc
import Data.Text.Prettyprint.Doc.Render.Util.Panic

#if MONAD_FAIL
import Control.Monad.Fail
#endif

#if !(MONOID_IN_PRELUDE)
import Data.Monoid (Monoid (..))
#endif

#if !(FOLDABLE_TRAVERSABLE_IN_PRELUDE)
import Data.Foldable    (Foldable (..))
import Data.Traversable (Traversable (..))
#endif

-- $setup
--
-- (Definitions for the doctests)
--
-- >>> import Data.Text.Prettyprint.Doc hiding ((<>))
-- >>> import qualified Data.Text.IO as T



-- | Simplest possible tree-based renderer.
--
-- For example, here is a document annotated with @()@, and the behaviour is to
-- surround annotated regions with »>>>« and »<<<«:
--
-- >>> let doc = "hello" <+> annotate () "world" <> "!"
-- >>> let stdoc = treeForm (layoutPretty defaultLayoutOptions doc)
-- >>> T.putStrLn (renderSimplyDecorated id (\() x -> ">>>" <> x <> "<<<") stdoc)
-- hello >>>world<<<!
renderSimplyDecorated
    :: Monoid out
    => (Text -> out)       -- ^ Render plain 'Text'
    -> (ann -> out -> out) -- ^ How to modify an element with an annotation
    -> SimpleDocTree ann
    -> out
renderSimplyDecorated text renderAnn = go
  where
    go = \case
        STEmpty -> mempty
        STChar c -> text (T.singleton c)
        STText _ t -> text t
        STLine i -> text (T.singleton '\n' <> T.replicate i " ")
        STAnn ann rest -> renderAnn ann (go rest)
        STConcat xs -> foldMap go xs

-- | Version of 'renderSimplyDecoratedA' that allows for 'Applicative' effects.
renderSimplyDecoratedA
    :: (Applicative f, Monoid out)
    => (Text -> f out)         -- ^ Render plain 'Text'
    -> (ann -> f out -> f out) -- ^ How to modify an element with an annotation
    -> SimpleDocTree ann
    -> f out
renderSimplyDecoratedA text renderAnn = go
  where
    go = \case
        STEmpty -> pure mempty
        STChar c -> text (T.singleton c)
        STText _ t -> text t
        STLine i -> text (T.singleton '\n' <> T.replicate i " ")
        STAnn ann rest -> renderAnn ann (go rest)
        STConcat xs -> fmap mconcat (traverse go xs)



-- | A type for parsers of unique results. Token stream »s«, results »a«.
--
-- Hand-written to avoid a dependency on a parser lib.
newtype UniqueParser s a = UniqueParser { runParser :: s -> Maybe (a, s) }

instance Functor (UniqueParser s) where
    fmap f (UniqueParser mx) = UniqueParser (\s ->
        fmap (\(x,s') -> (f x, s')) (mx s))

instance Applicative (UniqueParser s) where
    pure x = UniqueParser (\rest -> Just (x, rest))
    UniqueParser mf <*> UniqueParser mx = UniqueParser (\s -> do
        (f, s') <- mf s
        (x, s'') <- mx s'
        pure (f x, s'') )

instance Monad (UniqueParser s) where
#if !(APPLICATIVE_MONAD)
    return = pure
#endif
    UniqueParser p >>= f = UniqueParser (\s -> do
        (a', s') <- p s
        (a'', s'') <- runParser (f a') s'
        pure (a'', s'') )

    fail _err = empty

#if MONAD_FAIL
instance MonadFail (UniqueParser s) where
    fail _err = empty
#endif

instance Alternative (UniqueParser s) where
    empty = UniqueParser (const empty)
    UniqueParser p <|> UniqueParser q = UniqueParser (\s -> p s <|> q s)

data SimpleDocTok ann
    = TokEmpty
    | TokChar Char
    | TokText !Int Text
    | TokLine Int
    | TokAnnPush ann
    | TokAnnPop
    deriving (Eq, Ord, Show)

-- | A 'SimpleDocStream' is a linked list of different annotated cons cells
-- ('SText' and then some further 'SimpleDocStream', 'SLine' and then some
-- further 'SimpleDocStream', …). This format is very suitable as a target for a
-- layout engine, but not very useful for rendering to a structured format such
-- as HTML, where we don’t want to do a lookahead until the end of some markup.
-- These formats benefit from a tree-like structure that explicitly marks its
-- contents as annotated. 'SimpleDocTree' is that format.
data SimpleDocTree ann
    = STEmpty
    | STChar Char
    | STText !Int Text
    | STLine !Int
    | STAnn ann (SimpleDocTree ann)
    | STConcat [SimpleDocTree ann]
    deriving (Eq, Ord, Show, Generic)

-- | Alter the document’s annotations.
--
-- This instance makes 'SimpleDocTree' more flexible (because it can be used in
-- 'Functor'-polymorphic values), but @'fmap'@ is much less readable compared to
-- using @'reAnnotateST'@ in code that only works for @'SimpleDocTree'@ anyway.
-- Consider using the latter when the type does not matter.
instance Functor SimpleDocTree where
    fmap = reAnnotateST

-- | Get the next token, consuming it in the process.
nextToken :: UniqueParser (SimpleDocStream ann) (SimpleDocTok ann)
nextToken = UniqueParser (\case
    SFail             -> panicUncaughtFail
    SEmpty            -> empty
    SChar c rest      -> Just (TokChar c      , rest)
    SText l t rest    -> Just (TokText l t    , rest)
    SLine i rest      -> Just (TokLine i      , rest)
    SAnnPush ann rest -> Just (TokAnnPush ann , rest)
    SAnnPop rest      -> Just (TokAnnPop      , rest) )

sdocToTreeParser :: UniqueParser (SimpleDocStream ann) (SimpleDocTree ann)
sdocToTreeParser = fmap wrap (many contentPiece)

  where

    wrap :: [SimpleDocTree ann] -> SimpleDocTree ann
    wrap = \case
        []  -> STEmpty
        [x] -> x
        xs  -> STConcat xs

    contentPiece = nextToken >>= \case
        TokEmpty       -> pure STEmpty
        TokChar c      -> pure (STChar c)
        TokText l t    -> pure (STText l t)
        TokLine i      -> pure (STLine i)
        TokAnnPop      -> empty
        TokAnnPush ann -> do annotatedContents <- sdocToTreeParser
                             TokAnnPop <- nextToken
                             pure (STAnn ann annotatedContents)

-- | Convert a 'SimpleDocStream' to its 'SimpleDocTree' representation.
treeForm :: SimpleDocStream ann -> SimpleDocTree ann
treeForm sdoc = case runParser sdocToTreeParser sdoc of
    Nothing               -> panicSimpleDocTreeConversionFailed
    Just (sdoct, SEmpty)  -> sdoct
    Just (_, _unconsumed) -> panicInputNotFullyConsumed

-- $
--
-- >>> :set -XOverloadedStrings
-- >>> treeForm (layoutPretty defaultLayoutOptions ("lorem" <+> "ipsum" <+> annotate True ("TRUE" <+> annotate False "FALSE") <+> "dolor"))
-- STConcat [STText 5 "lorem",STChar ' ',STText 5 "ipsum",STChar ' ',STAnn True (STConcat [STText 4 "TRUE",STChar ' ',STAnn False (STText 5 "FALSE")]),STChar ' ',STText 5 "dolor"]

-- | Remove all annotations. 'unAnnotate' for 'SimpleDocTree'.
unAnnotateST :: SimpleDocTree ann -> SimpleDocTree xxx
unAnnotateST = \case
    STEmpty      -> STEmpty
    STChar c     -> STChar c
    STText l t   -> STText l t
    STLine i     -> STLine i
    STAnn _ rest -> unAnnotateST rest
    STConcat xs  -> STConcat (map unAnnotateST xs)

-- | Change the annotation of a document. 'reAnnotate' for 'SimpleDocTree'.
reAnnotateST :: (ann -> ann') -> SimpleDocTree ann -> SimpleDocTree ann'
reAnnotateST f = go
  where
    go = \case
        STEmpty        -> STEmpty
        STChar c       -> STChar c
        STText l t     -> STText l t
        STLine i       -> STLine i
        STAnn ann rest -> STAnn (f ann) (go rest)
        STConcat xs    -> STConcat (map go xs)

-- | Collect all annotations from a document.
instance Foldable SimpleDocTree where
    foldMap f = \case
        STEmpty        -> mempty
        STChar _       -> mempty
        STText _ _     -> mempty
        STLine _       -> mempty
        STAnn ann rest -> f ann `mappend` foldMap f rest
        STConcat xs    -> mconcat (map (foldMap f) xs)

-- | Transform a document based on its annotations, possibly leveraging
-- 'Applicative' effects.
instance Traversable SimpleDocTree where
    traverse f = \case
        STEmpty        -> pure STEmpty
        STChar c       -> pure (STChar c)
        STText l t     -> pure (STText l t)
        STLine i       -> pure (STLine i)
        STAnn ann rest -> STAnn <$> f ann <*> traverse f rest
        STConcat xs    -> STConcat <$> traverse (traverse f) xs