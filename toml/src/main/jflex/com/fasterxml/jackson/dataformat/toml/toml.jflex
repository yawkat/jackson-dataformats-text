package com.fasterxml.jackson.dataformat.toml;

%%

%class Lexer
%type TomlToken
%unicode
%line
%column
//%caseless todo: what is case insensitive?

%{
  private boolean trimmedNewline;
  StringBuilder stringBuilder = new StringBuilder();

  private void startString() {
      stringBuilder.setLength(0);
      trimmedNewline = false;
  }

  private void appendNormalTextToken() {
      // equivalent to stringBuilder.append(yytext()), without the roundtrip through the String constructor
      stringBuilder.append(zzBuffer, zzStartRead, zzMarkedPos-zzStartRead);
  }

  private void appendNewlineWithPossibleTrim() {
      if (!trimmedNewline && stringBuilder.length() == 0) {
          trimmedNewline = true;
      } else {
          // \n or \r\n todo: "TOML parsers should feel free to normalize newline to whatever makes sense for their platform."
          appendNormalTextToken();
      }
  }

  private void appendUnicodeEscape() {
      int length = zzMarkedPos - zzStartRead;
      if (length == 6) {
          int value = (Character.digit(yycharat(2), 16) << 12) |
                       (Character.digit(yycharat(3), 16) << 8) |
                       (Character.digit(yycharat(4), 16) << 4) |
                       Character.digit(yycharat(5), 16);
          stringBuilder.append((char) value);
      } else if (length == 8) {
           int value = (Character.digit(yycharat(2), 16) << 20) |
                       (Character.digit(yycharat(3), 16) << 16) |
                       (Character.digit(yycharat(4), 16) << 12) |
                       (Character.digit(yycharat(5), 16) << 8) |
                       (Character.digit(yycharat(6), 16) << 4) |
                       Character.digit(yycharat(7), 16);
           stringBuilder.appendCodePoint(value);
       } else {
          throw new AssertionError();
       }
  }

  String positionString() {
      return "line " + (yyline + 1) + " column " + yycolumn;
  }
%}

%init{
yybegin(EXPECT_KEY);
%init}

Ws = [ \t]*
WsNonEmpty = [ \t]+
NewLine = \n|\r\n
CommentStartSymbol = "#"
NonEol = \u0009|[\u0020-\U10ffff]

//Expression = {Ws} (({KeyVal}|{Table}) {Ws}) {Comment}?
Comment = {CommentStartSymbol} {NonEol}*

//KeyVal = {Key} {KeyValSep} {Val}
//Key = {SimpleKey} | {DottedKey}
KeyValSep = {Ws} "=" {Ws}
//SimpleKey = {QuotedKey} | {UnquotedKey}

UnquotedKey = [A-Za-z0-9\-_]+
//QuotedKey = {BasicString} | {LiteralString}
//DottedKey = {SimpleKey} ({Ws} "." {Ws} {SimpleKey})+
DotSep = "."

// grammar rule
// Val = {String} | {Boolean} | {Array} | {InlineTable} | {DateTime} | {Float} | {Integer}

//String = {MlBasicString} | {BasicString} | {MlLiteralString} | {LiteralString}

//BasicString = {QuotationMark} {BasicChar}* {QuotationMark}
QuotationMark = "\""
//BasicChar = {BasicUnescaped} | {Escaped}
// exclude control chars (tab is allowed, " and \)
//BasicUnescaped = [^\u0000-\u0008\u0009-\u001f\u007f\\\"]
//Escaped = "\\" ([\"\\bfnrt]|"u" {HexDig} {HexDig} {HexDig} {HexDig} ({HexDig} {HexDig} {HexDig} {HexDig})?)
UnicodeEscape = "\\u" {HexDig} {HexDig} {HexDig} {HexDig} ({HexDig} {HexDig} {HexDig} {HexDig})?

//MlBasicString = {MlBasicStringDelim} {NewLine}? {MlBasicBody} {MlBasicStringDelim}
MlBasicStringDelim = "\"\"\""
//MlBasicBody = {MlbContent}* ({MlbQuotes} {MlbContent}+)* {MlbQuotes}?
//MlbContent = {MlbChar} | {NewLine} | {MlbEscapedNl}
//MlbChar = {MlbUnescaped} | {Escaped}
//MlbUnescaped = {BasicUnescaped}
//MlbEscapedNl = {Escaped} {Ws} {NewLine} ([ \t] | {NewLine})*

Apostrophe = "'"

MlLiteralStringDelim = "'''"

Integer = {DecInt} | {HexInt} | {OctInt} | {BinInt}
DecInt = [+-]? {UnsignedDecInt}
UnsignedDecInt = [0-9] | ([1-9] (_? [0-9])+)
HexInt = 0x {HexDig} (_? {HexDig})*
OctInt = 0o [0-7] (_? [0-7])*
BinInt = 0b [01] (_? [01])*

