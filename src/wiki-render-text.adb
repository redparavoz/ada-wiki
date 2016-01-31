-----------------------------------------------------------------------
--  wiki-render-text -- Wiki Text renderer
--  Copyright (C) 2011, 2012, 2013, 2015 Stephane Carrez
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
with Ada.Characters.Conversions;
with Wiki.Helpers;
package body Wiki.Render.Text is

   --  ------------------------------
   --  Set the output writer.
   --  ------------------------------
   procedure Set_Output_Stream (Engine : in out Text_Renderer;
                                Stream : in Streams.Output_Stream_Access) is
   begin
      Engine.Output := Stream;
   end Set_Output_Stream;

   --  ------------------------------
   --  Emit a new line.
   --  ------------------------------
   procedure New_Line (Document : in out Text_Renderer) is
   begin
      Document.Output.Write (Wiki.Helpers.LF);
      Document.Empty_Line := True;
   end New_Line;

   --  ------------------------------
   --  Add a line break (<br>).
   --  ------------------------------
   procedure Add_Line_Break (Document : in out Text_Renderer) is
   begin
      Document.Output.Write (Wiki.Helpers.LF);
      Document.Empty_Line := True;
   end Add_Line_Break;

   --  ------------------------------
   --  Add a blockquote (<blockquote>).  The level indicates the blockquote nested level.
   --  The blockquote must be closed at the next header.
   --  ------------------------------
   procedure Add_Blockquote (Document : in out Text_Renderer;
                             Level    : in Natural) is
   begin
      Document.Close_Paragraph;
      for I in 1 .. Level loop
         Document.Output.Write ("  ");
      end loop;
   end Add_Blockquote;

   --  ------------------------------
   --  Add a list item (<li>).  Close the previous paragraph and list item if any.
   --  The list item will be closed at the next list item, next paragraph or next header.
   --  ------------------------------
   procedure Add_List_Item (Document : in out Text_Renderer;
                            Level    : in Positive;
                            Ordered  : in Boolean) is
      pragma Unreferenced (Level, Ordered);
   begin
      if not Document.Empty_Line then
         Document.Add_Line_Break;
      end if;
      Document.Need_Paragraph := False;
      Document.Open_Paragraph;
   end Add_List_Item;

   procedure Close_Paragraph (Document : in out Text_Renderer) is
   begin
      if Document.Has_Paragraph then
         Document.Add_Line_Break;
      end if;
      Document.Has_Paragraph := False;
   end Close_Paragraph;

   procedure Open_Paragraph (Document : in out Text_Renderer) is
   begin
      if Document.Need_Paragraph then
         Document.Has_Paragraph  := True;
         Document.Need_Paragraph := False;
      end if;
   end Open_Paragraph;

   --  ------------------------------
   --  Add a link.
   --  ------------------------------
   procedure Add_Link (Document : in out Text_Renderer;
                       Title    : in Wiki.Strings.WString;
                       Attr     : in Wiki.Attributes.Attribute_List_Type) is
   begin
      Document.Open_Paragraph;
      if Title'Length /= 0 then
         Document.Output.Write (Title);
      end if;
      Document.Empty_Line := False;
   end Add_Link;

   --  ------------------------------
   --  Add an image.
   --  ------------------------------
   procedure Add_Image (Document    : in out Text_Renderer;
                        Link        : in Unbounded_Wide_Wide_String;
                        Alt         : in Unbounded_Wide_Wide_String;
                        Position    : in Unbounded_Wide_Wide_String;
                        Description : in Unbounded_Wide_Wide_String) is
      pragma Unreferenced (Position);
   begin
      Document.Open_Paragraph;
--        if Length (Alt) > 0 then
--           Document.Output.Write (Alt);
--        end if;
--        if Length (Description) > 0 then
--           Document.Output.Write (Description);
--        end if;
--        Document.Output.Write (Link);
      Document.Empty_Line := False;
   end Add_Image;

   --  ------------------------------
   --  Add a text block that is pre-formatted.
   --  ------------------------------
   procedure Add_Preformatted (Document : in out Text_Renderer;
                               Text     : in Unbounded_Wide_Wide_String;
                               Format   : in Unbounded_Wide_Wide_String) is
      pragma Unreferenced (Format);
   begin
      Document.Close_Paragraph;
--        Document.Output.Write (Text);
      Document.Empty_Line := False;
   end Add_Preformatted;

   --  Render the node instance from the document.
   overriding
   procedure Render (Engine : in out Text_Renderer;
                     Doc    : in Wiki.Nodes.Document;
                     Node   : in Wiki.Nodes.Node_Type) is
      use type Wiki.Nodes.Html_Tag_Type;
      use type Wiki.Nodes.Node_List_Access;
   begin
      case Node.Kind is
         when Wiki.Nodes.N_HEADER =>
            Engine.Close_Paragraph;
            if not Engine.Empty_Line then
               Engine.Add_Line_Break;
            end if;
            Engine.Output.Write (Node.Header);
            Engine.Add_Line_Break;

         when Wiki.Nodes.N_LINE_BREAK =>
            Engine.Add_Line_Break;

         when Wiki.Nodes.N_HORIZONTAL_RULE =>
            Engine.Close_Paragraph;
            Engine.Output.Write ("---------------------------------------------------------");
            Engine.Add_Line_Break;

         when Wiki.Nodes.N_PARAGRAPH =>
            Engine.Close_Paragraph;
            Engine.Need_Paragraph := True;
            Engine.Add_Line_Break;

         when Wiki.Nodes.N_INDENT =>
            Engine.Indent_Level := Node.Level;

         when Wiki.Nodes.N_TEXT =>
            if Engine.Empty_Line and Engine.Indent_Level /= 0 then
               for I in 1 .. Engine.Indent_Level loop
                  Engine.Output.Write (' ');
               end loop;
            end if;
            Engine.Output.Write (Node.Text);
            Engine.Empty_Line := False;

         when Wiki.Nodes.N_QUOTE =>
            Engine.Open_Paragraph;
            Engine.Output.Write (Node.Quote);
            Engine.Empty_Line := False;

         when Wiki.Nodes.N_LINK =>
            Engine.Add_Link (Node.Title, Node.Link_Attr);

         when Wiki.Nodes.N_IMAGE =>
            null;

         when Wiki.Nodes.N_BLOCKQUOTE =>
            null;

         when Wiki.Nodes.N_TAG_START =>
            if Node.Children /= null then
               if Node.Tag_Start = Wiki.Nodes.DT_TAG then
                  Engine.Close_Paragraph;
                  Engine.Indent_Level := 0;
                  Engine.Render (Doc, Node.Children);
                  Engine.Close_Paragraph;
                  Engine.Indent_Level := 0;
               elsif Node.Tag_Start = Wiki.Nodes.DD_TAG then
                  Engine.Close_Paragraph;
                  Engine.Empty_Line := True;
                  Engine.Indent_Level := 4;
                  Engine.Render (Doc, Node.Children);
                  Engine.Close_Paragraph;
                  Engine.Indent_Level := 0;
               else
                  Engine.Render (Doc, Node.Children);
                  if Node.Tag_Start = Wiki.Nodes.DL_TAG then
                     Engine.Close_Paragraph;
                     Engine.New_Line;
                  end if;
               end if;
            end if;

      end case;
   end Render;
--
   --  ------------------------------
   --  Finish the document after complete wiki text has been parsed.
   --  ------------------------------
   overriding
   procedure Finish (Document : in out Text_Renderer) is
   begin
      Document.Close_Paragraph;
   end Finish;

end Wiki.Render.Text;
