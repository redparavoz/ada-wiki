-----------------------------------------------------------------------
--  wiki-parsers -- Wiki parser
--  Copyright (C) 2011, 2012, 2013, 2014, 2015, 2016 Stephane Carrez
--  Written by Stephane Carrez (Stephane.Carrez@gmail.com)
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
-----------------------------------------------------------------------
with Ada.Strings.Wide_Wide_Fixed;

with Wiki.Parsers.Html;
with Wiki.Helpers;
with Wiki.Nodes;
package body Wiki.Parsers is

   use Wiki.Helpers;
   use Wiki.Nodes;
   use Wiki.Strings.Wide_Wide_Builders;

   --  Parse the beginning or the end of a double character sequence.  This procedure
   --  is instantiated for several format types (bold, italic, superscript, subscript, code).
   --  Example:
   --    --name--  **bold** ~~strike~~
   generic
      Format : Format_Type;
   procedure Parse_Double_Format (P     : in out Parser;
                                  Token : in Wiki.Strings.WChar);

   --  Parse the beginning or the end of a single character sequence.  This procedure
   --  is instantiated for several format types (bold, italic, superscript, subscript, code).
   --  Example:
   --    _name_    *bold*   `code`
   generic
      Format : Format_Type;
   procedure Parse_Single_Format (P     : in out Parser;
                                  Token : in Wiki.Strings.WChar);

   --  Parse an italic, bold or bold + italic sequence.
   --  Example:
   --    ''name''         (italic)
   --    '''name'''       (bold)
   --    '''''name'''''   (bold+italic)
   procedure Parse_Bold_Italic (P     : in out Parser;
                                Token : in Wiki.Strings.WChar);

   --  Parse a line break.
   --  Example:
   --     \\    (Creole)
   --     %%%   (Dotclear)
   procedure Parse_Line_Break (P     : in out Parser;
                               Token : in Wiki.Strings.WChar);

   --  Parse a link.
   --  Example:
   --    [name]
   --    [name|url]
   --    [name|url|language]
   --    [name|url|language|title]
   --    [[link]]
   --    [[link|name]]
   --  ------------------------------
   procedure Parse_Link (P     : in out Parser;
                         Token : in Wiki.Strings.WChar);

   --  Parse a template with parameters.
   --  Example:
   --    {{Name|param|...}}           MediaWiki
   --    {{Name|param=value|...}}     MediaWiki
   --    <<Name param=value ...>>     Creole
   --    [{Name param=value ...}]     JSPWiki
   procedure Parse_Template (P     : in out Parser;
                             Token : in Wiki.Strings.WChar);

   --  Parse a space and take necessary formatting actions.
   --  Example:
   --    item1 item2   => add space in text buffer
   --    ' * item'     => start a bullet list (Google)
   --    ' # item'     => start an ordered list (Google)
   --    ' item'       => preformatted text (Google, Creole)
   procedure Parse_Space (P     : in out Parser;
                          Token : in Wiki.Strings.WChar);

   --  Parse a wiki heading.  The heading could start with '=' or '!'.
   --  The trailing equals are ignored.
   --  Example:
   --    == Level 2 ==
   --    !!! Level 3
   procedure Parse_Header (P     : in out Parser;
                           Token : in Wiki.Strings.WChar);

   --  Parse an image.
   --  Example:
   --    ((url|alt text))
   --    ((url|alt text|position))
   --    ((url|alt text|position||description))
   procedure Parse_Image (P     : in out Parser;
                          Token : in Wiki.Strings.WChar);

   --  Parse a quote.
   --  Example:
   --    {{name}}
   --    {{name|language}}
   --    {{name|language|url}}
   procedure Parse_Quote (P     : in out Parser;
                          Token : in Wiki.Strings.WChar);

   --  Parse a horizontal rule.
   --  Example:
   --    ----
   procedure Parse_Horizontal_Rule (P     : in out Parser;
                                    Token : in Wiki.Strings.WChar);

   procedure Parse_End_Line (P     : in out Parser;
                             Token : in Wiki.Strings.WChar);

   procedure Parse_Preformatted (P     : in out Parser;
                                 Token : in Wiki.Strings.WChar);

   --  Parse a blockquote.
   --  Example:
   --    >>>quote level 3
   --    >>quote level 2
   --    >quote level 1
   procedure Parse_Blockquote (P     : in out Parser;
                               Token : in Wiki.Strings.WChar);

   procedure Parse_List (P     : in out Parser;
                         Token : in Wiki.Strings.WChar);

   procedure Parse_List_Or_Bold (P     : in out Parser;
                                 Token : in Wiki.Strings.WChar);

   --  Parse a HTML component.
   --  Example:
   --     <b> or </b>
   procedure Parse_Maybe_Html (P     : in out Parser;
                               Token : in Wiki.Strings.WChar);

   --  Parse a list definition:
   --    ;item 1
   --    : definition 1
   procedure Parse_Item (P     : in out Parser;
                         Token : in Wiki.Strings.WChar);

   --  Parse a list definition:
   --    ;item 1
   --    : definition 1
   procedure Parse_Definition (P     : in out Parser;
                               Token : in Wiki.Strings.WChar);

   procedure Toggle_Format (P      : in out Parser;
                            Format : in Format_Type);

   --  ------------------------------
   --  Peek the next character from the wiki text buffer.
   --  ------------------------------
   procedure Peek (P     : in out Parser;
                   Token : out Wiki.Strings.WChar) is
   begin
      if not P.Has_Pending then
         --  Get the next character.
         P.Reader.Read (Token, P.Is_Eof);
         if P.Is_Eof then
            --  Return a \n on end of file (this simplifies the implementation).
            Token := LF;
            P.Pending := LF;
            P.Has_Pending := True;
         end if;
      else
         --  Return the pending character.
         Token := P.Pending;
         if not P.Is_Eof then
            P.Has_Pending := False;
         end if;
      end if;
   end Peek;

   --  ------------------------------
   --  Put back the character so that it will be returned by the next call to Peek.
   --  ------------------------------
   procedure Put_Back (P     : in out Parser;
                       Token : in Wiki.Strings.WChar) is
   begin
      P.Pending     := Token;
      P.Has_Pending := True;
   end Put_Back;

   --  ------------------------------
   --  Flush the wiki text that was collected in the text buffer.
   --  ------------------------------
   procedure Flush_Text (P : in out Parser) is

      procedure Add_Text (Content : in Wiki.Strings.WString);

      procedure Add_Text (Content : in Wiki.Strings.WString) is
      begin
         P.context.Filters.Add_Text (P.Document, Content, P.Format);
      end Add_Text;

      procedure Add_Text is
         new Wiki.Strings.Wide_Wide_Builders.Get (Add_Text);

   begin
      if Length (P.Text) > 0 then
         Add_Text (P.Text);
         Clear (P.Text);
      end if;
   end Flush_Text;

   --  ------------------------------
   --  Flush the wiki dl/dt/dd definition list.
   --  ------------------------------
   procedure Flush_List (P : in out Parser) is
   begin
      if P.In_List then
         P.Context.Filters.Pop_Node (P.Document, Wiki.DL_TAG);
         P.In_List := False;
      end if;
   end Flush_List;

   --  ------------------------------
   --  Skip white spaces and tabs.
   --  ------------------------------
   procedure Skip_Spaces (P : in out Parser) is
      C : Wiki.Strings.WChar;
   begin
      while not P.Is_Eof loop
         Peek (P, C);
         if not Wiki.Helpers.Is_Space (C) then
            Put_Back (P, C);
            return;
         end if;
      end loop;
   end Skip_Spaces;

   --  ------------------------------
   --  Append a character to the wiki text buffer.
   --  ------------------------------
   procedure Parse_Text (P     : in out Parser;
                         Token : in Wiki.Strings.WChar) is
   begin
      Append (P.Text, Token);
      P.Empty_Line := False;
   end Parse_Text;

   --  ------------------------------
   --  Skip all the spaces and tabs as well as end of the current line (CR+LF).
   --  ------------------------------
   procedure Skip_End_Of_Line (P : in out Parser) is
      C : Wiki.Strings.WChar;
   begin
      loop
         Peek (P, C);
         exit when C /= ' ' and C /= HT;
      end loop;
      if C = CR then
         Peek (P, C);
         if C /= LF then
            Put_Back (P, C);
         end if;
      elsif C = LF then
         Peek (P, C);
         if C /= CR then
            Put_Back (P, C);
         end if;
      end if;
   end Skip_End_Of_Line;

   --  ------------------------------
   --  Parse a pre-formatted text which starts either by a space or by a sequence
   --  of characters.  Example:
   --    {{{
   --    pre-formatted
   --    }}}
   --    ' pre-formattted'
   --  ------------------------------
   procedure Parse_Preformatted (P     : in out Parser;
                                 Token : in Wiki.Strings.WChar) is
      procedure Add_Preformatted (Content : in Wiki.Strings.WString);

      C          : Wiki.Strings.WChar;
      Stop_Token : Wiki.Strings.WChar;
      Format     : Wiki.Strings.UString;
      Col        : Natural;
      Is_Html    : Boolean := False;

      procedure Add_Preformatted (Content : in Wiki.Strings.WString) is
      begin
         P.Context.Filters.Add_Preformatted (P.Document, Content, Wiki.Strings.To_WString (Format));
      end Add_Preformatted;

      procedure Add_Preformatted is
         new Wiki.Strings.Wide_Wide_Builders.Get (Add_Preformatted);

   begin
      if Token /= ' ' then
         Peek (P, C);
         if C /= Token then
            Parse_Text (P, Token);
            Put_Back (P, C);
            return;
         end if;
         Peek (P, C);
         if C /= Token then
            Parse_Text (P, Token);
            Parse_Text (P, Token);
            Put_Back (P, C);
            return;
         end if;
      elsif not P.Is_Dotclear or else not P.Empty_Line then
         Parse_Text (P, Token);
         return;
      end if;
      Flush_Text (P);
      Flush_List (P);
      if Token = ' ' then
         Col := 1;
         while not P.Is_Eof loop
            Peek (P, C);
            if Col = 0 then
               if C /= ' ' then
                  Put_Back (P, C);
                  exit;
               end if;
               Col := Col + 1;
            elsif C = LF or C = CR then
               Col := 0;
               --  Check for CR + LF and treat it as a single LF.
               if C = CR and then not P.Is_Eof then
                  Peek (P, C);
                  if C = LF then
                     Append (P.Text, C);
                  else
                     Put_Back (P, C);
                     Append (P.Text, LF);
                  end if;
               else
                  Append (P.Text, C);
               end if;
            else
               Col := Col + 1;
               Append (P.Text, C);
            end if;
         end loop;
      else
         Peek (P, C);
         if Token = '{' then
            if C /= LF and C /= CR then
               Put_Back (P, C);
               P.Format (CODE) := True;
               return;
            end if;
         elsif Token = '}' then
            Put_Back (P, C);
            P.Format (CODE) := True;
            return;
         elsif Token /= ' ' then
            while not P.Is_Eof and C /= LF and C /= CR loop
               Wiki.Strings.Append (Format, C);
               Peek (P, C);
            end loop;
         end if;
         if Token = '{' then
            Stop_Token := '}';
         else
            Stop_Token := Token;
         end if;
         Flush_List (P);
         Is_Html := Wiki.Strings.To_WString (Format) = "html";
         Col := 0;
         while not P.Is_Eof loop
            Peek (P, C);
            if Stop_Token = C and Col = 0 then
               Peek (P, C);
               if C = Stop_Token then
                  Peek (P, C);
                  exit when C = Stop_Token;
               end if;
               Append (P.Text, Stop_Token);
               Col := Col + 1;
            elsif C = LF or C = CR then
               Col := 0;
            else
               Col := Col + 1;
            end if;
            if Is_Html and C = '<' then
               Wiki.Parsers.Html.Parse_Element (P);
            else
               Append (P.Text, C);
            end if;
         end loop;
         Skip_End_Of_Line (P);
      end if;
      P.Empty_Line := True;

      if not Is_Html then
         Add_Preformatted (P.Text);
         Clear (P.Text);
         P.Context.Filters.Add_Node (P.Document, Wiki.Nodes.N_PARAGRAPH);
         P.In_Paragraph := True;
      end if;
   end Parse_Preformatted;

   --  ------------------------------
   --  Parse a wiki heading.  The heading could start with '=' or '!'.
   --  The trailing equals are ignored.
   --  Example:
   --    == Level 2 ==
   --    !!! Level 3
   --  ------------------------------
   procedure Parse_Header (P     : in out Parser;
                           Token : in Wiki.Strings.WChar) is

      procedure Add_Header (Content : in Wiki.Strings.WString);

      C      : Wiki.Strings.WChar;
      Level  : Integer := 1;

      procedure Add_Header (Content : in Wiki.Strings.WString) is
         Last         : Natural := Content'Last;
         Ignore_Token : Boolean := True;
         Seen_Token   : Boolean := False;
      begin
         --  Remove the spaces and '=' at end of header string.
         while Last > Content'First loop
            if Content (Last) = Token then
               exit when not Ignore_Token;
               Seen_Token := True;
            elsif Content (Last) = ' ' or Content (Last) = HT then
               Ignore_Token := not Seen_Token;
            else
               exit;
            end if;
            Last := Last - 1;
         end loop;
         P.Context.Filters.Add_Header (P.Document, Content (Content'First .. Last), Level);
      end Add_Header;

      procedure Add_Header is
         new Wiki.Strings.Wide_Wide_Builders.Get (Add_Header);

   begin
      if not P.Empty_Line then
         Parse_Text (P, Token);
         return;
      end if;

      while Level <= 6 loop
         Peek (P, C);
         exit when C /= Token;
         Level := Level + 1;
      end loop;

      --  Ignore spaces after '=' signs
      while C = ' ' or C = HT loop
         Peek (P, C);
      end loop;
      Flush_Text (P);
      Flush_List (P);

      loop
         Append (P.Text, C);
         Peek (P, C);
         exit when C = LF or C = CR;
      end loop;

      --  dotclear header is the opposite of Creole for the level.
      Level := Level + P.Header_Offset;
      if Level < 0 then
         Level := -Level;
      end if;
      if Level = 0 then
         Level := 1;
      end if;

      Add_Header (P.Text);
      P.Empty_Line   := True;
      P.In_Paragraph := False;
      Clear (P.Text);
   end Parse_Header;

   --  ------------------------------
   --  Check if the link refers to an image and must be rendered as an image.
   --  ------------------------------
   function Is_Image (P    : in Parser;
                      Link : in Wide_Wide_String) return Boolean is
      Pos : Natural;
   begin
      if not P.Check_Image_Link then
         return False;
      elsif Wiki.Helpers.Is_Url (Link) then
         Pos := Ada.Strings.Wide_Wide_Fixed.Index (Link, ".", Ada.Strings.Backward);
         if Pos = 0 then
            return False;
         else
            return Wiki.Helpers.Is_Image_Extension (Link (Pos .. Link'Last));
         end if;
      elsif Link'Length <= 5 then
         return False;
      elsif Link (Link'First .. Link'First + 4) /= "File:" and
        Link (Link'First .. Link'First + 5) /= "Image:"
      then
         return False;
      else
         Pos := Ada.Strings.Wide_Wide_Fixed.Index (Link, ".", Ada.Strings.Backward);
         if Pos = 0 then
            return False;
         else
            return Wiki.Helpers.Is_Image_Extension (Link (Pos .. Link'Last));
         end if;
      end if;
   end Is_Image;

   --  ------------------------------
   --  Extract a list of parameters separated by the given separator (ex: '|').
   --  ------------------------------
   procedure Parse_Parameters (P          : in out Parser;
                               Separator  : in Wiki.Strings.WChar;
                               Terminator : in Wiki.Strings.WChar;
                               Names      : in String_Array) is
      procedure Add_Parameter (Content : in Wiki.Strings.WString);

      Index : Positive := 1;

      procedure Add_Parameter (Content : in Wiki.Strings.WString) is
      begin
         if Index <= Names'Last then
            Wiki.Attributes.Append (P.Attributes, Names (Index).all, Content);
         else
            Wiki.Attributes.Append (P.Attributes, Positive'Image (Index), Content);
         end if;
         Index := Index + 1;
      end Add_Parameter;

      procedure Add_Attribute is
         new Wiki.Strings.Wide_Wide_Builders.Get (Add_Parameter);

      C : Wiki.Strings.WChar;
   begin
      Wiki.Attributes.Clear (P.Attributes);
      loop
         Peek (P, C);
         if C = P.Escape_Char then
            Peek (P, C);
            Append (P.Text, C);
         elsif C = Separator then
            Add_Attribute (P.Text);
            Clear (P.Text);
         elsif C = Terminator or P.Is_Eof then
            Add_Attribute (P.Text);
            Clear (P.Text);
            return;
         else
            Append (P.Text, C);
         end if;
      end loop;
   end Parse_Parameters;

   NAME_ATTR  : aliased constant String := "name";
   HREF_ATTR  : aliased constant String := "href";
   LANG_ATTR  : aliased constant String := "lang";
   TITLE_ATTR : aliased constant String := "title";

   Attr_Names_Title_First : constant String_Array (1 .. 4)
     := (NAME_ATTR'Access, HREF_ATTR'Access, LANG_ATTR'Access, TITLE_ATTR'Access);

   Attr_Names_Link_First  : constant String_Array (1 .. 4)
     := (HREF_ATTR'Access, NAME_ATTR'Access, LANG_ATTR'Access, TITLE_ATTR'Access);

   Attr_Name              : constant String_Array (1 .. 1)
     := (1 => NAME_ATTR'Access);

   --  ------------------------------
   --  Parse a link.
   --  Example:
   --    [name]
   --    [url]
   --    [name|url]
   --    [name|url|language]
   --    [name|url|language|title]
   --  MediaWiki
   --    [[link]]
   --    [[link|name]]
   --    [[link|mode|size|center|alt]]
   --  ------------------------------
   procedure Parse_Link (P     : in out Parser;
                         Token : in Wiki.Strings.WChar) is
      C          : Wiki.Strings.WChar;
   begin
      --  If links have the form '[[link]]', check the second bracket.
      if P.Link_Double_Bracket then
         Peek (P, C);
         if C /= Token then
            Append (P.Text, Token);
            Put_Back (P, C);
            return;
         end if;
      end if;
      if P.Link_No_Space then
         Peek (P, C);
         if C = ' ' then
            Append (P.Text, Token);
            Put_Back (P, C);
            return;
         end if;
         Put_Back (P, C);
      end if;
      Flush_Text (P);

      Wiki.Attributes.Clear (P.Attributes);
      if P.Link_Title_First then
         Parse_Parameters (P, '|', ']', Attr_Names_Title_First);
      else
         Parse_Parameters (P, '|', ']', Attr_Names_Link_First);
      end if;

      if P.Link_Double_Bracket then
         Peek (P, C);
         if C /= ']' then
            Put_Back (P, C);
         end if;
      end if;
      P.Empty_Line := False;
      declare
         Link : constant Strings.WString := Attributes.Get_Attribute (P.Attributes, HREF_ATTR);
         Name : constant Strings.WString := Attributes.Get_Attribute (P.Attributes, NAME_ATTR);
      begin
         if P.Is_Image (Link) then
            Wiki.Attributes.Append (P.Attributes, String '("src"), Link);
            P.Context.Filters.Add_Image (P.Document, Name, P.Attributes);
         else
            if P.Link_Title_First and Link'Length = 0 then
               Wiki.Attributes.Append (P.Attributes, HREF_ATTR, Name);
            end if;
            if not P.Link_Title_First and Name'Length = 0 then
               P.Context.Filters.Add_Link (P.Document, Link, P.Attributes);
            else
               P.Context.Filters.Add_Link (P.Document, Name, P.Attributes);
            end if;
         end if;
      end;
      Peek (P, C);
      if not P.Is_Eof then
         if C = CR or C = LF then
            Append (P.Text, C);
         end if;
         Put_Back (P, C);
      end if;
   end Parse_Link;

   --  ------------------------------
   --  Find the plugin with the given name.
   --  Returns null if there is no such plugin.
   --  ------------------------------
   function Find (P    : in Parser;
                  Name : in Wiki.Strings.WString) return Wiki.Plugins.Wiki_Plugin_Access is
      use type Wiki.Plugins.Plugin_Factory_Access;
   begin
      if P.Context.Factory = null then
         return null;
      else
         return P.Context.Factory.Find (Wiki.Strings.To_String (Name));
      end if;
   end Find;

   --  ------------------------------
   --  Parse a template with parameters.
   --  Example:
   --    {{Name|param|...}}           MediaWiki
   --    {{Name|param=value|...}}     MediaWiki
   --    <<Name param=value ...>>     Creole
   --    [{Name param=value ...}]     JSPWiki
   --  ------------------------------
   procedure Parse_Template (P     : in out Parser;
                             Token : in Wiki.Strings.WChar) is
      use type Wiki.Plugins.Wiki_Plugin_Access;

      C      : Wiki.Strings.WChar;
      Expect : Wiki.Strings.WChar;
   begin
      Peek (P, C);
      if C /= Token then
         Append (P.Text, Token);
         Put_Back (P, C);
         return;
      end if;
      Flush_Text (P);

      if Token = '{' then
         Expect := '}';
      else
         Expect := '>';
      end if;
      Wiki.Attributes.Clear (P.Attributes);
      if P.Context.Syntax = SYNTAX_MEDIA_WIKI then
         Parse_Parameters (P, '|', Expect, Attr_Name);
      else
         Parse_Parameters (P, ' ', Expect, Attr_Name);
      end if;
      Peek (P, C);
      if C /= Expect then
         Put_Back (P, C);
      end if;
      P.Empty_Line := False;
      declare
         Name   : constant Strings.WString := Attributes.Get_Attribute (P.Attributes, NAME_ATTR);
         Plugin : constant Wiki.Plugins.Wiki_Plugin_Access := P.Find (Name);
         Context : Wiki.Plugins.Plugin_Context;
      begin
         if Plugin /= null then
            Context.Factory := P.Context.Factory;
            Context.Variables := P.Attributes;
            Plugin.Expand (P.Document, P.Attributes, Context);
         end if;
      end;
   end Parse_Template;

   --  ------------------------------
   --  Parse a quote.
   --  Example:
   --    {{name}}
   --    {{name|language}}
   --    {{name|language|url}}
   --  ------------------------------
   procedure Parse_Quote (P     : in out Parser;
                          Token : in Wiki.Strings.WChar) is

      --  Parse a quote component
      procedure Parse_Quote_Token (Into : in out Wiki.Strings.UString);

      Link       : Wiki.Strings.UString;
      Quote      : Wiki.Strings.UString;
      Language   : Wiki.Strings.UString;
      C          : Wiki.Strings.WChar;

      procedure Parse_Quote_Token (Into : in out Wiki.Strings.UString) is
      begin
         loop
            Peek (P, C);
            if C = P.Escape_Char then
               Peek (P, C);
            else
               exit when C = LF or C = CR or C = '}' or C = '|';
            end if;
            Wiki.Strings.Append (Into, C);
         end loop;
      end Parse_Quote_Token;

   begin
      Peek (P, C);
      if C /= Token then
         Append (P.Text, Token);
         Put_Back (P, C);
         return;
      end if;

      Parse_Quote_Token (Quote);
      if C = '|' then
         Parse_Quote_Token (Language);
         if C = '|' then
            Parse_Quote_Token (Link);
         end if;
      end if;
      if C /= '}' then
         Put_Back (P, C);
      end if;
      Flush_Text (P);
      Wiki.Attributes.Clear (P.Attributes);
      Wiki.Attributes.Append (P.Attributes, "cite", Link);
      Wiki.Attributes.Append (P.Attributes, "lang", Language);
      P.Context.Filters.Add_Quote (P.Document, Wiki.Strings.To_WString (Quote), P.Attributes);
      Peek (P, C);
      if C /= '}' then
         Put_Back (P, C);
      end if;
   end Parse_Quote;

   --  ------------------------------
   --  Parse a horizontal rule.
   --  Example:
   --    ---- (dotclear)
   --  ------------------------------
   procedure Parse_Horizontal_Rule (P     : in out Parser;
                                    Token : in Wiki.Strings.WChar) is
      C     : Wiki.Strings.WChar;
      Count : Natural := 1;
   begin
      loop
         Peek (P, C);
         exit when C /= Token;
         Count := Count + 1;
      end loop;
      if Count >= 4 then
         Flush_Text (P);
         Flush_List (P);
         P.Context.Filters.Add_Node (P.Document, Wiki.Nodes.N_HORIZONTAL_RULE);
         if C /= LF and C /= CR then
            Put_Back (P, C);
         end if;
      elsif P.Is_Dotclear and Count = 2 then
         Toggle_Format (P, STRIKEOUT);
         Put_Back (P, C);
      else
         for I in 1 .. Count loop
            Append (P.Text, Token);
         end loop;
         Put_Back (P, C);
      end if;
   end Parse_Horizontal_Rule;

   --  ------------------------------
   --  Parse an image.
   --  Example:
   --    ((url|alt text))
   --    ((url|alt text|position))
   --    ((url|alt text|position||description))
   --  ------------------------------
   procedure Parse_Image (P     : in out Parser;
                          Token : in Wiki.Strings.WChar) is

      --  Parse a image component
      procedure Parse_Image_Token (Into : in out Wiki.Strings.UString);

      Link       : Wiki.Strings.UString;
      Alt        : Wiki.Strings.UString;
      Position   : Wiki.Strings.UString;
      Desc       : Wiki.Strings.UString;
      C          : Wiki.Strings.WChar;

      procedure Parse_Image_Token (Into : in out Wiki.Strings.UString) is
      begin
         loop
            Peek (P, C);
            if C = P.Escape_Char then
               Peek (P, C);
            else
               exit when C = LF or C = CR or C = ')' or C = '|';
            end if;
            Wiki.Strings.Append (Into, C);
         end loop;
      end Parse_Image_Token;

   begin
      Peek (P, C);
      if C /= Token then
         Append (P.Text, Token);
         Put_Back (P, C);
         return;
      end if;

      Parse_Image_Token (Link);
      if C = '|' then
         Parse_Image_Token (Alt);
         if C = '|' then
            Parse_Image_Token (Position);
            if C = '|' then
               Parse_Image_Token (Desc);
            end if;
         end if;
      end if;
      if C /= ')' then
         Put_Back (P, C);
      end if;
      Flush_Text (P);
      Wiki.Attributes.Clear (P.Attributes);
      Wiki.Attributes.Append (P.Attributes, "src", Link);
      Wiki.Attributes.Append (P.Attributes, "position", Position);
      Wiki.Attributes.Append (P.Attributes, "longdesc", Desc);
      P.Context.Filters.Add_Image (P.Document, Wiki.Strings.To_WString (Alt), P.Attributes);
      Peek (P, C);
      if C /= ')' then
         Put_Back (P, C);
      end if;
   end Parse_Image;

   procedure Toggle_Format (P      : in out Parser;
                            Format : in Format_Type) is
   begin
      Flush_Text (P);
      P.Format (Format) := not P.Format (Format);
   end Toggle_Format;

   --  ------------------------------
   --  Parse the beginning or the end of a single character sequence.  This procedure
   --  is instantiated for several format types (bold, italic, superscript, subscript, code).
   --  Example:
   --    _name_    *bold*   `code`
   --  ------------------------------
   procedure Parse_Single_Format (P     : in out Parser;
                                  Token : in Wiki.Strings.WChar) is
      pragma Unreferenced (Token);
   begin
      Toggle_Format (P, Format);
   end Parse_Single_Format;

   procedure Parse_Single_Italic is new Parse_Single_Format (ITALIC);
   procedure Parse_Single_Bold is new Parse_Single_Format (BOLD);
   procedure Parse_Single_Code is new Parse_Single_Format (CODE);
   procedure Parse_Single_Superscript is new Parse_Single_Format (SUPERSCRIPT);
   --  procedure Parse_Single_Subscript is new Parse_Single_Format (SUBSCRIPT);
   --  procedure Parse_Single_Strikeout is new Parse_Single_Format (STRIKEOUT);

   --  ------------------------------
   --  Parse the beginning or the end of a double character sequence.  This procedure
   --  is instantiated for several format types (bold, italic, superscript, subscript, code).
   --  Example:
   --    --name--  **bold** ~~strike~~
   --  ------------------------------
   procedure Parse_Double_Format (P     : in out Parser;
                                  Token : in Wiki.Strings.WChar) is
      C : Wiki.Strings.WChar;
   begin
      Peek (P, C);
      if C = Token then
         Toggle_Format (P, Format);
      else
         Parse_Text (P, Token);
         Put_Back (P, C);
      end if;
   end Parse_Double_Format;

   procedure Parse_Double_Italic is new Parse_Double_Format (ITALIC);
   procedure Parse_Double_Bold is new Parse_Double_Format (BOLD);
   procedure Parse_Double_Code is new Parse_Double_Format (CODE);
   --  procedure Parse_Double_Superscript is new Parse_Double_Format (SUPERSCRIPT);
   procedure Parse_Double_Subscript is new Parse_Double_Format (SUBSCRIPT);
   procedure Parse_Double_Strikeout is new Parse_Double_Format (STRIKEOUT);

   --  ------------------------------
   --  Parse an italic, bold or bold + italic sequence.
   --  Example:
   --    ''name''         (italic)
   --    '''name'''       (bold)
   --    '''''name'''''   (bold+italic)
   --  ------------------------------
   procedure Parse_Bold_Italic (P     : in out Parser;
                                Token : in Wiki.Strings.WChar) is
      C     : Wiki.Strings.WChar;
      Count : Natural := 1;
   begin
      loop
         Peek (P, C);
         exit when C /= Token;
         Count := Count + 1;
      end loop;
      if Count > 10 then
         Count := Count mod 10;
         if Count = 0 then
            Put_Back (P, C);
            return;
         end if;
      end if;

      case Count is
         when 1 =>
            Parse_Text (P, Token);

         when 2 =>
            Toggle_Format (P, ITALIC);

         when 3 =>
            Toggle_Format (P, BOLD);

         when 4 =>
            Toggle_Format (P, BOLD);
            Parse_Text (P, Token);

         when 5 =>
            Toggle_Format (P, BOLD);
            Toggle_Format (P, ITALIC);

         when others =>
            null;
      end case;
      Put_Back (P, C);
   end Parse_Bold_Italic;

   procedure Parse_List (P     : in out Parser;
                         Token : in Wiki.Strings.WChar) is
      C     : Wiki.Strings.WChar;
      Level : Natural := 1;
   begin
      if not P.Empty_Line then
         Parse_Text (P, Token);
         return;
      end if;
      loop
         Peek (P, C);
         exit when C /= '#' and C /= '*';
         Level := Level + 1;
      end loop;
      Flush_Text (P);
      P.Context.Filters.Add_List_Item (P.Document, Level, Token = '#');

      --  Ignore the first white space after the list item.
      if C /= ' ' and C /= HT then
         Put_Back (P, C);
      end if;
   end Parse_List;

   procedure Parse_List_Or_Bold (P     : in out Parser;
                                 Token : in Wiki.Strings.WChar) is
      C     : Wiki.Strings.WChar;
      Level : Natural := 1;
   begin
      if not P.Empty_Line then
         Parse_Double_Bold (P, Token);
         return;
      end if;
      loop
         Peek (P, C);
         exit when C /= '#' and C /= '*';
         Level := Level + 1;
      end loop;
      Flush_Text (P);
      P.Context.Filters.Add_List_Item (P.Document, Level, Token = '#');

      --  Ignore the first white space after the list item.
      if C /= ' ' and C /= HT then
         Put_Back (P, C);
      end if;
   end Parse_List_Or_Bold;

   --  ------------------------------
   --  Parse a list definition:
   --    ;item 1
   --    : definition 1
   --  ------------------------------
   procedure Parse_Item (P     : in out Parser;
                         Token : in Wiki.Strings.WChar) is
   begin
      if not P.Empty_Line then
         Parse_Text (P, Token);
         return;
      end if;
      Flush_Text (P);
      Wiki.Attributes.Clear (P.Attributes);
      if not P.In_List then
         P.Context.Filters.Push_Node (P.Document, Wiki.DL_TAG, P.Attributes);
         P.In_List := True;
      end if;
      P.Context.Filters.Push_Node (P.Document, Wiki.DT_TAG, P.Attributes);
   end Parse_Item;

   --  ------------------------------
   --  Parse a list definition:
   --    ;item 1
   --    : definition 1
   --  ------------------------------
   procedure Parse_Definition (P     : in out Parser;
                               Token : in Wiki.Strings.WChar) is
   begin
      if not P.Empty_Line then
         Parse_Text (P, Token);
         return;
      end if;
      Flush_Text (P);
      Wiki.Attributes.Clear (P.Attributes);
      P.Context.Filters.Push_Node (P.Document, Wiki.DD_TAG, P.Attributes);
   end Parse_Definition;

   --  ------------------------------
   --  Parse a blockquote.
   --  Example:
   --    >>>quote level 3
   --    >>quote level 2
   --    >quote level 1
   --  ------------------------------
   procedure Parse_Blockquote (P     : in out Parser;
                               Token : in Wiki.Strings.WChar) is
      C     : Wiki.Strings.WChar;
      Level : Natural := 1;
   begin
      if not P.Empty_Line then
         Parse_Text (P, Token);
         return;
      end if;
      loop
         Peek (P, C);
         exit when C /= '>';
         Level := Level + 1;
      end loop;
      Flush_Text (P);
      Flush_List (P);
      P.Empty_Line := True;
      P.Quote_Level := Level;
      P.Context.Filters.Add_Blockquote (P.Document, Level);

      --  Ignore the first white space after the quote character.
      if C /= ' ' and C /= HT then
         Put_Back (P, C);
      end if;
   end Parse_Blockquote;

   --  ------------------------------
   --  Parse a space and take necessary formatting actions.
   --  Example:
   --    item1 item2   => add space in text buffer
   --    ' * item'     => start a bullet list (Google)
   --    ' # item'     => start an ordered list (Google)
   --    ' item'       => preformatted text (Google, Creole)
   --  ------------------------------
   procedure Parse_Space (P     : in out Parser;
                          Token : in Wiki.Strings.WChar) is
      C     : Wiki.Strings.WChar;
   begin
      if P.Empty_Line then
         loop
            Peek (P, C);
            exit when C /= ' ' and C /= HT;
         end loop;
         if C = '*' or C = '#' then
            Parse_List (P, C);
         elsif C = CR or C = LF then
            Parse_End_Line (P, C);
         else
            Put_Back (P, C);
            Parse_Preformatted (P, Token);
         end if;
      else
         Append (P.Text, Token);
      end if;
   end Parse_Space;

   procedure Parse_End_Line (P     : in out Parser;
                             Token : in Wiki.Strings.WChar) is
      C     : Wiki.Strings.WChar := Token;
      Count : Positive := 1;
   begin
      if P.Is_Eof then
         return;
      end if;
      while not P.Is_Eof loop
         Peek (P, C);
         exit when C /= CR and C /= LF;
         if C = Token then
            Count := Count + 1;
         end if;
      end loop;
      Put_Back (P, C);
      if Count >= 2 then
         Flush_Text (P);
         Flush_List (P);

         --  Finish the active blockquotes if a new paragraph is started on an empty line.
         if P.Quote_Level > 0 then
            P.Context.Filters.Add_Blockquote (P.Document, 0);
            P.Quote_Level := 0;
         end if;
         P.Context.Filters.Add_Node (P.Document, Wiki.Nodes.N_PARAGRAPH);
         P.In_Paragraph := True;
      elsif Length (P.Text) > 0 or not P.Empty_Line then
         Append (P.Text, LF);
      end if;

      --  Finish the active blockquotes if a new paragraph is started immediately after
      --  the blockquote.
      if P.Quote_Level > 0 and C /= '>' then
         Flush_Text (P);
         P.Context.Filters.Add_Blockquote (P.Document, 0);
         P.Quote_Level := 0;
      end if;
      P.Empty_Line := True;
   end Parse_End_Line;

   --  ------------------------------
   --  Parse a line break.
   --  Example:
   --     \\    (Creole)
   --     %%%   (Dotclear)
   --  ------------------------------
   procedure Parse_Line_Break (P     : in out Parser;
                               Token : in Wiki.Strings.WChar) is
      C : Wiki.Strings.WChar;
   begin
      Peek (P, C);

      --  Check for escape character
      if Token = P.Escape_Char then
         Parse_Text (P, C);
         return;
      end if;
      if C /= Token then
         Parse_Text (P, Token);
         Put_Back (P, C);
         return;
      end if;

      --  Check for a third '%'.
      if P.Is_Dotclear then
         Peek (P, C);
         if C /= Token then
            Parse_Text (P, Token);
            Parse_Text (P, Token);
            Put_Back (P, C);
            return;
         end if;
      end if;
      P.Empty_Line := True;
      Flush_Text (P);
      P.Context.Filters.Add_Node (P.Document, Wiki.Nodes.N_LINE_BREAK);
   end Parse_Line_Break;

   --  ------------------------------
   --  Parse a HTML component.
   --  Example:
   --     <b> or </b>
   --  ------------------------------
   procedure Parse_Maybe_Html (P     : in out Parser;
                               Token : in Wiki.Strings.WChar) is
      pragma Unreferenced (Token);
   begin
      Wiki.Parsers.Html.Parse_Element (P);
   end Parse_Maybe_Html;

   Google_Wiki_Table : aliased constant Parser_Table
     := (
         16#0A# => Parse_End_Line'Access,
         16#0D# => Parse_End_Line'Access,
         Character'Pos (' ') => Parse_Space'Access,
         Character'Pos ('=') => Parse_Header'Access,
         Character'Pos ('*') => Parse_Single_Bold'Access,
         Character'Pos ('_') => Parse_Single_Italic'Access,
         Character'Pos ('`') => Parse_Single_Code'Access,
         Character'Pos ('^') => Parse_Single_Superscript'Access,
         Character'Pos ('~') => Parse_Double_Strikeout'Access,
         Character'Pos (',') => Parse_Double_Subscript'Access,
         Character'Pos ('[') => Parse_Link'Access,
         Character'Pos ('\') => Parse_Line_Break'Access,
         Character'Pos ('#') => Parse_List'Access,
         Character'Pos ('{') => Parse_Preformatted'Access,
         Character'Pos ('}') => Parse_Preformatted'Access,
         Character'Pos ('<') => Parse_Maybe_Html'Access,
         others => Parse_Text'Access
        );

   Dotclear_Wiki_Table : aliased constant Parser_Table
     := (
         16#0A# => Parse_End_Line'Access,
         16#0D# => Parse_End_Line'Access,
         Character'Pos (' ') => Parse_Space'Access,
         Character'Pos ('!') => Parse_Header'Access,
         Character'Pos ('_') => Parse_Double_Bold'Access,
         Character'Pos (''') => Parse_Double_Italic'Access,
         Character'Pos ('@') => Parse_Double_Code'Access,
         Character'Pos ('^') => Parse_Single_Superscript'Access,
         Character'Pos ('-') => Parse_Horizontal_Rule'Access,
         Character'Pos ('+') => Parse_Double_Strikeout'Access,
         Character'Pos (',') => Parse_Double_Subscript'Access,
         Character'Pos ('[') => Parse_Link'Access,
         Character'Pos ('\') => Parse_Line_Break'Access,
         Character'Pos ('{') => Parse_Quote'Access,
         Character'Pos ('#') => Parse_List'Access,
         Character'Pos ('*') => Parse_List'Access,
         Character'Pos ('(') => Parse_Image'Access,
         Character'Pos ('/') => Parse_Preformatted'Access,
         Character'Pos ('%') => Parse_Line_Break'Access,
         Character'Pos ('>') => Parse_Blockquote'Access,
         others => Parse_Text'Access
        );

   Creole_Wiki_Table : aliased constant Parser_Table
     := (
         16#0A# => Parse_End_Line'Access,
         16#0D# => Parse_End_Line'Access,
         Character'Pos (' ') => Parse_Space'Access,
         Character'Pos ('=') => Parse_Header'Access,
         Character'Pos ('*') => Parse_List_Or_Bold'Access,
         Character'Pos ('/') => Parse_Double_Italic'Access,
         Character'Pos ('@') => Parse_Double_Code'Access,
         Character'Pos ('^') => Parse_Single_Superscript'Access,
         Character'Pos ('-') => Parse_Double_Strikeout'Access,
         Character'Pos ('+') => Parse_Double_Strikeout'Access,
         Character'Pos (',') => Parse_Double_Subscript'Access,
         Character'Pos ('[') => Parse_Link'Access,
         Character'Pos ('\') => Parse_Line_Break'Access,
         Character'Pos ('#') => Parse_List'Access,
         Character'Pos ('{') => Parse_Image'Access,
         Character'Pos ('%') => Parse_Line_Break'Access,
         Character'Pos (';') => Parse_Item'Access,
         Character'Pos ('<') => Parse_Template'Access,
         Character'Pos (':') => Parse_Definition'Access,
         others => Parse_Text'Access
        );

   Markdown_Wiki_Table : aliased constant Parser_Table
     := (
         16#0A# => Parse_End_Line'Access,
         16#0D# => Parse_End_Line'Access,
         Character'Pos (' ') => Parse_Space'Access,
         Character'Pos ('#') => Parse_Header'Access,
         Character'Pos ('*') => Parse_Double_Bold'Access,
         Character'Pos ('/') => Parse_Double_Italic'Access,
         Character'Pos ('@') => Parse_Double_Code'Access,
         Character'Pos ('^') => Parse_Single_Superscript'Access,
         Character'Pos ('-') => Parse_Double_Strikeout'Access,
         Character'Pos ('+') => Parse_Double_Strikeout'Access,
         Character'Pos (',') => Parse_Double_Subscript'Access,
         Character'Pos ('[') => Parse_Link'Access,
         Character'Pos ('\') => Parse_Line_Break'Access,
         Character'Pos ('{') => Parse_Image'Access,
         Character'Pos ('%') => Parse_Line_Break'Access,
         Character'Pos ('<') => Parse_Maybe_Html'Access,
         Character'Pos ('`') => Parse_Preformatted'Access,
         others => Parse_Text'Access
        );

   Mediawiki_Wiki_Table : aliased constant Parser_Table
     := (
         16#0A# => Parse_End_Line'Access,
         16#0D# => Parse_End_Line'Access,
         Character'Pos (' ') => Parse_Space'Access,
         Character'Pos ('=') => Parse_Header'Access,
         Character'Pos (''') => Parse_Bold_Italic'Access,
         Character'Pos ('[') => Parse_Link'Access,
         Character'Pos ('\') => Parse_Line_Break'Access,
         Character'Pos ('#') => Parse_List'Access,
         Character'Pos ('*') => Parse_List'Access,
         Character'Pos ('<') => Parse_Maybe_Html'Access,
         Character'Pos ('&') => Html.Parse_Entity'Access,
         Character'Pos ('-') => Parse_Horizontal_Rule'Access,
         Character'Pos (';') => Parse_Item'Access,
         Character'Pos ('{') => Parse_Template'Access,
         Character'Pos (':') => Parse_Definition'Access,
         others => Parse_Text'Access
        );

   Misc_Wiki_Table : aliased constant Parser_Table
     := (
         16#0A# => Parse_End_Line'Access,
         16#0D# => Parse_End_Line'Access,
         Character'Pos (' ') => Parse_Space'Access,
         Character'Pos ('=') => Parse_Header'Access,
         Character'Pos ('*') => Parse_Single_Bold'Access,
         Character'Pos ('_') => Parse_Single_Italic'Access,
         Character'Pos ('`') => Parse_Single_Code'Access,
         Character'Pos ('^') => Parse_Single_Superscript'Access,
         Character'Pos ('~') => Parse_Double_Strikeout'Access,
         Character'Pos (',') => Parse_Double_Subscript'Access,
         Character'Pos ('[') => Parse_Link'Access,
         Character'Pos ('\') => Parse_Line_Break'Access,
         Character'Pos ('#') => Parse_List'Access,
         Character'Pos ('@') => Parse_Double_Code'Access,
         Character'Pos ('<') => Parse_Maybe_Html'Access,
         others => Parse_Text'Access
        );

   Html_Table : aliased constant Parser_Table
     := (
         Character'Pos ('<') => Parse_Maybe_Html'Access,
         Character'Pos ('&') => Html.Parse_Entity'Access,
         others => Parse_Text'Access
        );

   type Syntax_Parser_Tables is array (Wiki_Syntax) of Parser_Table_Access;

   Syntax_Tables : constant Syntax_Parser_Tables
     := (
         SYNTAX_GOOGLE     => Google_Wiki_Table'Access,
         SYNTAX_CREOLE     => Creole_Wiki_Table'Access,
         SYNTAX_DOTCLEAR   => Dotclear_Wiki_Table'Access,
         SYNTAX_PHPBB      => Mediawiki_Wiki_Table'Access,
         SYNTAX_MEDIA_WIKI => Mediawiki_Wiki_Table'Access,
         SYNTAX_MARKDOWN   => Markdown_Wiki_Table'Access,
         SYNTAX_MIX        => Misc_Wiki_Table'Access,
         SYNTAX_HTML       => Html_Table'Access
        );

   procedure Start_Element (P          : in out Parser;
                            Tag        : in Wiki.Html_Tag;
                            Attributes : in out Wiki.Attributes.Attribute_List) is
   begin
      Flush_Text (P);
      P.Context.Filters.Push_Node (P.Document, Tag, Attributes);

      --  When we are within a <pre> HTML element, switch to HTML to emit the text as is.
      if Tag = PRE_TAG and P.Context.Syntax /= SYNTAX_HTML then
         P.Previous_Syntax := P.Context.Syntax;
         P.Set_Syntax (SYNTAX_HTML);
      end if;
   end Start_Element;

   procedure End_Element (P    : in out Parser;
                          Tag  : in Wiki.Html_Tag) is
   begin
      Flush_Text (P);
      P.Context.Filters.Pop_Node (P.Document, Tag);

      --  Switch back to the previous syntax when we reached the </pre> HTML element.
      if P.Previous_Syntax /= P.Context.Syntax and Tag = PRE_TAG then
         P.Set_Syntax (P.Previous_Syntax);
      end if;
   end End_Element;

   --  ------------------------------
   --  Set the plugin factory to find and use plugins.
   --  ------------------------------
   procedure Set_Plugin_Factory (Engine  : in out Parser;
                                 Factory : in Wiki.Plugins.Plugin_Factory_Access) is
   begin
      Engine.Context.Factory := Factory;
   end Set_Plugin_Factory;

   --  ------------------------------
   --  Set the wiki syntax that the wiki engine must use.
   --  ------------------------------
   procedure Set_Syntax (Engine : in out Parser;
                         Syntax : in Wiki_Syntax := SYNTAX_MIX) is
   begin
      Engine.Context.Syntax := Syntax;
      Engine.Table  := Syntax_Tables (Syntax);
   end Set_Syntax;

   --  ------------------------------
   --  Add a filter in the wiki engine.
   --  ------------------------------
   procedure Add_Filter (Engine : in out Parser;
                         Filter : in Wiki.Filters.Filter_Type_Access) is
   begin
      Engine.Context.Filters.Add_Filter (Filter);
   end Add_Filter;

   --  ------------------------------
   --  Set the plugin context.
   --  ------------------------------
   procedure Set_Context (Engine  : in out Parser;
                          Context : in Wiki.Plugins.Plugin_Context) is
   begin
      Engine.Context.Filters.Set_Chain (Context.Filters);
      Engine.Context.Factory   := Context.Factory;
      Engine.Context.Variables := Context.Variables;
      Engine.Set_Syntax (Context.Syntax);
   end Set_Context;

   --  ------------------------------
   --  Parse the wiki text contained in <b>Text</b> according to the wiki syntax
   --  defined on the parser.
   --  ------------------------------
   procedure Parse (Engine : in out Parser;
                    Text   : in Wide_Wide_String;
                    Doc    : in out Wiki.Documents.Document) is

      type Wide_Input is new Wiki.Streams.Input_Stream with record
         Pos : Positive;
      end record;

      overriding
      procedure Read (Buf    : in out Wide_Input;
                      Token  : out Wiki.Strings.WChar;
                      Is_Eof : out Boolean);

      procedure Read (Buf    : in out Wide_Input;
                      Token  : out Wiki.Strings.WChar;
                      Is_Eof : out Boolean) is
      begin
         if Buf.Pos > Text'Last then
            Is_Eof := True;
            Token := CR;
         else
            Token := Text (Buf.Pos);
            Buf.Pos := Buf.Pos + 1;
            Is_Eof := False;
         end if;
      end Read;

      Buffer : aliased Wide_Input;
   begin
      Buffer.Pos   := Text'First;
      Engine.Parse (Buffer'Unchecked_Access, Doc);
   end Parse;

   --  ------------------------------
   --  Parse the wiki text contained in <b>Text</b> according to the wiki syntax
   --  defined on the parser.
   --  ------------------------------
   procedure Parse (Engine : in out Parser;
                    Text   : in Wiki.Strings.UString;
                    Doc    : in out Wiki.Documents.Document) is

      type Wide_Input is new Wiki.Streams.Input_Stream with record
         Pos : Positive;
         Len : Natural;
      end record;

      overriding
      procedure Read (Buf    : in out Wide_Input;
                      Token  : out Wiki.Strings.WChar;
                      Is_Eof : out Boolean);

      procedure Read (Buf    : in out Wide_Input;
                      Token  : out Wiki.Strings.WChar;
                      Is_Eof : out Boolean) is
      begin
         if Buf.Pos > Buf.Len then
            Is_Eof := True;
            Token := CR;
         else
            Token := Wiki.Strings.Element (Text, Buf.Pos);
            Buf.Pos := Buf.Pos + 1;
            Is_Eof := False;
         end if;
      end Read;

      Buffer : aliased Wide_Input;
   begin
      Buffer.Pos   := 1;
      Buffer.Len   := Wiki.Strings.Length (Text);
      Engine.Parse (Buffer'Unchecked_Access, Doc);
   end Parse;

   --  ------------------------------
   --  Parse the wiki stream managed by <tt>Stream</tt> according to the wiki syntax configured
   --  on the wiki engine.
   --  ------------------------------
   procedure Parse (Engine : in out Parser;
                    Stream : in Wiki.Streams.Input_Stream_Access;
                    Doc    : in out Wiki.Documents.Document) is
   begin
      Engine.Document   := Doc;
      Engine.Previous_Syntax := Engine.Context.Syntax;
      Engine.Empty_Line := True;
      Engine.Format     := (others => False);
      Engine.Is_Eof     := False;
      Engine.In_Paragraph := True;
      Engine.Has_Pending := False;
      Engine.Reader      := Stream;
      Engine.Link_Double_Bracket := False;
      Engine.Escape_Char := '~';
      Engine.Context.Filters.Add_Node (Engine.Document, Wiki.Nodes.N_PARAGRAPH);
      case Engine.Context.Syntax is
         when SYNTAX_DOTCLEAR =>
            Engine.Is_Dotclear := True;
            Engine.Escape_Char := '\';
            Engine.Header_Offset := -6;
            Engine.Link_Title_First := True;

         when SYNTAX_CREOLE =>
            Engine.Link_Double_Bracket := True;

         when SYNTAX_MEDIA_WIKI =>
            Engine.Link_Double_Bracket := True;
            Engine.Check_Image_Link := True;

         when SYNTAX_MIX =>
            Engine.Is_Dotclear := True;

         when SYNTAX_GOOGLE =>
            Engine.Link_No_Space := True;

         when others =>
            null;

      end case;
      Parse_Token (Engine);
      Flush_Text (Engine);
      Engine.Context.Filters.Finish (Engine.Document);
      Doc := Engine.Document;
   end Parse;

   procedure Parse_Token (P : in out Parser) is
      C : Wiki.Strings.WChar;
   begin
      loop
         Peek (P, C);
         exit when P.Is_Eof;
         if C > '~' then
            Parse_Text (P, C);
         else
            P.Table (Wiki.Strings.WChar'Pos (C)).all (P, C);
         end if;
      end loop;
   end Parse_Token;

end Wiki.Parsers;
