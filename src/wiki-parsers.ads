-----------------------------------------------------------------------
--  wiki-parsers -- Wiki parser
--  Copyright (C) 2011, 2015 Stephane Carrez
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
with Ada.Strings.Wide_Wide_Unbounded;

with Wiki.Documents;
with Wiki.Attributes;

--  == Wiki Parsers ==
--  The <b>Wikis.Parsers</b> package implements a parser for several well known wiki formats.
--  The parser works with the <b>Document_Reader</b> interface type which defines several
--  procedures that are called by the parser when the wiki text is scanned.
package Wiki.Parsers is

   pragma Preelaborate;

   --  Defines the possible wiki syntax supported by the parser.
   type Wiki_Syntax_Type
     is (
         --  Google wiki syntax http://code.google.com/p/support/wiki/WikiSyntax
         SYNTAX_GOOGLE,

         --  Creole wiki syntax http://www.wikicreole.org/wiki/Creole1.0
         SYNTAX_CREOLE,

         --  Dotclear syntax http://dotclear.org/documentation/2.0/usage/syntaxes
         SYNTAX_DOTCLEAR,

         --  PhpBB syntax http://wiki.phpbb.com/Help:Formatting
         SYNTAX_PHPBB,

         --  MediaWiki syntax http://www.mediawiki.org/wiki/Help:Formatting
         SYNTAX_MEDIA_WIKI,

         --  Markdown
         SYNTAX_MARKDOWN,

         --  A mix of the above
         SYNTAX_MIX);

   --  Parse the wiki text contained in <b>Text</b> according to the wiki syntax
   --  specified in <b>Syntax</b> and invoke the document reader procedures defined
   --  by <b>into</b>.
   procedure Parse (Into   : in Wiki.Documents.Document_Reader_Access;
                    Text   : in Wide_Wide_String;
                    Syntax : in Wiki_Syntax_Type := SYNTAX_MIX);

private

   use Ada.Strings.Wide_Wide_Unbounded;

   HT : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#09#);
   LF : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#0A#);
   CR : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#0D#);

   type Input is interface;
   type Input_Access is access all Input'Class;
   procedure Read_Char (From : in out Input;
                        Token : out Wide_Wide_Character;
                        Eof   : out Boolean) is abstract;

   type Parser is limited record
      Pending             : Wide_Wide_Character;
      Has_Pending         : Boolean;
      Document            : Wiki.Documents.Document_Reader_Access;
      Format              : Wiki.Documents.Format_Map;
      Text                : Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
      Token               : Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
      Empty_Line          : Boolean := True;
      Is_Eof              : Boolean := False;
      In_Paragraph        : Boolean := False;
      In_List             : Boolean := False;
      Need_Paragraph      : Boolean := True;
      Link_Double_Bracket : Boolean := False;
      Is_Dotclear         : Boolean := False;
      Header_Offset       : Integer := 0;
      Quote_Level         : Natural := 0;
      Escape_Char         : Wide_Wide_Character;
      List_Level          : Natural := 0;
      Reader              : Input_Access := null;
      Attributes          : Wiki.Attributes.Attribute_List_Type;
   end record;

   type Parser_Handler is access procedure (P     : in out Parser;
                                            Token : in Wide_Wide_Character);

   type Parser_Table is array (0 .. 127) of Parser_Handler;
   type Parser_Table_Access is access Parser_Table;

   --  Peek the next character from the wiki text buffer.
   procedure Peek (P     : in out Parser;
                   Token : out Wide_Wide_Character);

   --  Put back the character so that it will be returned by the next call to Peek.
   procedure Put_Back (P     : in out Parser;
                       Token : in Wide_Wide_Character);

   --  Flush the wiki text that was collected in the text buffer.
   procedure Flush_Text (P : in out Parser);

   --  Flush the wiki dl/dt/dd definition list.
   procedure Flush_List (P : in out Parser);

   procedure Start_Element (P          : in out Parser;
                            Name       : in Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
                            Attributes : in Wiki.Attributes.Attribute_List_Type);

   procedure End_Element (P    : in out Parser;
                          Name : in Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String);

end Wiki.Parsers;
