-----------------------------------------------------------------------
--  wiki-render-html -- Wiki HTML renderer
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
with Ada.Characters.Conversions;
with Util.Strings;

package body Wiki.Render.Html is

   package ACC renames Ada.Characters.Conversions;

   --  ------------------------------
   --  Set the output stream.
   --  ------------------------------
   procedure Set_Output_Stream (Engine : in out Html_Renderer;
                                Stream : in Wiki.Streams.Html.Html_Output_Stream_Access) is
   begin
      Engine.Output := Stream;
   end Set_Output_Stream;

   --  ------------------------------
   --  Set the link renderer.
   --  ------------------------------
   procedure Set_Link_Renderer (Document : in out Html_Renderer;
                                Links    : in Link_Renderer_Access) is
   begin
      Document.Links := Links;
   end Set_Link_Renderer;

   --  ------------------------------
   --  Render the node instance from the document.
   --  ------------------------------
   overriding
   procedure Render (Engine : in out Html_Renderer;
                     Doc    : in Wiki.Nodes.Document;
                     Node   : in Wiki.Nodes.Node_Type) is
      use type Wiki.Nodes.Html_Tag_Type;
      use type Wiki.Nodes.Node_List_Access;
   begin
      case Node.Kind is
         when Wiki.Nodes.N_HEADER =>
            Engine.Add_Header (Header => Node.Header,
                               Level  => Node.Level);

         when Wiki.Nodes.N_LINE_BREAK =>
            Engine.Output.Start_Element ("br");
            Engine.Output.End_Element ("br");

         when Wiki.Nodes.N_HORIZONTAL_RULE =>
            Engine.Close_Paragraph;
            Engine.Add_Blockquote (0);
            Engine.Output.Start_Element ("hr");
            Engine.Output.End_Element ("hr");

         when Wiki.Nodes.N_PARAGRAPH =>
            Engine.Close_Paragraph;
            Engine.Need_Paragraph := True;

         when Wiki.Nodes.N_INDENT =>
            -- Engine.Indent_Level := Node.Level;
            null;

         when Wiki.Nodes.N_TEXT =>
            Engine.Add_Text (Text   => Node.Text,
                             Format => Node.Format);

         when Wiki.Nodes.N_QUOTE =>
            Engine.Open_Paragraph;
            Engine.Output.Write (Node.Quote);

         when Wiki.Nodes.N_LINK =>
            if Node.Image then
               Engine.Add_Link (Node.Title, Node.Link_Attr);
            else
               Engine.Render_Link (Doc, Node.Title, Node.Link_Attr);
            end if;

         when Wiki.Nodes.N_BLOCKQUOTE =>
            Engine.Add_Blockquote (Node.Level);

         when Wiki.Nodes.N_TAG_START =>
            Engine.Render_Tag (Doc, Node);

      end case;
   end Render;

   procedure Render_Tag (Engine : in out Html_Renderer;
                         Doc    : in Wiki.Nodes.Document;
                         Node   : in Wiki.Nodes.Node_Type) is
      use type Wiki.Nodes.Html_Tag_Type;

      Name : constant Wiki.Nodes.String_Access := Wiki.Nodes.Get_Tag_Name (Node.Tag_Start);
      Iter : Wiki.Attributes.Cursor := Wiki.Attributes.First (Node.Attributes);
   begin
      if Node.Tag_Start = Wiki.Nodes.P_TAG then
         Engine.Has_Paragraph := True;
         Engine.Need_Paragraph := False;
      end if;
      Engine.Output.Start_Element (Name.all);
      while Wiki.Attributes.Has_Element (Iter) loop
         Engine.Output.Write_Wide_Attribute (Name    => Wiki.Attributes.Get_Name (Iter),
                                             Content => Wiki.Attributes.Get_Wide_Value (Iter));
         Wiki.Attributes.Next (Iter);
      end loop;
      Engine.Render (Doc, Node.Children);
      if Node.Tag_Start = Wiki.Nodes.P_TAG then
         Engine.Has_Paragraph := False;
         Engine.Need_Paragraph := True;
      end if;
      Engine.Output.End_Element (Name.all);
   end Render_Tag;

   --  ------------------------------
   --  Add a section header in the document.
   --  ------------------------------
   procedure Add_Header (Engine : in out Html_Renderer;
                         Header : in Wiki.Strings.WString;
                         Level  : in Positive) is
   begin
      Engine.Close_Paragraph;
      Engine.Add_Blockquote (0);
      case Level is
         when 1 =>
            Engine.Output.Write_Wide_Element ("h1", Header);

         when 2 =>
            Engine.Output.Write_Wide_Element ("h2", Header);

         when 3 =>
            Engine.Output.Write_Wide_Element ("h3", Header);

         when 4 =>
            Engine.Output.Write_Wide_Element ("h4", Header);

         when 5 =>
            Engine.Output.Write_Wide_Element ("h5", Header);

         when 6 =>
            Engine.Output.Write_Wide_Element ("h6", Header);

         when others =>
            Engine.Output.Write_Wide_Element ("h3", Header);
      end case;
   end Add_Header;

   --  ------------------------------
   --  Add a blockquote (<blockquote>).  The level indicates the blockquote nested level.
   --  The blockquote must be closed at the next header.
   --  ------------------------------
   procedure Add_Blockquote (Document : in out Html_Renderer;
                             Level    : in Natural) is
   begin
      if Document.Quote_Level /= Level then
         Document.Close_Paragraph;
         Document.Need_Paragraph := True;
      end if;
      while Document.Quote_Level < Level loop
         Document.Output.Start_Element ("blockquote");
         Document.Quote_Level := Document.Quote_Level + 1;
      end loop;
      while Document.Quote_Level > Level loop
         Document.Output.End_Element ("blockquote");
         Document.Quote_Level := Document.Quote_Level - 1;
      end loop;
   end Add_Blockquote;

   --  ------------------------------
   --  Add a list item (<li>).  Close the previous paragraph and list item if any.
   --  The list item will be closed at the next list item, next paragraph or next header.
   --  ------------------------------
   procedure Add_List_Item (Document : in out Html_Renderer;
                            Level    : in Positive;
                            Ordered  : in Boolean) is
   begin
      if Document.Has_Paragraph then
         Document.Output.End_Element ("p");
         Document.Has_Paragraph := False;
      end if;
      if Document.Has_Item then
         Document.Output.End_Element ("li");
         Document.Has_Item := False;
      end if;
      Document.Need_Paragraph := False;
      Document.Open_Paragraph;
      while Document.Current_Level < Level loop
         if Ordered then
            Document.Output.Start_Element ("ol");
         else
            Document.Output.Start_Element ("ul");
         end if;
         Document.Current_Level := Document.Current_Level + 1;
         Document.List_Styles (Document.Current_Level) := Ordered;
      end loop;
   end Add_List_Item;

   procedure Close_Paragraph (Document : in out Html_Renderer) is
   begin
      if Document.Html_Level > 0 then
         return;
      end if;
      if Document.Has_Paragraph then
         Document.Output.End_Element ("p");
      end if;
      if Document.Has_Item then
         Document.Output.End_Element ("li");
      end if;
      while Document.Current_Level > 0 loop
         if Document.List_Styles (Document.Current_Level) then
            Document.Output.End_Element ("ol");
         else
            Document.Output.End_Element ("ul");
         end if;
         Document.Current_Level := Document.Current_Level - 1;
      end loop;
      Document.Has_Paragraph := False;
      Document.Has_Item := False;
   end Close_Paragraph;

   procedure Open_Paragraph (Document : in out Html_Renderer) is
   begin
      if Document.Html_Level > 0 then
         return;
      end if;
      if Document.Need_Paragraph then
         Document.Output.Start_Element ("p");
         Document.Has_Paragraph  := True;
         Document.Need_Paragraph := False;
      end if;
      if Document.Current_Level > 0 and not Document.Has_Item then
         Document.Output.Start_Element ("li");
         Document.Has_Item := True;
      end if;
   end Open_Paragraph;

   --  ------------------------------
   --  Render a link.
   --  ------------------------------
   procedure Render_Link (Engine : in out Html_Renderer;
                          Doc    : in Wiki.Nodes.Document;
                          Title  : in Wiki.Strings.WString;
                          Attr   : in Wiki.Attributes.Attribute_List_Type) is
      Exists : Boolean;
      Link   : Unbounded_Wide_Wide_String := Wiki.Attributes.Get_Unbounded_Wide_Value (Attr, "href");
      URI    : Unbounded_Wide_Wide_String;
   begin
      Engine.Open_Paragraph;
      Engine.Output.Start_Element ("a");
      if Length (Title) > 0 then
         Document.Output.Write_Wide_Attribute ("title", Title);
      end if;
      if Length (Language) > 0 then
         Document.Output.Write_Wide_Attribute ("lang", Language);
      end if;
      Engine.Links.Make_Page_Link (Link, URI, Exists);
      Engine.Output.Write_Wide_Attribute ("href", URI);
      Engine.Output.Write_Wide_Text (Name);
      Engine.Output.End_Element ("a");
   end Render_Link;

   --  ------------------------------
   --  Add an image.
   --  ------------------------------
   procedure Add_Image (Document    : in out Html_Renderer;
                        Link        : in Unbounded_Wide_Wide_String;
                        Alt         : in Unbounded_Wide_Wide_String;
                        Position    : in Unbounded_Wide_Wide_String;
                        Description : in Unbounded_Wide_Wide_String) is
      pragma Unreferenced (Position);

      URI    : Unbounded_Wide_Wide_String;
      Width  : Natural;
      Height : Natural;
   begin
      Document.Open_Paragraph;
      Document.Output.Start_Element ("img");
      if Length (Alt) > 0 then
         Document.Output.Write_Wide_Attribute ("alt", Alt);
      end if;
      if Length (Description) > 0 then
         Document.Output.Write_Wide_Attribute ("longdesc", Description);
      end if;
      Document.Links.Make_Image_Link (Link, URI, Width, Height);
      Document.Output.Write_Wide_Attribute ("src", URI);
      if Width > 0 then
         Document.Output.Write_Attribute ("width", Natural'Image (Width));
      end if;
      if Height > 0 then
         Document.Output.Write_Attribute ("height", Natural'Image (Height));
      end if;
      Document.Output.End_Element ("img");
   end Add_Image;

   --  ------------------------------
   --  Add a quote.
   --  ------------------------------
   procedure Add_Quote (Document : in out Html_Renderer;
                        Quote    : in Unbounded_Wide_Wide_String;
                        Link     : in Unbounded_Wide_Wide_String;
                        Language : in Unbounded_Wide_Wide_String) is
   begin
      Document.Open_Paragraph;
      Document.Output.Start_Element ("q");
      if Length (Language) > 0 then
         Document.Output.Write_Wide_Attribute ("lang", Language);
      end if;
      if Length (Link) > 0 then
         Document.Output.Write_Wide_Attribute ("cite", Link);
      end if;
      Document.Output.Write_Wide_Text (Quote);
      Document.Output.End_Element ("q");
   end Add_Quote;

   HTML_BOLD        : aliased constant String := "b";
   HTML_ITALIC      : aliased constant String := "i";
   HTML_CODE        : aliased constant String := "tt";
   HTML_SUPERSCRIPT : aliased constant String := "sup";
   HTML_SUBSCRIPT   : aliased constant String := "sub";
   HTML_STRIKEOUT   : aliased constant String := "del";
   --  HTML_UNDERLINE   : aliased constant String := "ins";
   HTML_PREFORMAT   : aliased constant String := "pre";

   type String_Array_Access is array (Documents.Format_Type) of Util.Strings.Name_Access;

   HTML_ELEMENT     : constant String_Array_Access :=
     (Documents.BOLD        => HTML_BOLD'Access,
      Documents.ITALIC      => HTML_ITALIC'Access,
      Documents.CODE        => HTML_CODE'Access,
      Documents.SUPERSCRIPT => HTML_SUPERSCRIPT'Access,
      Documents.SUBSCRIPT   => HTML_SUBSCRIPT'Access,
      Documents.STRIKEOUT   => HTML_STRIKEOUT'Access,
      Documents.PREFORMAT   => HTML_PREFORMAT'Access);

   --  ------------------------------
   --  Add a text block with the given format.
   --  ------------------------------
   procedure Add_Text (Engine   : in out Html_Renderer;
                       Text     : in Wiki.Strings.WString;
                       Format   : in Wiki.Documents.Format_Map) is
   begin
      Engine.Open_Paragraph;
      for I in Format'Range loop
         if Format (I) then
            Engine.Output.Start_Element (HTML_ELEMENT (I).all);
         end if;
      end loop;
      Engine.Output.Write_Wide_Text (Text);
      for I in reverse Format'Range loop
         if Format (I) then
            Engine.Output.End_Element (HTML_ELEMENT (I).all);
         end if;
      end loop;
   end Add_Text;

   --  ------------------------------
   --  Add a text block that is pre-formatted.
   --  ------------------------------
   procedure Add_Preformatted (Document : in out Html_Renderer;
                               Text     : in Unbounded_Wide_Wide_String;
                               Format   : in Unbounded_Wide_Wide_String) is
   begin
      Document.Close_Paragraph;
      if Format = "html" then
         Document.Output.Write (Text);
      else
         Document.Output.Start_Element ("pre");
--         Document.Output.Write_Wide_Text (Text);
         Document.Output.End_Element ("pre");
      end if;
   end Add_Preformatted;

   --  ------------------------------
   --  Finish the document after complete wiki text has been parsed.
   --  ------------------------------
   overriding
   procedure Finish (Document : in out Html_Renderer) is
   begin
      Document.Close_Paragraph;
      Document.Add_Blockquote (0);
   end Finish;

end Wiki.Render.Html;
