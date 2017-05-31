/*-----------------------------------------------------------------------------\

	KOTORmax
	by bead-v
	
	Derived from:
    NWmax
    by Joco (jameswalker@clear.net.nz)

    Credits:
    Wayland Reid :-
        Extends Wayland's (wreid@spectrumanalytic.com) Import/Export script
    Zaddix :-
        Based on code from Zaddix's original WOK file importer
    BioWare :-
        This code is based on the information gleaned from BioWares
        3DS Max scripts. In many cases the Bioware code is used instead of
        "re-inventing the wheel". I have attempted to note all those places
        where I have used the Bioware code.


    Legal Stuff
    1. This is free software and is provided with no explicit or implied
       warranty. If you use this software then you do so at your own risk.
    2. If there is any law in your country that requires the author to provide
       any form of support or indemnity on the use of the this software you are
       not therefore authorised to use said software as no such indemnity or
       support will be provided (per 1) other than at the authors discretion.
    3. Credit has been given where code or methods have been integrated from
       other sources.
    4. In the case of code used from the Bioware scripts their intellectual
       property rights still hold.
    5. No code has been knowingly included from other sources where that code
       is sold for commercial purposes.




   Updates:
   .8b61    Fix for global sanity check issues.
            Enhanced wok checker tool

   .8b22    Fix for fadinglight token not being parsed
            Fix for wok test not out putting to sanity check file
            Support for wok material file being fully driven from .ini file
            A number of misc bug fixes that I have lost track of.
\-----------------------------------------------------------------------------*/

-- Ensure stack and heap size is large enough
--if ( heapSize < 7500000 ) then heapSize = 7500000
--if ( stackLimit < 4000000 ) then stackLimit = 4000000
---- following NWmax 0.8c, stack and heap size should be higher
if ( heapSize < 80000000 ) then heapSize = 80000000
if ( stackLimit < 80000000 ) then stackLimit = 80000000

global gNX_maxver = (maxversion())[1]
global gblVersion = "0.1"
global g_kotormaxPath = scriptsPath + "KOTORmax\\"
global kotormax_handle -- handle to the master floater window
if autostart == undefined then autostart = false

ClearListener()
format "--------------------------------------------------------------\r\n"
format "\r\n"
format "                        KOTORmax v%\r\n" gblVersion
format "\r\n"
format "--------------------------------------------------------------\r\n"

--------------------------------------------------------------------------------
---
--- Global Variables and init setups
---
--------------------------------------------------------------------------------
global DEBUG = false	-- debug flag
global SPEEDT = false	-- speed timer flag
global strIndent1 = "  "
global strIndent2 = "    "
global strIndent3 = "      "
global strIndent4 = "        "
global strIndent5 = "          "
--
-- Load kotormax ini global vars
format "KOTORmax ini load\r\n"
global g_3dsmax = getINISetting (g_kotormaxPath + "kotormax.ini") "init" "usemax"
global g_verbose = getINISetting (g_kotormaxPath + "kotormax.ini") "init" "verbose"
global gNX_dock = getINISetting (g_kotormaxPath + "kotormax.ini") "init" "dock"
global gNX_visible = getINISetting (g_kotormaxPath + "kotormax.ini") "init" "visible"
global gnx_sanity = getINISetting (g_kotormaxPath + "kotormax.ini") "init" "sanity"
global g_basepointer = getINISetting (g_kotormaxPath + "kotormax.ini") "init" "basepointer"
global g_exportwok = getINISetting (g_kotormaxPath + "kotormax.ini") "init" "exportwok"
global gnx_pos_kotormax = getINISetting (g_kotormaxPath + "kotormax.ini") "init" "position"

/*
-- check to see if over-ride in nxlocalprefs
if (getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "verbose") != undefined and \
   (getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "verbose") != ""
then g_verbose = getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "verbose"

if (getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "dock") != undefined and \
   (getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "dock") != ""
then gNX_dock = getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "dock"

if (getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "visible") != undefined and \
   (getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "visible") != ""
then gNX_visible = getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "visible"

if (getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "sanity") != undefined and \
   (getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "sanity") != ""
then gnx_sanity = getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "sanity"

if (getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "basepointer") != undefined and \
   (getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "basepointer") != ""
then g_basepointer = getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "basepointer"

if (getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "exportwok") != undefined and \
   (getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "exportwok") != ""
then g_basepointer = getINISetting (scriptsPath+"nxlocalprefs.ini") "init" "exportwok"

-- get nxlocalprefs specific data and convert types
gnx_pos_kotormax = getINISetting (scriptsPath+"nxlocalprefs.ini") "position" "kotormax"
*/

-- Correct ini vars for undefined and set required defaults and type conversion
format "Correct ini vars\r\n"
if g_verbose == undefined then g_verbose = 0
else g_verbose = (g_verbose as integer)
   
