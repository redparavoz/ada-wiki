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
with Ada.Wide_Wide_Characters.Handling;
with Ada.Unchecked_Deallocation;
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
   begin
      if From.Current /= null then
         From.Current := From.Current.Parent;
      end if;
   end Pop_Node;

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
         if Into.Current.Children = null then
            Into.Current.Children := new Node_List;
            --  Into.Current.Children.Current := Into.Current.Children.First'Access;
            --  Into.Current.Children.Parent := Into.Current;
         end if;
         Append (Into.Current.Children.all, Node);
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
   begin
      Append (Into, new Node_Type '(Kind => N_PREFORMAT, Len => Text'Length,
                                    Preformatted => Text, others => <>));
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

   overriding
   procedure Initialize (Doc : in out Document) is
   begin
--      Doc.Nodes := Node_List_Refs.Create;
  --    Doc.Nodes.Value.Current := Doc.Nodes.Value.First'Access;
     null;
   end Initialize;

end Wiki.Documents;