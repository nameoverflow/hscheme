module Hscheme.Parser (
    readExpr,
    readExprList
) where

import Numeric
import Data.Char
import Text.ParserCombinators.Parsec hiding (spaces)
import System.Environment ()
import Control.Applicative ((<$>))

import Hscheme.Types

type LispParser = Parser LispVal


readOrThrow :: Parser a -> String -> ThrowsError a
readOrThrow parser input = case parse parser "lisp" input of
    Left err  -> throwError $ Parser err
    Right val -> return val

readExpr :: String -> ThrowsError LispVal
readExpr = readOrThrow parseExpr

readExprList :: String -> ThrowsError [LispVal]
readExprList = readOrThrow (endBy parseExpr spaces)


symbol :: Parser Char
symbol = oneOf "!#$%&|*+-/:<=>?@^_~"

spaces :: Parser ()
spaces = skipMany1 space

comment :: Parser ()
comment = char ';' >> skipMany (noneOf "\n")

multLineComment :: Parser ()
multLineComment = skipMany1 $ between (string "#|") (string "|#") anyToken

atomSplits :: Parser ()
atomSplits = spaces <|> comment <|> multLineComment

parseExpr :: LispParser
parseExpr = parseString <|> parseNumber <|> parseListSugar <|> parseAtom <|> do
    _ <- char '('
    x <- try parseList <|> parseDottedList
    _ <- char ')'
    return x

parseString :: LispParser
parseString = do
    let escapedChar = char '\\' >> oneOf "\"nrt\\"
    _ <- char '"'
    x <- many (escapedChar <|> noneOf "\"")
    _ <- char '"'
    return $ String x

parseAtom :: LispParser
parseAtom = do
    first <- letter <|> symbol
    rest <- many (letter <|> digit <|> symbol)
    let atom = first : rest
    return $ case atom of
        "#t" -> Bool True
        "#f" -> Bool False
        _ -> Atom atom

parseNumber :: LispParser
parseNumber = try parseFloat <|> parseInteger

parseFloat :: LispParser
parseFloat = do
    beforeDot <- many1 digit
    dot <- char '.'
    fra <- many1 digit
    let h = case beforeDot of
              "" -> "0"
              num -> num
    return $ Float . fst . head . readFloat $ h ++ dot : fra

parseInteger :: LispParser
parseInteger = parseWithBase <|> readBase 10
    where
        readBase :: Integer -> LispParser
        readBase b = do
            numStr <- many1 digit
            return $ Number . fst . head . readInt b isDigit digitToInt $ numStr
        parseWithBase = char '#' >> oneOf "bodx" >>= \base ->
            case base of
              'b' -> readBase 2
              'o' -> readBase 8
              'd' -> readBase 10
              'x' -> readBase 16
              _   -> undefined

parseList :: LispParser
parseList = List <$> sepBy parseExpr atomSplits

parseDottedList :: LispParser
parseDottedList = do
    h <- endBy parseExpr spaces
    t <- char '.' >> spaces >> parseExpr
    return $ DottedList h t

parseListSugar :: LispParser
parseListSugar = do
    start <- oneOf "'`,@"
    x <- parseExpr
    let deSugar h = List [Atom h, x]
    return . deSugar $ case start of
      '\'' -> "quote"
      '`' -> "quasiquote"
      '@' -> "unquote-splicing"
      ',' -> "unquote"
      _   -> undefined
