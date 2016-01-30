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

package body Wiki.Nodes is

   --  ------------------------------
   --  Create a text node.
   --  ------------------------------
   function Create_Text (Text : in WString) return Node_Type_Access is
   begin
      return new Node_Type '(Kind => N_TEXT,
                             Len  => Text'Length,
                             Text => Text,
                             others => <>);
   end Create_Text;

end Wiki.Nodes;
