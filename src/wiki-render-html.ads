-----------------------------------------------------------------------
--  wiki-render-html -- Wiki HTML renderer
--  Copyright (C) 2011, 2012, 2013, 2015, 2016 Stephane Carrez
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
with Wiki.Attributes;
with Wiki.Streams.Html;
with Wiki.Strings;
with Wiki.Render.Links;

--  == HTML Renderer ==
--  The <tt>Html_Renderer</tt> allows to render a wiki document into an HTML content.
--
package Wiki.Render.Html is

   --  ------------------------------
   --  Wiki to HTML renderer
   --  ------------------------------
   type Html_Renderer is new Renderer with private;

   --  Set the output stream.
   procedure Set_Output_Stream (Engine : in out Html_Renderer;
                                Stream : in Wiki.Streams.Html.Html_Output_Stream_Access);

   --  Set the link renderer.
   procedure Set_Link_Renderer (Engine : in out Html_Renderer;
                                Links  : in Wiki.Render.Links.Link_Renderer_Access);

   --  Set the render TOC flag that controls the TOC rendering.
   procedure Set_Render_TOC (Engine : in out Html_Renderer;
                             State  : in Boolean);

   --  Render the node instance from the document.
   overriding
   procedure Render (Engine : in out Html_Renderer;
                     Doc    : in Wiki.Documents.Document;
                     Node   : in Wiki.Nodes.Node_Type);

   --  Get the current section number.
   function Get_Section_Number (Engine    : in Html_Renderer;
                                Prefix    : in Wiki.Strings.WString;
                                Separator : in Wiki.Strings.WChar) return Wiki.Strings.WString;

   --  Add a blockquote (<blockquote>).  The level indicates the blockquote nested level.
   --  The blockquote must be closed at the next header.
   procedure Add_Blockquote (Engine : in out Html_Renderer;
                             Level    : in Natural);

   --  Render a list item (<li>).  Close the previous paragraph and list item if any.
   --  The list item will be closed at the next list item, next paragraph or next header.
   procedure Render_List_Item (Engine   : in out Html_Renderer;
                               Level    : in Positive;
                               Ordered  : in Boolean);

   --  Add a text block with the given format.
   procedure Add_Text (Engine   : in out Html_Renderer;
                       Text     : in Wiki.Strings.WString;
                       Format   : in Wiki.Format_Map);

   --  Render a text block that is pre-formatted.
   procedure Render_Preformatted (Engine : in out Html_Renderer;
                                  Text   : in Wiki.Strings.WString;
                                  Format : in Wiki.Strings.WString);

   --  Finish the document after complete wiki text has been parsed.
   overriding
   procedure Finish (Engine : in out Html_Renderer;
                     Doc    : in Wiki.Documents.Document);

private

   procedure Close_Paragraph (Engine : in out Html_Renderer);
   procedure Open_Paragraph (Engine : in out Html_Renderer);

   type Toc_Number_Array is array (1 .. 6) of Natural;

   type List_Style_Array is array (1 .. 32) of Boolean;

   Default_Links : aliased Wiki.Render.Links.Default_Link_Renderer;

   type Html_Renderer is new Renderer with record
      Output            : Wiki.Streams.Html.Html_Output_Stream_Access := null;
      Format            : Wiki.Format_Map := (others => False);
      Links             : Wiki.Render.Links.Link_Renderer_Access := Default_Links'Access;
      Has_Paragraph     : Boolean := False;
      Need_Paragraph    : Boolean := False;
      Has_Item          : Boolean := False;
      Enable_Render_TOC : Boolean := False;
      TOC_Rendered      : Boolean := False;
      Current_Level     : Natural := 0;
      Html_Tag          : Wiki.Html_Tag := BODY_TAG;
      List_Styles       : List_Style_Array := (others => False);
      Quote_Level       : Natural := 0;
      Html_Level        : Natural := 0;
      Current_Section   : Toc_Number_Array := (others => 0);
      Section_Level     : Natural := 0;
   end record;

   procedure Render_Tag (Engine : in out Html_Renderer;
                         Doc    : in Wiki.Documents.Document;
                         Node   : in Wiki.Nodes.Node_Type);

   --  Render a section header in the document.
   procedure Render_Header (Engine : in out Html_Renderer;
                            Doc    : in Wiki.Documents.Document;
                            Header : in Wiki.Strings.WString;
                            Level  : in Positive);

   --  Render the table of content.
   procedure Render_TOC (Engine : in out Html_Renderer;
                         Doc    : in Wiki.Documents.Document;
                         Level  : in Natural);

   --  Render a link.
   procedure Render_Link (Engine : in out Html_Renderer;
                          Doc    : in Wiki.Documents.Document;
                          Title  : in Wiki.Strings.WString;
                          Attr   : in Wiki.Attributes.Attribute_List);

   --  Render an image.
   procedure Render_Image (Engine : in out Html_Renderer;
                           Doc    : in Wiki.Documents.Document;
                           Title  : in Wiki.Strings.WString;
                           Attr   : in Wiki.Attributes.Attribute_List);

   --  Render a quote.
   procedure Render_Quote (Engine : in out Html_Renderer;
                           Doc    : in Wiki.Documents.Document;
                           Title  : in Wiki.Strings.WString;
                           Attr   : in Wiki.Attributes.Attribute_List);

   --  Returns true if the HTML element being included is already contained in a paragraph.
   --  This include: a, em, strong, small, b, i, u, s, span, ins, del, sub, sup.
   function Has_Html_Paragraph (Engine : in Html_Renderer) return Boolean;

end Wiki.Render.Html;
