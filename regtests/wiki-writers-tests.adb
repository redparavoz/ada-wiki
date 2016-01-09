-----------------------------------------------------------------------
--  Render Tests - Unit tests for AWA Wiki rendering
--  Copyright (C) 2013, 2016 Stephane Carrez
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

with Ada.Text_IO;
with Ada.Directories;
with Ada.Characters.Conversions;

with Util.Files;
with Util.Measures;

with Wiki.Render.Wiki;
with Wiki.Filters.Html;
with Wiki.Writers.Builders;
with Wiki.Utils;
package body Wiki.Writers.Tests is

   use Ada.Strings.Unbounded;
   use type Wiki.Parsers.Wiki_Syntax_Type;

   --  ------------------------------
   --  Test rendering a wiki text in HTML or text.
   --  ------------------------------
   procedure Test_Render (T : in out Test) is
      function To_Wide (Item : in String) return Wide_Wide_String
        renames Ada.Characters.Conversions.To_Wide_Wide_String;

      Result_File : constant String := To_String (T.Result);
      Content     : Unbounded_String;
   begin
      Util.Files.Read_File (Path     => To_String (T.File),
                            Into     => Content,
                            Max_Size => 10000);
      declare
         Time : Util.Measures.Stamp;
      begin
         if T.Source = Wiki.Parsers.SYNTAX_HTML then
            declare
               Html_Filter : aliased Wiki.Filters.Html.Html_Filter_Type;
               Writer      : aliased Wiki.Writers.Builders.Writer_Builder_Type;
               Renderer    : aliased Wiki.Render.Wiki.Wiki_Renderer;
            begin
               Renderer.Set_Writer (Writer'Unchecked_Access, T.Format);
               Html_Filter.Set_Document (Renderer'Unchecked_Access);
               Wiki.Parsers.Parse (Html_Filter'Unchecked_Access, To_Wide (To_String (Content)),
                                   Wiki.Parsers.SYNTAX_HTML);
               Content := To_Unbounded_String (Writer.To_String);
            end;
         elsif T.Is_Html then
            Content := To_Unbounded_String
              (Utils.To_Html (To_Wide (To_String (Content)), T.Format));
         else
            Content := To_Unbounded_String
              (Utils.To_Text (To_Wide (To_String (Content)), T.Format));
         end if;

         Util.Measures.Report (Time, "Render " & To_String (T.Name));
      end;

      Util.Files.Write_File (Result_File, Content);
      Util.Tests.Assert_Equal_Files (T       => T,
                                     Expect  => To_String (T.Expect),
                                     Test    => Result_File,
                                     Message => "Render");
   end Test_Render;

   --  ------------------------------
   --  Test case name
   --  ------------------------------
   overriding
   function Name (T : in Test) return Util.Tests.Message_String is
   begin
      if T.Source = Wiki.Parsers.SYNTAX_HTML then
         return Util.Tests.Format ("Test IMPORT " & To_String (T.Name));
      elsif T.Is_Html then
         return Util.Tests.Format ("Test HTML " & To_String (T.Name));
      else
         return Util.Tests.Format ("Test TEXT " & To_String (T.Name));
      end if;
   end Name;

   --  ------------------------------
   --  Perform the test.
   --  ------------------------------
   overriding
   procedure Run_Test (T : in out Test) is
   begin
      T.Test_Render;
   end Run_Test;

   procedure Add_Tests (Suite : in Util.Tests.Access_Test_Suite) is
      use Ada.Directories;
      function Create_Test (Name    : in String;
                            Path    : in String;
                            Format  : in Wiki.Parsers.Wiki_Syntax_Type;
                            Prefix  : in String;
                            Is_Html : in Boolean) return Test_Case_Access;

      Result_Dir  : constant String := "regtests/result";
      Expect_Dir  : constant String := "regtests/expect";
      Expect_Path : constant String := Util.Tests.Get_Path (Expect_Dir);
      Result_Path : constant String := Util.Tests.Get_Test_Path (Result_Dir);
      Search      : Search_Type;
      Filter      : constant Filter_Type := (others => True);
      Ent         : Directory_Entry_Type;

      function Create_Test (Name    : in String;
                            Path    : in String;
                            Format  : in Wiki.Parsers.Wiki_Syntax_Type;
                            Prefix  : in String;
                            Is_Html : in Boolean) return Test_Case_Access is
         Tst    : Test_Case_Access;
      begin
         Tst := new Test;
         Tst.Is_Html := Is_Html;
         Tst.Name    := To_Unbounded_String (Name);
         Tst.File    := To_Unbounded_String (Path);
         Tst.Expect  := To_Unbounded_String (Expect_Path & Prefix & Name);
         Tst.Result  := To_Unbounded_String (Result_Path & Prefix & Name);
         Tst.Format  := Format;
         Tst.Source  := Format;
         return Tst;
      end Create_Test;

      procedure Add_Wiki_Tests is
         Dir         : constant String := "regtests/files/wiki";
         Path        : constant String := Util.Tests.Get_Path (Dir);
      begin
         if Kind (Path) /= Directory then
            Ada.Text_IO.Put_Line ("Cannot read test directory: " & Path);
         end if;

         Start_Search (Search, Directory => Path, Pattern => "*.*", Filter => Filter);
         while More_Entries (Search) loop
            Get_Next_Entry (Search, Ent);
            declare
               Simple : constant String := Simple_Name (Ent);
               Ext    : constant String := Ada.Directories.Extension (Simple);
               Tst    : Test_Case_Access;
               Format : Wiki.Parsers.Wiki_Syntax_Type;
            begin
               if Simple /= "." and then Simple /= ".."
                 and then Simple /= ".svn" and then Simple (Simple'Last) /= '~'
               then
                  if Ext = "wiki" then
                     Format := Wiki.Parsers.SYNTAX_GOOGLE;
                  elsif Ext = "dotclear" then
                     Format := Wiki.Parsers.SYNTAX_DOTCLEAR;
                  elsif Ext = "creole" then
                     Format := Wiki.Parsers.SYNTAX_CREOLE;
                  elsif Ext = "phpbb" then
                     Format := Wiki.Parsers.SYNTAX_PHPBB;
                  elsif Ext = "mediawiki" then
                     Format := Wiki.Parsers.SYNTAX_MEDIA_WIKI;
                  else
                     Format := Wiki.Parsers.SYNTAX_MIX;
                  end if;

                  Tst := Create_Test (Simple, Path & "/" & Simple, Format, "/wiki-html/", True);
                  Suite.Add_Test (Tst.all'Access);

                  Tst := Create_Test (Simple, Path & "/" & Simple, Format, "/wiki-txt/", False);
                  Suite.Add_Test (Tst.all'Access);
               end if;
            end;
         end loop;
      end Add_Wiki_Tests;

      procedure Add_Import_Tests is
         Dir         : constant String := "regtests/files/html";
         Path        : constant String := Util.Tests.Get_Path (Dir);
      begin
         if Kind (Path) /= Directory then
            Ada.Text_IO.Put_Line ("Cannot read test directory: " & Path);
         end if;

         Start_Search (Search, Directory => Path, Pattern => "*.*", Filter => Filter);
         while More_Entries (Search) loop
            Get_Next_Entry (Search, Ent);
            declare
               Simple : constant String := Simple_Name (Ent);
               Name   : constant String := Base_Name (Simple);
               Tst    : Test_Case_Access;
            begin
               if Simple /= "." and then Simple /= ".."
                 and then Simple /= ".svn" and then Simple (Simple'Last) /= '~'
               then
                  for Syntax in Wiki.Parsers.Wiki_Syntax_Type'Range loop
                     case Syntax is
                        when Wiki.Parsers.SYNTAX_CREOLE =>
                           Tst := Create_Test (Name & ".creole", Path & "/" & Simple,
                                               Syntax, "/wiki-import/", True);

                        when Wiki.Parsers.SYNTAX_DOTCLEAR =>
                           Tst := Create_Test (Name & ".dotclear", Path & "/" & Simple,
                                               Syntax, "/wiki-import/", True);

                        when Wiki.Parsers.SYNTAX_MEDIA_WIKI =>
                           Tst := Create_Test (Name & ".mediawiki", Path & "/" & Simple,
                                               Syntax, "/wiki-import/", True);

                        when others =>
                           Tst := null;

                     end case;
                     if Tst /= null then
                        Tst.Source := Wiki.Parsers.SYNTAX_HTML;
                        Suite.Add_Test (Tst.all'Access);
                     end if;
                  end loop;
               end if;
            end;
         end loop;
      end Add_Import_Tests;

   begin
      Add_Wiki_Tests;
      Add_Import_Tests;
   end Add_Tests;

end Wiki.Writers.Tests;
