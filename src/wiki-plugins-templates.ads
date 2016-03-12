-----------------------------------------------------------------------
--  wiki-plugins-template -- Template Plugin
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
with Wiki.Strings;

--  === Template Plugins ===
--  The <b>Wiki.Plugins.Templates</b> package defines an abstract template plugin.
--  To use the template plugin, the <tt>Get_Template</tt> procedure must be implemented.
--  It is responsible for getting the template content according to the plugin parameters.
--
package Wiki.Plugins.Templates is

   pragma Preelaborate;

   type Template_Plugin is abstract new Wiki_Plugin with null record;

   --  Get the template content for the plugin evaluation.
   procedure Get_Template (Plugin   : in out Template_Plugin;
                           Params   : in out Wiki.Attributes.Attribute_List;
                           Template : out Wiki.Strings.UString) is abstract;

   --  Expand the template configured with the parameters for the document.
   --  The <tt>Get_Template</tt> operation is called and the template content returned
   --  by that operation is parsed in the current document.  Template parameters are passed
   --  in the <tt>Context</tt> instance and they can be evaluated within the template
   --  while parsing the template content.
   overriding
   procedure Expand (Plugin   : in out Template_Plugin;
                     Document : in out Wiki.Documents.Document;
                     Params   : in out Wiki.Attributes.Attribute_List;
                     Context  : in Plugin_Context);

end Wiki.Plugins.Templates;