if gNX_dock == undefined then gNX_dock = 0
else gNX_dock = (gNX_dock as integer)
	
if gNX_visible == undefined then gNX_visible = 0
else gNX_visible = (gNX_visible as integer)
	
if gnx_sanity == undefined or gnx_sanity == "" then gnx_sanity = "111110111111111"
	
if g_basepointer == undefined then g_basepointer = 1
else g_basepointer = (g_basepointer as integer)

if g_exportwok == undefined then g_exportwok = 1
else g_exportwok = (g_exportwok as integer)

if gnx_pos_kotormax == undefined or (gnx_pos_kotormax == "") then gnx_pos_kotormax = [0,100]
else gnx_pos_kotormax = execute(gnx_pos_kotormax)

-- set globals for 3dsmax vs gmax
format "Set globals for 3dsmax vs gmax\r\n"
global g_fextn = ""
global g_gmaxini = ""
global g_ismax = false
if g_3dsmax == "1" then (
   g_fextn = ".max"
   g_gmaxini = "3dsmax.ini"
   g_ismax = true
) else (
   g_fextn = ".gmax"
   g_gmaxini = "gmax.ini"
   g_ismax = false
)

-- load in all paths from gmax.ini or max file
format "Load in all paths from gmax.ini or max file\r\n"
global g_maps_path = #()
for i = 1 to 100 do
(
	if (getINISetting (scriptsPath+"..\\"+g_gmaxini) "BitmapDirs" ("Dir"+(i as string))) == "" then exit
	append g_maps_path (getINISetting (scriptsPath+"..\\"+g_gmaxini) "BitmapDirs" ("Dir"+(i as string)))
)
format "Maps search dirs:\r\n"
print g_maps_path

-- Export path
global g_exportPath = ""

-- Global stack to be used for files and generic stack routines
global g_FileHandles = #()

-- Exporting stream buffer
format "Setup exporting stream\r\n"
if g_ismax then
(
   global g_strBuffer = undefined	-- file stream buffer for exporting
   global g_delim = "\n"	-- Buffered export system delimter
) 
else
(
	global g_strBuffer = stringStream ""	-- StringStream buffer for compressed export system
	if g_verbose == 1 then
		g_delim = "~\n"
	else
		g_delim = "~"
)

-- Compiler
--global g_compiler = g_kotormaxPath + "mdlcomp\\nwnmdlcomp.exe"

-- Plug-Ins
global g_plugins = #()  -- list of plugins

-- Specific import globals
global lastDanglyName = undefined
global AnimRootNodeName = undefined
global LastAnimNumber = undefined
global LastAnimEventNumber = undefined

-- UI flags for active dialogs
global nx_animkeymaster_flag = false
global nx_skindumper_flag = false

-- global execute str - execution requires global scope, so this has to be preserved
global nx_exec_str

-- These are for the Sanity Check Preferences
-- Originally per Bioware's export scripts code. Legacy system.
format "Set Sanity check default settings\r\n"
global runRotationCheck = (gnx_sanity[1] as integer != 0)
global runAnimCheck = (gnx_sanity[2] as integer != 0)
global runNameCheck = (gnx_sanity[3] as integer != 0)
global runScaleCheck = (gnx_sanity[4] as integer != 0)
global runPartTextureCheck = (gnx_sanity[5] as integer != 0)
global runWeldCheck = (gnx_sanity[6] as integer != 0)
global runClassCheck = (gnx_sanity[7] as integer != 0)
global runControllerCheck = (gnx_sanity[8] as integer != 0)
global runDoganCheck = (gnx_sanity[9] as integer != 0)
global runBitmapNameCheck = (gnx_sanity[10] as integer != 0)
global runFaceCheck = (gnx_sanity[11] as integer != 0)
global runAnimrootCheck = (gnx_sanity[12] as integer != 0)
global runBoneCountCheck = (gnx_sanity[13] as integer != 0)
global runDuplicateNamesCheck = (gnx_sanity[14] as integer != 0)
global runAabbCheck = (gnx_sanity[15] as integer != 0)

-- this function might work well for testing
fn nx_coderefresh =
(
	filein (g_kotormaxPath+"kotormax_scripts/odyssey_fn_general.ms")
	filein (g_kotormaxPath+"kotormax_scripts/odyssey_fn_sanity.ms")
	filein (g_kotormaxPath+"kotormax_scripts/odyssey_fn_export.ms")
	filein (g_kotormaxPath+"kotormax_scripts/odyssey_fn_import.ms")
	filein (g_kotormaxPath+"kotormax_scripts/nx_gui_create.ms")
	filein (g_kotormaxPath+"kotormax_scripts/nx_gui_speedbtns.ms")
	filein (g_kotormaxPath+"kotormax_scripts/nx_gui_import.ms")
	filein (g_kotormaxPath+"kotormax_scripts/nx_gui_about.ms")
	max views redraw
)

