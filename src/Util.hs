{-# LANGUAGE PatternSynonyms, RankNTypes #-}

module Util (module Util) where

import Data.TextWithMatch
import Types

import Brick(BrickEvent(..))
import Control.Monad.State
import Data.Sequence (Seq, (|>))
import Data.Text (Text)
import Data.Text.Zipper (getText)
import Data.Zipper (toSeq)
import Lens.Micro
import Lens.Micro.Extras (view)
import Search (mkRegex, textWithMatches)
import Text.Regex.PCRE (Regex)
import qualified Brick.Widgets.Edit as Edit
import qualified Brick.Widgets.List as List
import qualified Data.Sequence as Seq
import qualified Data.Text as Text
import qualified Graphics.Vty as V

pattern PlainKey :: V.Key -> BrickEvent n e
pattern PlainKey c = VtyEvent (V.EvKey c [])

filterMSeq :: (a -> IO Bool) -> Seq a -> IO (Seq a)
filterMSeq p = foldM (\acc a -> p a >>= \b -> if b then pure (acc |> a) else pure acc) Seq.empty

nextName :: Name -> Name
nextName FileBrowser = FromInput
nextName FromInput = ToInput
nextName ToInput = FileBrowser
nextName Preview = error "No nextName for Preview"

prevName :: Name -> Name
prevName FromInput = FileBrowser
prevName FileBrowser = ToInput
prevName ToInput = FromInput
prevName Preview = error "No prevName for Preview"

selectionL ::
  (List.Splittable t, Traversable t, Semigroup (t e)) =>
  SimpleGetter (List.GenericList n t e) (Maybe e)
selectionL = to (fmap snd . List.listSelectedElement)

editorContentL :: SimpleGetter (Edit.Editor Text n) Text
editorContentL = Edit.editContentsL . to getText . to Text.concat

compiledRegexL :: SimpleGetter AppState (Maybe Regex)
compiledRegexL = regexFrom .
  editorContentL .
  to Text.unpack .
  to (\t -> guard (not $ null t) >> mkRegex t)

primaryTextWithMatchesL :: SimpleGetter AppState (Maybe (String, Seq TextWithMatch))
primaryTextWithMatchesL = to $ \s -> do
  regex <- s ^. compiledRegexL
  (fname, selectedContents) <- s ^. matchedFiles . selectionL
  pure (fname, textWithMatches regex selectedContents)

textWithMatchesL :: SimpleGetter AppState (Maybe (Seq TextWithMatch))
textWithMatchesL = to $ \s -> maybe (fmap snd $ s ^. primaryTextWithMatchesL) (pure . toSeq . view curReplaceFile) (s ^. replaceState)
