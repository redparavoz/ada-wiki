-----------------------------------------------------------------------
--  wiki-writers -- Wiki writers
--  Copyright (C) 2011, 2012, 2013, 2016 Stephane Carrez
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
package body Wiki.Writers is

   --  ------------------------------
   --  Write an XML attribute within an XML element.
   --  The attribute value is escaped according to the XML escape rules.
   --  ------------------------------
   procedure Write_Attribute (Writer  : in out Html_Writer_Type'Class;
                              Name    : in String;
                              Content : in String) is
      S : constant Wide_Wide_String := Ada.Characters.Conversions.To_Wide_Wide_String (Content);
   begin
      Writer.Write_Wide_Attribute (Name, To_Unbounded_Wide_Wide_String (S));
   end Write_Attribute;

end Wiki.Writers;