--
-- Start progress for loading
--
progressStart "PlugIns Loading ..."
global com_load_total = 8 -- setting progress 
global com_load = 0 -- tracking progress

--------------------------------------------------------------------------------
--
-- General functions
--
--------------------------------------------------------------------------------
filein (g_kotormaxPath+"kotormax_scripts/odyssey_fn_proto.ms")
filein (g_kotormaxPath+"kotormax_scripts/odyssey_fn_general.ms")

--------------------------------------------------------------------------------
---
--- Scripted Plug-Ins
---
--------------------------------------------------------------------------------
filein (g_kotormaxPath+"kotormax_scripts/odyssey_helper_dummy.ms")    -- 1
filein (g_kotormaxPath+"kotormax_scripts/odyssey_helper_base.ms")     -- 2
filein (g_kotormaxPath+"kotormax_scripts/odyssey_helper_light.ms")    -- 3
filein (g_kotormaxPath+"kotormax_scripts/odyssey_helper_emitter.ms")  -- 4
filein (g_kotormaxPath+"kotormax_scripts/odyssey_mod_trimesh.ms")     -- 5
filein (g_kotormaxPath+"kotormax_scripts/odyssey_mod_flex.ms")        -- 6
filein (g_kotormaxPath+"kotormax_scripts/odyssey_mod_walkmesh.ms")    -- 7
filein (g_kotormaxPath+"kotormax_scripts/odyssey_geom_lightsaber.ms") -- 8

--------------------------------------------------------------------------------
--
-- Import/Export functions
--
--------------------------------------------------------------------------------
filein (g_kotormaxPath+"kotormax_scripts/odyssey_fn_sanity.ms")
filein (g_kotormaxPath+"kotormax_scripts/odyssey_fn_export.ms")
filein (g_kotormaxPath+"kotormax_scripts/odyssey_fn_import.ms")

--------------------------------------------------------------------------------
---
---   Rollout definitions
---
--------------------------------------------------------------------------------
filein (g_kotormaxPath+"kotormax_scripts/nx_gui_create.ms")
filein (g_kotormaxPath+"kotormax_scripts/nx_gui_speedbtns.ms")
filein (g_kotormaxPath+"kotormax_scripts/nx_gui_import.ms")
filein (g_kotormaxPath+"kotormax_scripts/nx_gui_about.ms")


--------------------------------------------------------------------------------
---
---   Rollout Window creation
---
--------------------------------------------------------------------------------

fn nx_make_floater =
(
	kotormax_handle = newRolloutFloater "KOTORmax" 200 600 0 100 -- 192 600 0 100
	addRollout nx_util0			kotormax_handle rolledUp:true
	addRollout nx_util1			kotormax_handle rolledUp:true
	--addRollout nx_util2			kotormax_handle rolledUp:true
	addRollout nx_util3			kotormax_handle rolledUp:true
	addRollout nx_util4			kotormax_handle rolledUp:true
	--addRollout nx_util5			kotormax_handle rolledUp:true
	addRollout nx_util6			kotormax_handle rolledUp:true
	addRollout ImportRollout    kotormax_handle rolledUp:true
	addRollout nx_prefs			kotormax_handle rolledUp:true
	addRollout AboutRollout     kotormax_handle rolledUp:false

	-- load in old position from local ini file
	kotormax_handle.pos = gnx_pos_kotormax
)

fn nx_destroy_floater =
(
	if kotormax_handle != undefined do
	(
	    -- make sure floater is not docked and unregister it
	    try (
	        cui.FloatDialogBar kotormax_handle
	        cui.UnRegisterDialogBar kotormax_handle
	    ) catch ()
	    -- close it.
	    closerolloutfloater kotormax_handle
	)
)

-- try to close out a floater if it already exists
nx_destroy_floater()

-- CREATE KOTORMAX WINDOW
if gNX_visible == 1 then
(
	nx_make_floater()
	if gNX_dock == 1 then
	(
		-- Register floater as a dockable bar
		cui.RegisterDialogBar kotormax_handle \
		    maxSize:[-1,-1] \
		    style:#(#cui_dock_vert, #cui_floatable, #cui_handles)
		-- By default dock the bar
		cui.DockDialogBar kotormax_handle #cui_dock_left
	)
)

-- Set app title
--cui.setAppTitle ("KOTORmax v" + gblVersion)

if IsSceneRedrawDisabled()==true do enablesceneredraw()

format "------------------------------Done----------------------------\r\n\r\n"
progressEnd()
max views redraw
