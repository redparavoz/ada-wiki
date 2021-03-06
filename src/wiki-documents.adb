-----------------------------------------------------------------------
--  wiki-nodes -- Wiki Document Internal representation
--  Copyright (C) 2016 Stephane Carrez
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

package body Wiki.Documents is

   use Wiki.Nodes;

   --  ------------------------------
   --  Append a HTML tag start node to the document.
   --  ------------------------------
   procedure Push_Node (Into       : in out Document;
                        Tag        : in Html_Tag;
                        Attributes : in Wiki.Attributes.Attribute_List) is

      Node : constant Node_Type_Access := new Node_Type '(Kind       => N_TAG_START,
                                                          Len        => 0,
                                                          Tag_Start  => Tag,
                                                          Attributes => Attributes,
                                                          Children   => null,
                                                          Parent     => Into.Current);
   begin
      Append (Into, Node);
      Into.Current := Node;
   end Push_Node;

   --  ------------------------------
   --  Pop the HTML tag.
   --  ------------------------------
   procedure Pop_Node (From : in out Document;
                       Tag  : in Html_Tag) is
      pragma Unreferenced (Tag);
   begin
      if From.Current /= null then
         From.Current := From.Current.Parent;
      end if;
   end Pop_Node;

   --  ------------------------------
   --  Returns True if the current node is the root document node.
   --  ------------------------------
   function Is_Root_Node (Doc : in Document) return Boolean is
   begin
      return Doc.Current = null;
   end Is_Root_Node;

   --  ------------------------------
   --  Append a section header at end of the document.
   --  ------------------------------
   procedure Append (Into   : in out Document;
                     Header : in Wiki.Strings.WString;
                     Level  : in Positive) is
   begin
      Append (Into, new Node_Type '(Kind   => N_HEADER,
                                    Len    => Header'Length,
                                    Header => Header,
                                    Level  => Level));
   end Append;

   --  ------------------------------
   --  Append a node to the document.
   --  ------------------------------
   procedure Append (Into : in out Document;
                     Node : in Wiki.Nodes.Node_Type_Access) is
   begin
      if Into.Current = null then
         Append (Into.Nodes, Node);
      else
         Append (Into.Current, Node);
      end if;
   end Append;

   --  ------------------------------
   --  Append a simple node such as N_LINE_BREAK, N_HORIZONTAL_RULE or N_PARAGRAPH.
   --  ------------------------------
   procedure Append (Into : in out Document;
                     Kind : in Simple_Node_Kind) is
   begin
      case Kind is
         when N_LINE_BREAK =>
            Append (Into, new Node_Type '(Kind => N_LINE_BREAK, Len => 0));

         when N_HORIZONTAL_RULE =>
            Append (Into, new Node_Type '(Kind => N_HORIZONTAL_RULE, Len => 0));

         when N_PARAGRAPH =>
            Append (Into, new Node_Type '(Kind => N_PARAGRAPH, Len => 0));

         when N_TOC_DISPLAY =>
            Append (Into, new Node_Type '(Kind => N_TOC_DISPLAY, Len => 0));
            Into.Using_TOC := True;

      end  case;
   end Append;

   --  ------------------------------
   --  Append the text with the given format at end of the document.
   --  ------------------------------
   procedure Append (Into   : in out Document;
                     Text   : in Wiki.Strings.WString;
                     Format : in Format_Map) is
   begin
      Append (Into, new Node_Type '(Kind => N_TEXT, Len => Text'Length,
                                    Text => Text, Format => Format));
   end Append;

   --  ------------------------------
   --  Add a link.
   --  ------------------------------
   procedure Add_Link (Into       : in out Document;
                       Name       : in Wiki.Strings.WString;
                       Attributes : in out Wiki.Attributes.Attribute_List) is
   begin
      Append (Into, new Node_Type '(Kind => N_LINK, Len => Name'Length,
                                    Title => Name, Link_Attr => Attributes));
   end Add_Link;

   --  ------------------------------
   --  Add an image.
   --  ------------------------------
   procedure Add_Image (Into       : in out Document;
                        Name       : in Wiki.Strings.WString;
                        Attributes : in out Wiki.Attributes.Attribute_List) is
   begin
      Append (Into, new Node_Type '(Kind => N_IMAGE, Len => Name'Length,
                                    Title => Name, Link_Attr => Attributes));
   end Add_Image;

   --  ------------------------------
   --  Add a quote.
   --  ------------------------------
   procedure Add_Quote (Into       : in out Document;
                        Name       : in Wiki.Strings.WString;
                        Attributes : in out Wiki.Attributes.Attribute_List) is
   begin
      Append (Into, new Node_Type '(Kind => N_QUOTE, Len => Name'Length,
                                    Title => Name, Link_Attr => Attributes));
   end Add_Quote;

   --  ------------------------------
   --  Add a list item (<li>).  Close the previous paragraph and list item if any.
   --  The list item will be closed at the next list item, next paragraph or next header.
   --  ------------------------------
   procedure Add_List_Item (Into     : in out Document;
                            Level    : in Positive;
                            Ordered  : in Boolean) is
   begin
      if Ordered then
         Append (Into, new Node_Type '(Kind => N_NUM_LIST, Len => 0,
                                       Level => Level, others => <>));
      else
         Append (Into, new Node_Type '(Kind => N_LIST, Len => 0,
                                       Level => Level, others => <>));
      end if;
   end Add_List_Item;

   --  ------------------------------
   --  Add a blockquote (<blockquote>).  The level indicates the blockquote nested level.
   --  The blockquote must be closed at the next header.
   --  ------------------------------
   procedure Add_Blockquote (Into     : in out Document;
                             Level    : in Natural) is
   begin
      Append (Into, new Node_Type '(Kind => N_BLOCKQUOTE, Len => 0,
                                    Level => Level, others => <>));
   end Add_Blockquote;

   --  Add a text block that is pre-formatted.
   procedure Add_Preformatted (Into     : in out Document;
                               Text     : in Wiki.Strings.WString;
                               Format   : in Wiki.Strings.WString) is
      pragma Unreferenced (Format);
   begin
      Append (Into, new Node_Type '(Kind => N_PREFORMAT, Len => Text'Length,
                                    Preformatted => Text));
   end Add_Preformatted;

   --  ------------------------------
   --  Iterate over the nodes of the list and call the <tt>Process</tt> procedure with
   --  each node instance.
   --  ------------------------------
   procedure Iterate (Doc     : in Document;
                      Process : not null access procedure (Node : in Node_Type)) is
   begin
      Iterate (Doc.Nodes, Process);
   end Iterate;

   --  ------------------------------
   --  Returns True if the document is empty.
   --  ------------------------------
   function Is_Empty (Doc : in Document) return Boolean is
   begin
      return Wiki.Nodes.Is_Empty (Doc.Nodes);
   end Is_Empty;

   --  ------------------------------
   --  Returns True if the document displays the table of contents by itself.
   --  ------------------------------
   function Is_Using_TOC (Doc : in Document) return Boolean is
   begin
      return Doc.Using_TOC;
   end Is_Using_TOC;

   --  ------------------------------
   --  Returns True if the table of contents is visible and must be rendered.
   --  ------------------------------
   function Is_Visible_TOC (Doc : in Document) return Boolean is
   begin
      return Doc.Visible_TOC;
   end Is_Visible_TOC;

   --  ------------------------------
   --  Hide the table of contents.
   --  ------------------------------
   procedure Hide_TOC (Doc : in out Document) is
   begin
      Doc.Visible_TOC := False;
   end Hide_TOC;

   --  ------------------------------
   --  Get the table of content node associated with the document.
   --  ------------------------------
   procedure Get_TOC (Doc : in out Document;
                      TOC : out Wiki.Nodes.Node_List_Ref) is
   begin
      if Wiki.Nodes.Is_Empty (Doc.TOC) then
         Append (Doc.TOC, new Node_Type '(Kind => N_TOC, Len => 0, others => <>));
      end if;
      TOC := Doc.TOC;
   end Get_TOC;

   --  ------------------------------
   --  Get the table of content node associated with the document.
   --  ------------------------------
   function Get_TOC (Doc : in Document) return Wiki.Nodes.Node_List_Ref is
   begin
      return Doc.TOC;
   end Get_TOC;

end Wiki.Documents;