Float = {DecInt} ({Exp} | {Frac} {Exp}?) | {SpecialFloat}
Frac = "." {ZeroPrefixableInt}
ZeroPrefixableInt = [0-9] (_? [0-9])*
Exp = [eE] [+-]? {ZeroPrefixableInt}
SpecialFloat = [+-]? (inf | nan)

// Boolean = "true" | "false"

//DateTime = {OffsetDateTime} | {LocalDateTime} | {LocalDate} | {LocalTime}
DateFullyear = [0-9][0-9][0-9][0-9]
DateMonth = [0-9][0-9]
DateMday = [0-9][0-9]
TimeDelim = [Tt ]
TimeHour = [0-9][0-9]
TimeMinute = [0-9][0-9]
TimeSecond = [0-9][0-9]
TimeSecfrac = "." [0-9]+
TimeNumoffset = [+-] {TimeHour} ":" {TimeMinute}
TimeOffset = "Z" | {TimeNumoffset}
PartialTime = {TimeHour} ":" {TimeMinute} ":" {TimeSecond} {TimeSecfrac}?
FullDate = {DateFullyear} "-" {DateMonth} "-" {DateMday}
FullTime = {PartialTime} {TimeOffset}

OffsetDateTime = {FullDate} {TimeDelim} {FullTime}
LocalDateTime = {FullDate} {TimeDelim} {PartialTime}
LocalDate = {FullDate}
LocalTime = {PartialTime}

//Array = {ArrayOpen} {ArrayValues}? {WsCommentNewline} {ArrayClose}
ArrayOpen = "["
ArrayClose = "]"
//ArrayValues = {WsCommentNewline} {Val} {WsCommentNewline} ("," {ArrayValues} | ","?)
ArraySep = ","
WsCommentNewlineNonEmpty = ([\t ] | {Comment}? {NewLine})+

//Table = {StdTable} | {ArrayTable}

//StdTable = {StdTableClose} {Key} {StdTableClose}
StdTableOpen = "[" {Ws}
StdTableClose = {Ws} "]"

//InlineTable = {InlineTableOpen} {InlineTableKeyvals}? {InlineTableClose}
InlineTableOpen = "{" {Ws}
InlineTableClose = {Ws} "}"
//InlineTableKeyvals = {KeyVal} ("," {InlineTableKeyvals})?

//ArrayTable = {ArrayTableOpen} {Key} {ArrayTableClose}
ArrayTableOpen = "[[" {Ws}
ArrayTableClose = {Ws} "]]"

HexDig = [0-9A-Fa-f]

%state EXPECT_KEY
%state EXPECT_VALUE
%state ML_BASIC_STRING
%state BASIC_STRING
%state ML_LITERAL_STRING
%state LITERAL_STRING

%%

<EXPECT_KEY> {
    {UnquotedKey} {return TomlToken.UNQUOTED_KEY;}
    {DotSep} {return TomlToken.DOT_SEP;}
    // quoted-key = basic-string / literal-string
    {QuotationMark} {
          yybegin(BASIC_STRING);
          startString();
      }
    {Apostrophe} {
          yybegin(LITERAL_STRING);
          startString();
      }
    {StdTableOpen} {return TomlToken.STD_TABLE_OPEN;}
    {StdTableClose} {return TomlToken.STD_TABLE_CLOSE;}
    {ArrayTableOpen} {return TomlToken.ARRAY_TABLE_OPEN;}
    {ArrayTableClose} {return TomlToken.ARRAY_TABLE_CLOSE;}
    {KeyValSep} {
          yybegin(EXPECT_VALUE);
          return TomlToken.KEY_VAL_SEP;
      }
    {ArraySep} {
          // yybegin is handled by the parser
          return TomlToken.ARRAY_SEP;
      }
    {InlineTableClose} {
          return TomlToken.INLINE_TABLE_CLOSE;
      }
    {NewLine} {}
    {Comment} {}
    {WsNonEmpty} {}
}

<EXPECT_VALUE> {
    {QuotationMark} {
          yybegin(BASIC_STRING);
          startString();
      }
    {MlBasicStringDelim} {
          yybegin(ML_BASIC_STRING);
          startString();
      }
    {Apostrophe} {
          yybegin(LITERAL_STRING);
          startString();
      }
    {MlLiteralStringDelim} {
          yybegin(ML_LITERAL_STRING);
          startString();
      }
    true {
          yybegin(EXPECT_KEY);
          return TomlToken.TRUE;
      }
    false {
          yybegin(EXPECT_KEY);
          return TomlToken.FALSE;
      }
    {ArrayOpen} {
          return TomlToken.ARRAY_OPEN;
      }
    {ArrayClose} {
          yybegin(EXPECT_KEY);
          return TomlToken.ARRAY_CLOSE;
      }
    {WsCommentNewlineNonEmpty} {
          return TomlToken.ARRAY_WS_COMMENT_NEWLINE;
      }
    {InlineTableOpen} {
          yybegin(EXPECT_KEY);
          return TomlToken.INLINE_TABLE_OPEN;
      }
    {OffsetDateTime} {
          yybegin(EXPECT_KEY);
          return TomlToken.OFFSET_DATE_TIME;
      }
    {LocalDateTime} {
          yybegin(EXPECT_KEY);
          return TomlToken.LOCAL_DATE_TIME;
      }
    {LocalDate} {
          yybegin(EXPECT_KEY);
          return TomlToken.LOCAL_DATE;
      }
    {LocalTime} {
          yybegin(EXPECT_KEY);
          return TomlToken.LOCAL_TIME;
      }
    {Float} {
          yybegin(EXPECT_KEY);
          return TomlToken.FLOAT;
      }
    {Integer} {
          yybegin(EXPECT_KEY);
          return TomlToken.INTEGER;
      }
}

