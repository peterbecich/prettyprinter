{-# LANGUAGE OverloadedStrings #-}

module Main (main) where



import Prelude hiding (words)

import qualified Data.List                             as L
import           Data.Text                             (Text)
import qualified Data.Text                             as T
import qualified Data.Text.IO                          as T
import           Data.Text.Prettyprint.Doc
import           Data.Text.Prettyprint.Doc.Render.Text



main :: IO ()
main = (T.putStrLn . renderStrict . layoutPretty layoutOptions) readmeContents
  where
    layoutOptions = LayoutOptions { layoutRibbonFraction = 1, layoutPageWidth = CharsPerLine 80 }

readmeContents :: Doc ann
readmeContents = (mconcat . L.intersperse vspace)
    [ htmlComment "This file was auto-generated by the 'readme' makefile target."

    , h1 "Prettyprinter à la Wadler/Leijen"

    , cat
        [ "[![status](https://img.shields.io/github/release/quchen/prettyprinter.svg?style=flat-square&label=Latest%20version)](https://github.com/quchen/prettyprinter/releases)"
        , "[![status](https://img.shields.io/travis/quchen/prettyprinter/master.svg?style=flat-square&label=Master%20build)](https://travis-ci.org/quchen/prettyprinter)"
        ]

    , paragraph "This module defines a prettyprinter to format text in a\
        \ flexible and convenient way. The idea is to combine a document out\
        \ of many small components, then using a layouter to convert it to an\
        \ easily renderable simple document, which can then be rendered to a\
        \ variety of formats, for example plain `Text`, or Markdown. *What you\
        \ are reading right now was generated by this library (see `GenerateReadme.hs`).*"

    , h2 "Why another prettyprinter?"
        , paragraph "Haskell, more specifically Hackage, has a zoo of Wadler/Leijen based prettyprinters already. Each of them addresses a different concern with the classic `wl-pprint` package. This package solves *all* these issues, and then some."
    , h3 "`Text` instead of `String`"
        , paragraph "`String` has exactly one use, and that’s showing Hello World in tutorials. For all other uses, Text is what people should be using. The prettyprinter uses no `String` definitions anywhere; using a `String` means an immediate conversion to the internal `Text`-based format."
    , h3 "Extensive documentation"
        , paragraph "The library is stuffed with runnable examples, showing use cases for the vast majority of exported values. Many things reference related definitions, *everything* comes with at least a sentence explaining its purpose."
    , h3 "No name clashes"
        , paragraph "Many prettyprinters use the legacy API of the first Wadler/Leijen prettyprinter, which used e.g. `(<$>)` to separate lines, which clashes with the ubiquitous synonym for `fmap` that’s been in Base for ages. These definitions were either removed or renamed, so there are no name clashes with standard libraries anymore."
    , h3 "Annotation support"
        , paragraph "Text is not all letters and newlines. Often, we want to add more information, the simplest kind being some form of styling. An ANSI terminal supports colouring, a web browser a plethora of different formattings."
        , paragraph "More complex uses of annotations include e.g. adding type annotations for mouse-over hovers when printing a syntax tree, adding URLs to documentation, or adding source locations to show where a certain piece of output comes from. Idris is a project that makes extensive use of such a feature."
        , paragraph "Special care has been applied to make annotations unobtrusive, so that if you don’t need or care about them there is no overhead, neither in terms of usability nor performance."
    , h3 "Extensible backends"
        , paragraph "A document can be rendered in many different ways, for many different clients. There is plain text, there is the ANSI terminal, there is the browser. Each of these speak different languages, and the backend is responsible for the translation to those languages. Backends should be readily available, or easy to implement if a custom solution is desired."
    , h3 "Performance"
        , paragraph "Rendering large documents should be done efficiently, and the library should make it easy to optimize common use cases for the programmer."
    , h3 "Open implementation"
        , paragraph "The type of documents is unanimously (!) abstract in the other Wadler/Leijen prettyprinters, making it impossible to write adaptors from one library to another. The type should be exposed for such purposes so it is possible to write adaptors from library to library, or each of them is doomed to live on its own small island of incompatibility. For this reason, the `Doc` type is fully exposed in a semi-internal module for this specific use case."


    , h2 "The wl-pprint family"
    , paragraph "The `wl-pprint` family of packages consists of:"
    , (indent 2 . unorderedList . map paragraph)
        [ "`wl-pprint` is the core package. It defines the language to generate nicely\
            \ laid out documents, which can then be given to renderers to display them in\
            \ various ways, e.g. HTML, or plain text."
        , "`wl-pprint-ansi` provides a renderer suitable for ANSI terminal output\
            \ including colors (at the cost of a dependency more)."
        , "`wl-pprint-compat-old` provides a drop-in compatibility layer for\
            \previous users of the old `wl-pprint`. Use it for easy adaption of\
            \ the new `wl-pprint`, but don't develop anything new with it."
        , "`wl-pprint-compat-old-ansi` is the same, but for previous users of `ansi-wl-pprint`."
        ]

    , h2 "Differences to the old Wadler/Leijen prettyprinter"

    , paragraph  "The library originally started as a fork of `ansi-wl-pprint` until\
        \ every line had been touched. The result is still in the same spirit\
        \ as its predecessors, but modernized to match the current ecosystem \
        \ and needs."
    , paragraph  "The most significant changes are:"
    , (indent 2 . orderedList . map paragraph)
        [ "`(<$>)` is removed as an operator, since it clashes with the common alias for `fmap`."
        , "All but the essential `<>` and `<+>` operators were removed or replaced by ordinary names."
        , "Everything extensively documented, with references to other functions and runnable code examples."
        , "Use of `Text` instead of `String`."
        , "A `fuse` function to optimize often-used documents before rendering for efficiency."
        , "Instead of providing an own colorization function for each\
          \ color/intensity/layer combination, they have been combined in 'color'\
          \ 'colorDull', 'bgColor', and 'bgColorDull' functions."
        ]
    ]

paragraph :: Text -> Doc ann
paragraph = align . fillSep . map pretty . T.words

vspace :: Doc ann
vspace = hardline <> hardline

h1 :: Doc ann -> Doc ann
h1 x = vspace <> underlineWith "=" x

h2 :: Doc ann -> Doc ann
h2 x = vspace <> underlineWith "-" x

h3 :: Doc ann -> Doc ann
h3 x = vspace <> "###" <+> x

underlineWith :: Text -> Doc ann -> Doc ann
underlineWith symbol x = align (width x (\w ->
    hardline <> pretty (T.take w (T.replicate w symbol))))

orderedList :: [Doc ann] -> Doc ann
orderedList = align . vsep . zipWith (\i x -> pretty i <> dot <+> align x) [1::Int ..]

unorderedList :: [Doc ann] -> Doc ann
unorderedList = align . vsep . map ("-" <+>)

htmlComment :: Doc ann -> Doc ann
htmlComment = enclose "<!-- " " -->"
