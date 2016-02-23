-----------------------------------------------------------------------
--  wiki-filters-toc -- Filter for the creation of Table Of Contents
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

--  === TOC Filter ===
--  The <tt>TOC_Filter</tt> is a filter used to build the table of contents.
--  It collects the headers with the section level as they are added to the
--  wiki document.  The TOC is built in the wiki document as a separate node
--  and it can be retrieved by using the <tt>Get_TOC</tt> function.
package Wiki.Filters.TOC is

   pragma Preelaborate;

   --  ------------------------------
   --  TOC Filter
   --  ------------------------------
   type TOC_Filter is new Filter_Type with null record;

   --  Add a section header with the given level in the document.
   overriding
   procedure Add_Header (Filter    : in out TOC_Filter;
                         Document  : in out Wiki.Documents.Document;
                         Header    : in Wiki.Strings.WString;
                         Level     : in Natural);

end Wiki.Filters.TOC;