<BASIC_STRING> {
    // basic-string = quotation-mark *basic-char quotation-mark
    // basic-char = basic-unescaped / escaped
    // basic-unescaped = wschar / %x21 / %x23-5B / %x5D-7E / non-ascii
    {QuotationMark} {
          yybegin(EXPECT_KEY);
          return TomlToken.STRING;
      }

    [^\u0000-\u0008\u000a-\u001f\u007f\\\"]+ { appendNormalTextToken(); }
    \\\" { stringBuilder.append('"'); }
    \\\\ { stringBuilder.append('\\'); }
    \\b { stringBuilder.append('\b'); }
    \\f { stringBuilder.append('\f'); }
    \\n { stringBuilder.append('\n'); }
    \\r { stringBuilder.append('\r'); }
    \\t { stringBuilder.append('\t'); }
    {UnicodeEscape} { appendUnicodeEscape(); }
}

<ML_BASIC_STRING> {
    // ml-basic-string = ml-basic-string-delim [ newline ] ml-basic-body ml-basic-string-delim
    // ml-basic-body = *mlb-content *( mlb-quotes 1*mlb-content ) [ mlb-quotes ]
    // mlb-content = mlb-char / newline / mlb-escaped-nl
    // mlb-char = mlb-unescaped / escaped
    // mlb-quotes = 1*2quotation-mark
    {MlBasicStringDelim} {
          yybegin(EXPECT_KEY);
          return TomlToken.STRING;
      }
    {NewLine} { appendNewlineWithPossibleTrim(); }
    // mlb-quotes: inline
    \" { stringBuilder.append('"'); }
    // mlb-quotes: at the end
    \" {MlBasicStringDelim} {
          stringBuilder.append('"');
          yybegin(EXPECT_KEY);
          return TomlToken.STRING;
      }
    \"\" {MlBasicStringDelim} {
          stringBuilder.append("\"\"");
          yybegin(EXPECT_KEY);
          return TomlToken.STRING;
      }
    // mlb-escaped-nl
    // ignore, but disable newline trimming after it
    \\ {Ws} {NewLine} ([ \t] | {NewLine})* { trimmedNewline = true; }
    // mlb-char
    [^\u0000-\u0008\u000a-\u001f\u007f\\\"]+ { appendNormalTextToken(); }
    \\\" { stringBuilder.append('"'); }
    \\\\ { stringBuilder.append('\\'); }
    \\b { stringBuilder.append('\b'); }
    \\f { stringBuilder.append('\f'); }
    \\n { stringBuilder.append('\n'); }
    \\r { stringBuilder.append('\r'); }
    \\t { stringBuilder.append('\t'); }
    {UnicodeEscape} { appendUnicodeEscape(); }
}

<LITERAL_STRING> {
    // literal-string = apostrophe *literal-char apostrophe
    {Apostrophe} {
          yybegin(EXPECT_KEY);
          return TomlToken.STRING;
      }
    [^\u0000-\u0008\u000a-\u001f']+ { appendNormalTextToken(); }
}

<ML_LITERAL_STRING> {
    // ml-literal-string = ml-literal-string-delim [ newline ] ml-literal-body ml-literal-string-delim
    // ml-literal-body = *mll-content *( mll-quotes 1*mll-content ) [ mll-quotes ]
    // mll-quotes = 1*2apostrophe
    {MlLiteralStringDelim} {
          yybegin(EXPECT_KEY);
          return TomlToken.STRING;
      }
    [^\u0000-\u0008\u000a-\u001f']+ { appendNormalTextToken(); }
    {NewLine} { appendNewlineWithPossibleTrim(); }
    // mll-quotes: inline
    {Apostrophe} { stringBuilder.append('\''); }
    // mll-quotes: at the end
    {Apostrophe} {MlLiteralStringDelim} {
          stringBuilder.append('\'');
          yybegin(EXPECT_KEY);
          return TomlToken.STRING;
      }
    {Apostrophe}{Apostrophe} {MlLiteralStringDelim} {
          stringBuilder.append("''");
          yybegin(EXPECT_KEY);
          return TomlToken.STRING;
      }
}

[^] {
  throw new com.fasterxml.jackson.core.JacksonException("Unknown token at " + positionString()) {
      @Override public Object processor() {
    return null; // TODO
    }
  };
}
