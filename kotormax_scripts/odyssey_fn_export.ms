/*-----------------------------------------------------------------------------\

    Odyssey Export Functions

    The exporting of data from the model is based on traversing a tree.
    The model is represented by tree nodes all linked directly or indirectly
    off the model base node. Often referred to as the root.

	KOTORmax
	by bead-v
	
	Derived from:
    NWmax
    by Joco (jameswalker@clear.net.nz)

    Credits:
    Wayland Reid :-
        Extends Wayland's Import/Export script with rewrites as needed
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
    4. No code has been knowingly included from other sources where that code
       is sold for commercial purposes.

\-----------------------------------------------------------------------------*/

--------------------------------------------------------------------------------
-- Global working vars for exporting
--------------------------------------------------------------------------------
global g_curnode
global g_detonateKeys
global g_RoundOffVertices
global g_ModelName

global g_nodeprog	-- holds export progress by node -- bead-v: reusing this, exactly what I need
global g_animprog	-- holds export progress by anim -- bead-v: reusing this, exactly what I need
global g_exptotal   -- bead-v: holds the total number of node*animations
global g_nodestotal -- bead-v: total number of nodes under odysseybase
global g_showprogres -- bead-v: whether to show progress when exporting mdl

fn getNumDescendants node =
(
    local nDescendants = 0
    for child in node.children do
    (
        -- if the child is an odysseybase, then don't count its children
        if not iskindof child odysseybase then
			nDescendants += getNumDescendants child
    )
    nDescendants += node.children.count
    return nDescendants
)

fn nx_progressUpdate =
(
    if(g_showprogres!= undefined and g_showprogres and g_nodestotal != undefined and g_animprog != undefined and g_nodeprog != undefined and g_exptotal != undefined) then
        progressUpdate (((g_nodestotal * g_animprog + g_nodeprog) * 100 ) / g_exptotal)
)

--------------------------------------------------------------------------------
-- Utility functions
--------------------------------------------------------------------------------
fn nx_fprints data =
(
    -- From BioWare
    -- Formated print string in the same vein as C's formated printing
    case of
    (
    	((classof data) == color):
    	(
    		return ( ((data.r/255.0)as string) + " " + \
    		         ((data.g/255.0)as string) + " " + \
    		         ((data.b/255.0)as string) + " " )
        )

    	((classof data) == point3):
    	(
    		return ( (data.x as string) + " " + \
    		         (data.y as string) + " " + \
    		         (data.z as string) + " " )
        )

    	((classof data) == quat):
    		data = data as angleaxis

    	((classof data) == angleaxis):
    	(
    		local a = data.axis
    		return (nx_fprints a + " " + ((degtorad(data.angle)) as string) + " ")
    	)
    )

	return (data as string)
)

/*
    Gets node type (for our purposes). Possible values:
    GEOM:
     - trimesh
     - skin
     - danglymesh
     - aabb
     - lightsaber
    NO GEOM:
     - dummy
	 - base
     - light
     - emitter
*/
fn nx_getnodetype node =
(
    local node_type = ""
    local node_class = (nx_strclassof node)
    local node_superclass = ((superclassof node) as string)

    if DEBUG then format "  #DEBUG: node: %  type: %  superclass: % %" node.name node_class node_superclass g_delim to:g_strBuffer

    case of
    (
    	(node_class == "odysseybase"): node_type = "base"
    	(node_class == "odysseylight"): node_type = "light"
    	(node_class == "odysseyemitter"): node_type = "emitter"
    	(node_class == "odysseylightsaber"): node_type = "lightsaber"
    	(node_superclass == "GeometryClass"):
    	(
        	case of
        	(
            	(node.modifiers["OdysseyWalkmesh"] != undefined):
            	(
                	if node.modifiers["OdysseyWalkmesh"].meshtype == 1 then
                        node_type = "aabb"
                	else if node.modifiers["OdysseyWalkmesh"].meshtype == 0 then
                        node_type = "dummy" -- if the user left it unselected, then just dumb it down to a dummy
                	else
                        node_type = "trimesh" -- pwk/dwk walkmeshes are just trimeshes in the ascii.
        	    )
            	(node.modifiers["skin"] != undefined): node_type = "skin"
            	(node.modifiers["OdysseyFlex"] != undefined): node_type = "danglymesh"
            	default: node_type = "trimesh"  -- any other geometry should be fine exported as a trimesh
        	)
    	)
    	default: node_type = "dummy"
    )

    return node_type
)

fn nx_getcontrollerhaskeys ctrl firstframe lastframe =
(
    if ctrl == undefined then return false
    else
    (
        for t = firstframe to lastframe do
        (
            if (getKeyIndex ctrl t) > 0 then return true
        )
    )
    return false
)

fn nx_isnodetreeanimated node firstframe lastframe =
(
    local node_type = nx_getnodetype node

    if nx_getcontrollerhaskeys node.position.controller firstframe lastframe then return true
    if nx_getcontrollerhaskeys node.rotation.controller firstframe lastframe then return true

    if node.modifiers["OdysseyTrimesh"] != undefined then
    (
        if nx_getcontrollerhaskeys node.modifiers["OdysseyTrimesh"].scale.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.modifiers["OdysseyTrimesh"].alpha.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.modifiers["OdysseyTrimesh"].selfillumcolor.controller firstframe lastframe then return true
    )
    if node_type == "lightsaber" then
    (
        if nx_getcontrollerhaskeys node.baseobject.scale.controller firstframe lastframe then return true
    )
    if(node_type == "light") then
    (
        if nx_getcontrollerhaskeys node.rgb.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.radius.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.shadowradius.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.verticaldisplacement.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.multiplier.controller firstframe lastframe then return true
    )
    if(node_type == "emitter") then
    (
        if nx_getcontrollerhaskeys node.colorStart.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.colorMid.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.colorEnd.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.alphaStart.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.alphaMid.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.alphaEnd.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.sizeStart.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.sizeMid.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.sizeEnd.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.sizeStart_y.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.sizeMid_y.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.sizeEnd_y.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.percentStart.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.percentMid.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.percentEnd.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.frameStart.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.frameEnd.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.fps.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.lightningDelay.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.lightningRadius.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.lightningScale.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.lightningSubDiv.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.lightningzigzag.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.birthrate.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.m_fRandomBirthRate.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.lifeExp.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.mass.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.spread.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.particleRot.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.velocity.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.randvel.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.bounce_co.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.blurlength.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.targetsize.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.numcontrolpts.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.controlptradius.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.controlptdelay.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.tangentspread.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.tangentlength.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.detonate.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.p2p_bezier2.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.p2p_bezier3.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.grav.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.drag.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.xsize.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.ysize.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.threshold.controller firstframe lastframe then return true
        if nx_getcontrollerhaskeys node.combinetime.controller firstframe lastframe then return true
    )

    for child in node.children do
    (
        if(nx_isnodetreeanimated child firstframe lastframe) then return true
    )

    return false
)

fn nx_materialbitmapname mat =
(
    --
    -- Gets the material bitmap name.  If it cannot find it then returns NULL
    --
	if(mat == undefined) then
		return "NULL"

	if (mat.diffusemap== undefined or mat.diffusemap.filename==undefined) then
	(
        local tok = filterString mat.name " "
        if(tok[1] == "n/a") then return "NULL"
        else return tok[1]
	)

	return (getfilenamefile mat.diffusemap.filename)
)

-- MagnusLL: Get the lightmap file name, if present.
-- bead-v: mat is already processed to hold the right material by when this function is called.
fn nx_materiallightmapname mat =
(
    --
    -- Gets the material lightmap name.  If it cannot find it then returns NULL
    --
	if(mat == undefined) then
		return "NULL"

	if (mat.ambientmap==undefined or mat.ambientmap.filename==undefined) then
	(
        local tok = filterString mat.name " "
        if(tok.count < 2) then return "NULL"
        else return tok[2]
	)

	return (getfilenamefile mat.ambientmap.filename)
)
-- end modification

--------------------------------------------------------------------------------
-- texture exporting functions
--------------------------------------------------------------------------------

fn nx_copyTextureFiles nodeMaterial node exportdir = (

	type = nodeMaterial.diffusemap as string
	retval = matchPattern type pattern:"*bitmap"
	if (retval == true) then
	(
		local work

		-- get path of texture
		tex = nodeMaterial.diffusemap.filename

		if (BitMapNameCheck(node) == 0) then return 0

		-- get filename of texture
		filename = nx_lowercase( filenameFromPath tex )

		-- check to make sure source and target aren't the same
		if (tex != (exportdir+"\\"+filename)) then
		(
			-- convert from windows path to MAX path
			--tex = convertslash tex
			--work = convertslash (getdir #export)
			work = exportdir

			-- check to see if a file already has that filename
			-- in the export directory specified in MAX
			if ((getfiles (work +"/"+ filename)).count != 0) then
			(
				-- check to see if date modified is the same
				if ((getfilemoddate tex) != (getfilemoddate (work+"/"+filename))) then
				(
					str = "The texture \"" + work+"/"+filename + "\"\n"+
					"already exists.  Do you want to replace it?"

					if ((queryBox str title:"File Exists" beep:true) == false) then
					(
						return 0
					)
					-- need to delete old file before can copy into target
					deleteFile (work+"/"+filename)
				)
			)
			copyFile (tex) (work+"/"+filename)
		)
	)
)

-- function to check the current model for textures.  If any are used, copy them
-- to the export directory.  If there is already a file by the same name in the
-- export directory, a dialog will ask the user if they wish to overwrite it.  If
-- the modified date of both files match, then it will skip over that file.
fn nx_getTextures node modelbase =
(
	-- verify that the current node has a material applied to it
	local texture_exportpath = modelbase.export_path

	-- if we are also going to do the dds thing then we want a tga specific dir
	if modelbase.tga2dds == 1 then
	(
		texture_exportpath += "tga"
		-- does this dir exist?
		if not nx_existDir(texture_exportpath) then
		(
			-- dir does not exist so we create it
			if not (makeDir texture_exportpath) then
			(
				-- failure to make dir, abort
				messageBox "Failure to make tga export dir for dds conversion, aborting texture copy"
				return false
			)
		)
	)

	if (node.material != undefined) then
	(
		-- verify that the material uses a bitmap for the diffusemap
		if ((classof(node.material) == Multimaterial) or (classof(node.material) == MultiSubmaterial)) then
		(
			for i = 1 to node.material.numsubs do (

				if ((nx_copyTextureFiles node.material[i] node texture_exportpath)  == 0) then return 0

			)
		)
		else
				if ((nx_copyTextureFiles node.material node texture_exportpath)  == 0) then return 0

	)
	for i in node.children do
	(
		if ((nx_getTextures i modelbase) == 0) then
			return 0
	)
	return 1

)

/*
    This function is called by the dummy and outputs position and orientation. Also does some processing on emitter orientation.
*/
fn Ex3DOrientation node =
(
    if DEBUG then format "Ex3DOrientation::do %%" node.name g_delim to:g_strBuffer
    -- From Wayland's original script

    if DEBUG then (
        format "Data before 'in coordsys parent block'%" g_delim to:g_strBuffer
        format "objPos=%%" (at time 0 node.pos) g_delim to:g_strBuffer
    )

    in coordsys parent
    (
        if DEBUG then (
            format "Data in the 'in coordsys parent block'%" g_delim to:g_strBuffer
            format "objPos=%%" (at time 0 node.pos) g_delim to:g_strBuffer
        )

        local objPos = at time 0 node.pos;
        objPos *= 0.01  -- scale the model down by 100 to make it in meters

        local objRot = at time 0 node.rotation;

        -- Users should really apply an XForm to all p2p emitters, but in case
        -- they have forgotten we try to correct the emitters rotation
        -- back to 0 degrees.
        if ((nx_strclassof node) == "odysseyemitter") and \
           (node.modifiers["XForm"]==undefined) then
               objRot += quat -180 (point3 1 0 0);

        -- MAXScript vector normalisation is not producing results consistent with the source file,
        -- but is the over all result the same?  Looks ok when viewed and seems to behave ok.
        local rotVector = normalize (point3 -objRot.x -objRot.y -objRot.z)
        local angle = -degToRad(objRot.angle)

        format "%position % % %%" strIndent1 objPos.x objPos.y objPos.z g_delim to:g_strBuffer
        format "%orientation % % % %%" strIndent1 rotVector.x rotVector.y rotVector.z angle g_delim to:g_strBuffer
    )
    if DEBUG then format "Ex3DOrientation::End%" g_delim to:g_strBuffer

    nx_FlushBuffer()
)

--------------------------------------------------------------------------------
-- Specific node oriented functions
--------------------------------------------------------------------------------

/*
    This function's job should be printing out the parent and position + orientation.
    Also wirecolor, but we're getting rid of that.
*/
fn do_dummy node =
(
	if DEBUG then format "#do_dummy::on %%" node.name g_delim to:g_strBuffer

	-- get the parent name and put to listener
	local parent = "NULL"
	if (node.parent != undefined ) then
        parent = node.parent.name
	format "%parent %%" strIndent1 parent g_delim to:g_strBuffer

	-- default position and rotation except for odyssey base
	if ( (nx_strclassof node) != "odysseybase" ) then
	(
    	if DEBUG then format "node pos=%%" (at time 0 node.pos) g_delim to:g_strBuffer

    	-- this function prints out position and orientation
		Ex3DOrientation node;
		
		-- print out the wirecolor
		--format "%wirecolor %%"  strIndent1 (nx_fprints ode.wirecolor) g_delim to:g_strBuffer
	)

	nx_FlushBuffer()

	if DEBUG then format "#do_dummy::End%" g_delim to:g_strBuffer
)

/*
    This function's job should be printing out all of the light props
*/
function do_light node =
(
    -- lights have all their data held on the helper obj
    -- so process for it. Color is a special case that we deal with here
    local c = node.rgb
    local r = node.radius * 0.01
    local sr = node.shadowradius * 0.01
    local vd = node.verticaldisplacement * 0.01

    if node.negativeLight == 1 then
        format "  color %%" (nx_fprints -c) g_delim to:g_strBuffer
    else
        format "  color %%" (nx_fprints c) g_delim to:g_strBuffer
    format "  radius %%" r g_delim to:g_strBuffer
    format "  shadowradius %%" sr g_delim to:g_strBuffer
    format "  verticaldisplacement %%" vd g_delim to:g_strBuffer
    format "  multiplier %%" node.multiplier g_delim to:g_strBuffer

    format "  lightpriority %%" node.lightpriority g_delim to:g_strBuffer
    format "  ambientonly %%" node.ambientOnly g_delim to:g_strBuffer
    format "  nDynamicType %%" node.nDynamicType g_delim to:g_strBuffer
    format "  affectDynamic %%" node.affectDynamic g_delim to:g_strBuffer
    format "  shadow %%" node.Shadow g_delim to:g_strBuffer
    format "  flare %%" node.lensflares g_delim to:g_strBuffer -- bead-v: add flare
    format "  fadingLight %%" node.fadingLight g_delim to:g_strBuffer

    -- If there are flares, process for them
    if node.lens_flares.count > 0 then
    (
        local flare		-- for processing flares
        local tokens	-- for parsed flare string
        format "  flareradius %%" node.flareRadius g_delim to:g_strBuffer
        format "  texturenames %%" node.lens_flares.count g_delim to:g_strBuffer
        for flare in node.lens_flares do
        (
            tokens = filterString flare " "
            format "    %%" tokens[1] g_delim to:g_strBuffer
        )
        format "  flaresizes %%" node.lens_flares.count g_delim to:g_strBuffer
        for flare in node.lens_flares do
        (
            tokens = filterString flare " "
            format "    %%" tokens[2] g_delim to:g_strBuffer
        )
        format "  flarepositions %%" node.lens_flares.count g_delim to:g_strBuffer
        for flare in node.lens_flares do
        (
            tokens = filterString flare " "
            format "    %%" tokens[3] g_delim to:g_strBuffer
        )
        format "  flarecolorshifts %%" node.lens_flares.count g_delim to:g_strBuffer
        for flare in node.lens_flares do
        (
            tokens = filterString flare " "
            format "    % % %%" tokens[4] tokens[5] tokens[6] g_delim to:g_strBuffer
        )
    )
    nx_FlushBuffer()
)

/*
    This function's job should be printing out all of the emitter props
*/
function do_emitter node =
(
	if DEBUG then format "#do_emitter%" g_delim to:g_strBuffer

	/*
	-- Filter array of strings for properties we DON'T want
	local invalidProps = #("cone_angle_manipulator","gizmo", \
							"twosidedtext", "chunk", "chunky", "iconsize", \
							"sanity_check", "sanity_tests", "copy_tga", "tga2dds", "sanityok")
	local propStr
	local propVal
	*/

	-- Emitter Header properties
    format "%deadspace %%" strIndent1 (nx_fprints (degtorad node.deadspace)) g_delim to:g_strBuffer
    format "%blastRadius %%" strIndent1 (nx_fprints node.blastRadius) g_delim to:g_strBuffer
    format "%blastLength %%" strIndent1 (nx_fprints node.blastLength) g_delim to:g_strBuffer
    format "%numBranches %%" strIndent1 (nx_fprints node.numBranches) g_delim to:g_strBuffer
    format "%controlptsmoothing %%" strIndent1 (nx_fprints node.controlptsmoothing) g_delim to:g_strBuffer
    format "%xgrid %%" strIndent1 (nx_fprints node.xgrid) g_delim to:g_strBuffer
    format "%ygrid %%" strIndent1 (nx_fprints node.ygrid) g_delim to:g_strBuffer
    format "%spawntype %%" strIndent1 (nx_fprints node.spawntype) g_delim to:g_strBuffer
    format "%update %%" strIndent1 (nx_fprints node.update) g_delim to:g_strBuffer
    format "%render %%" strIndent1 (nx_fprints node.render) g_delim to:g_strBuffer
    format "%blend %%" strIndent1 (nx_fprints node.blend) g_delim to:g_strBuffer
    format "%texture %%" strIndent1 (nx_fprints node.texture) g_delim to:g_strBuffer
    format "%chunkname %%" strIndent1 (nx_fprints node.chunkName) g_delim to:g_strBuffer
    format "%twosidedtex %%" strIndent1 (nx_fprints node.twosidedtex) g_delim to:g_strBuffer
    format "%loop %%" strIndent1 (nx_fprints node.loop) g_delim to:g_strBuffer
    format "%renderorder %%" strIndent1 (nx_fprints node.renderorder) g_delim to:g_strBuffer
    format "%m_bFrameBlending %%" strIndent1 (nx_fprints node.m_bFrameBlending) g_delim to:g_strBuffer
    format "%m_sDepthTextureName %%" strIndent1 (nx_fprints node.m_sDepthTextureName) g_delim to:g_strBuffer
	nx_FlushBuffer()
	
	-- Emitter flags
    format "%p2p %%" strIndent1 (nx_fprints node.p2p) g_delim to:g_strBuffer
    format "%p2p_sel %%" strIndent1 (nx_fprints node.p2p_sel) g_delim to:g_strBuffer
    format "%affectedByWind %%" strIndent1 (nx_fprints node.affectedByWind) g_delim to:g_strBuffer
    format "%m_isTinted %%" strIndent1 (nx_fprints node.m_isTinted) g_delim to:g_strBuffer
    format "%bounce %%" strIndent1 (nx_fprints node.bounce) g_delim to:g_strBuffer
    format "%random %%" strIndent1 (nx_fprints node.random) g_delim to:g_strBuffer
    format "%inherit %%" strIndent1 (nx_fprints node.inherit) g_delim to:g_strBuffer
    format "%inheritvel %%" strIndent1 (nx_fprints node.inheritvel) g_delim to:g_strBuffer
    format "%inherit_local %%" strIndent1 (nx_fprints node.inherit_local) g_delim to:g_strBuffer
    format "%splat %%" strIndent1 (nx_fprints node.splat) g_delim to:g_strBuffer
    format "%inherit_part %%" strIndent1 (nx_fprints node.inherit_part) g_delim to:g_strBuffer
    format "%depth_texture %%" strIndent1 (nx_fprints node.depth_texture) g_delim to:g_strBuffer
	nx_FlushBuffer()
	
	-- Emitter Controllers
    format "%alphaStart %%" strIndent1 (nx_fprints node.alphaStart) g_delim to:g_strBuffer
    format "%alphaMid %%" strIndent1 (nx_fprints node.alphaMid) g_delim to:g_strBuffer
    format "%alphaEnd %%" strIndent1 (nx_fprints node.alphaEnd) g_delim to:g_strBuffer
    format "%colorStart %%" strIndent1 (nx_fprints node.colorStart) g_delim to:g_strBuffer
    format "%colorMid %%" strIndent1 (nx_fprints node.colorMid) g_delim to:g_strBuffer
    format "%colorEnd %%" strIndent1 (nx_fprints node.colorEnd) g_delim to:g_strBuffer
    format "%percentStart %%" strIndent1 (nx_fprints node.percentStart) g_delim to:g_strBuffer
    format "%percentMid %%" strIndent1 (nx_fprints node.percentMid) g_delim to:g_strBuffer
    format "%percentEnd %%" strIndent1 (nx_fprints node.percentEnd) g_delim to:g_strBuffer
    format "%sizeStart %%" strIndent1 (nx_fprints node.sizeStart) g_delim to:g_strBuffer
    format "%sizeMid %%" strIndent1 (nx_fprints node.sizeMid) g_delim to:g_strBuffer
    format "%sizeEnd %%" strIndent1 (nx_fprints node.sizeEnd) g_delim to:g_strBuffer
    format "%sizeStart_y %%" strIndent1 (nx_fprints node.sizeStart_y) g_delim to:g_strBuffer
    format "%sizeMid_y %%" strIndent1 (nx_fprints node.sizeMid_y) g_delim to:g_strBuffer
    format "%sizeEnd_y %%" strIndent1 (nx_fprints node.sizeEnd_y) g_delim to:g_strBuffer
    format "%birthrate %%" strIndent1 (nx_fprints node.birthrate) g_delim to:g_strBuffer
    format "%m_fRandomBirthRate %%" strIndent1 (nx_fprints node.m_fRandomBirthRate) g_delim to:g_strBuffer
    format "%lifeExp %%" strIndent1 (nx_fprints node.lifeExp) g_delim to:g_strBuffer
    format "%mass %%" strIndent1 (nx_fprints node.mass) g_delim to:g_strBuffer
    format "%spread %%" strIndent1 (nx_fprints (degtorad node.spread)) g_delim to:g_strBuffer
    format "%particleRot %%" strIndent1 (nx_fprints node.particleRot) g_delim to:g_strBuffer
    format "%velocity %%" strIndent1 (nx_fprints node.velocity) g_delim to:g_strBuffer
    format "%randvel %%" strIndent1 (nx_fprints node.randvel) g_delim to:g_strBuffer
    format "%blurlength %%" strIndent1 (nx_fprints node.blurlength) g_delim to:g_strBuffer
    format "%targetsize %%" strIndent1 (nx_fprints node.targetsize) g_delim to:g_strBuffer
    format "%tangentspread %%" strIndent1 (nx_fprints node.tangentspread) g_delim to:g_strBuffer
    format "%tangentlength %%" strIndent1 (nx_fprints node.tangentlength) g_delim to:g_strBuffer
    format "%detonate %%" strIndent1 (nx_fprints node.detonate) g_delim to:g_strBuffer
    format "%bounce_co %%" strIndent1 (nx_fprints node.bounce_co) g_delim to:g_strBuffer
    format "%fps %%" strIndent1 (nx_fprints node.fps) g_delim to:g_strBuffer
    format "%frameStart %%" strIndent1 (nx_fprints node.frameStart) g_delim to:g_strBuffer
    format "%frameEnd %%" strIndent1 (nx_fprints node.frameEnd) g_delim to:g_strBuffer
    format "%xsize %%" strIndent1 (nx_fprints node.xsize) g_delim to:g_strBuffer
    format "%ysize %%" strIndent1 (nx_fprints node.ysize) g_delim to:g_strBuffer
    format "%threshold %%" strIndent1 (nx_fprints node.threshold) g_delim to:g_strBuffer
    format "%combinetime %%" strIndent1 (nx_fprints node.combinetime) g_delim to:g_strBuffer
    format "%lightningDelay %%" strIndent1 (nx_fprints node.lightningDelay) g_delim to:g_strBuffer
    format "%lightningRadius %%" strIndent1 (nx_fprints node.lightningRadius) g_delim to:g_strBuffer
    format "%lightningScale %%" strIndent1 (nx_fprints node.lightningScale) g_delim to:g_strBuffer
    format "%lightningSubDiv %%" strIndent1 (nx_fprints node.lightningSubDiv) g_delim to:g_strBuffer
    format "%lightningzigzag %%" strIndent1 (nx_fprints node.lightningzigzag) g_delim to:g_strBuffer
    format "%drag %%" strIndent1 (nx_fprints node.drag) g_delim to:g_strBuffer
    format "%grav %%" strIndent1 (nx_fprints node.grav) g_delim to:g_strBuffer
    format "%p2p_bezier2 %%" strIndent1 (nx_fprints node.p2p_bezier2) g_delim to:g_strBuffer
    format "%p2p_bezier3 %%" strIndent1 (nx_fprints node.p2p_bezier3) g_delim to:g_strBuffer
    format "%numcontrolpts %%" strIndent1 (nx_fprints node.numcontrolpts) g_delim to:g_strBuffer
    format "%controlptradius %%" strIndent1 (nx_fprints node.controlptradius) g_delim to:g_strBuffer
    format "%controlptdelay %%" strIndent1 (nx_fprints node.controlptdelay) g_delim to:g_strBuffer
	nx_FlushBuffer()
	
	/*
	for prop in (getpropnames node) do
	(
    	-- We will need to perform some filtering on what
    	-- properties we want to output
     	if (findItem invalidProps (nx_lowercase (prop as string))) == 0 then
       	(
		  	propStr = prop as string
		  	propVal = (getproperty node prop)
		  	if (getproperty node prop) != undefined then
		  	(
			  	-- special case processing required
			  	case of
			  	(
				  	((propStr == "spread") or (propStr == "deadspace")):
				  	(
					  	format "%% %%" strIndent1 propStr (nx_fprints (degtorad propVal)) g_delim to:g_strBuffer
				  	)

				  	(propStr == "chunkName"):
				  	(
					  	-- we only put out chunkName if it is not a "NULL" value
					  	if propVal != "NULL" then (
						  	format "%% %%" strIndent1 propStr (nx_fprints propVal) g_delim to:g_strBuffer
					  	)
				  	)

				  	default: format "%% %%" strIndent1 propStr (nx_fprints propVal) g_delim to:g_strBuffer
			  	)
			)
			else
			(
				format "%#% %%" strIndent1 propStr (nx_fprints propVal) g_delim to:g_strBuffer
	        )
			nx_FlushBuffer()
	    )
	)
	*/
	if DEBUG then format "#do_emitter:: End%" g_delim to:g_strBuffer
)

/*
    This function's job is printing out all the props for all the mesh-related modifiers.
    In practice, this really only means OdysseyTrimesh and OdysseyFlex.
    It is only inside this function that we care whether there is an OdysseyTrimesh modifier
    present on a mesh or not.
*/
fn do_modifier_props node mat =
(
    if DEBUG then format "#do_modifier_props%" g_delim to:g_strBuffer

    local odyssey_modifier = undefined

    if(classof node.baseobject as string == "odysseylightsaber") then
    (
        format "%scale %%" strIndent1 (nx_fprints node.saberscale) g_delim to:g_strBuffer
    )
    nx_FlushBuffer()

    odyssey_modifier = node.modifiers["OdysseyTrimesh"]
    if(odyssey_modifier != undefined) then
    (
        format "%scale %%" strIndent1 (nx_fprints odyssey_modifier.scale) g_delim to:g_strBuffer
        format "%alpha %%" strIndent1 (nx_fprints odyssey_modifier.alpha) g_delim to:g_strBuffer
        format "%selfillumcolor %%" strIndent1 (nx_fprints odyssey_modifier.selfillumcolor) g_delim to:g_strBuffer

        if odyssey_modifier.extra_mat_data != 0 then
        (
            format "%ambient %%" strIndent1 (nx_fprints odyssey_modifier.ambient) g_delim to:g_strBuffer
            format "%diffuse %%" strIndent1 (nx_fprints odyssey_modifier.diffuse) g_delim to:g_strBuffer
            --format "%specular %%" strIndent1 (nx_fprints odyssey_modifier.specular) g_delim to:g_strBuffer
            --format "%shininess %%" strIndent1 (nx_fprints odyssey_modifier.shininess) g_delim to:g_strBuffer
        )
        else if mat != undefined then
        (
            local a = mat.ambient
            local d = mat.diffuse
            local sp = mat.specular * (mat.specularlevel/100.0)
            local sh = mat.glossiness
            local illum = mat.selfillumcolor
            local alpha = mat.opacity / 100.0

            --format "%alpha %%" strIndent1 (nx_fprints alpha) g_delim to:g_strBuffer
            --format "%selfillumcolor %%" strIndent1 (nx_fprints illum) g_delim to:g_strBuffer
            format "%ambient %%"  strIndent1 (nx_fprints a) g_delim to:g_strBuffer
            format "%diffuse %%"  strIndent1 (nx_fprints d) g_delim to:g_strBuffer
            --format "%specular %%"  strIndent1 (nx_fprints sp) g_delim to:g_strBuffer
            --format "%shininess %%"  strIndent1 (nx_fprints sh) g_delim to:g_strBuffer
        )
        format "%render %%" strIndent1 (nx_fprints odyssey_modifier.render) g_delim to:g_strBuffer
        format "%shadow %%" strIndent1 (nx_fprints odyssey_modifier.shadow) g_delim to:g_strBuffer
        format "%beaming %%" strIndent1 (nx_fprints odyssey_modifier.beaming) g_delim to:g_strBuffer
        format "%rotatetexture %%" strIndent1 (nx_fprints odyssey_modifier.rotatetexture) g_delim to:g_strBuffer
        format "%lightmapped %%" strIndent1 (nx_fprints odyssey_modifier.lightmapped) g_delim to:g_strBuffer
        format "%hologram_donotdraw %%" strIndent1 (nx_fprints odyssey_modifier.hologram_donotdraw) g_delim to:g_strBuffer
        format "%m_blsBackgroundGeometry %%" strIndent1 (nx_fprints odyssey_modifier.m_blsBackgroundGeometry) g_delim to:g_strBuffer
        format "%transparencyhint %%" strIndent1 (nx_fprints odyssey_modifier.transparencyhint) g_delim to:g_strBuffer
        format "%dirt_enabled %%" strIndent1 (nx_fprints odyssey_modifier.dirt_enabled) g_delim to:g_strBuffer
        format "%dirt_texture %%" strIndent1 (nx_fprints odyssey_modifier.dirt_texture) g_delim to:g_strBuffer
        format "%dirt_worldspace %%" strIndent1 (nx_fprints odyssey_modifier.dirt_worldspace) g_delim to:g_strBuffer
        format "%animateuv %%" strIndent1 (nx_fprints odyssey_modifier.animateuv) g_delim to:g_strBuffer
        format "%uvdirectionx %%" strIndent1 (nx_fprints odyssey_modifier.uvdirectionx) g_delim to:g_strBuffer
        format "%uvdirectiony %%" strIndent1 (nx_fprints odyssey_modifier.uvdirectiony) g_delim to:g_strBuffer
        format "%uvjitter %%" strIndent1 (nx_fprints odyssey_modifier.uvjitter) g_delim to:g_strBuffer
        format "%uvjitterspeed %%" strIndent1 (nx_fprints odyssey_modifier.uvjitterspeed) g_delim to:g_strBuffer
        format "%tangentspace %%" strIndent1 (nx_fprints odyssey_modifier.tangentspace) g_delim to:g_strBuffer
    )
    else if mat != undefined then
    (
         -- if we do not have the trimesh modifier, we can still (try to) get some stuff from the material
		local a = mat.ambient
		local d = mat.diffuse
		local sp = mat.specular * (mat.specularlevel/100.0)
		local sh = mat.glossiness
		local illum = mat.selfillumcolor
        local alpha = mat.opacity / 100.0

        format "%alpha %%" strIndent1 (nx_fprints alpha) g_delim to:g_strBuffer
		format "%selfillumcolor %%" strIndent1 (nx_fprints illum) g_delim to:g_strBuffer
		format "%ambient %%"  strIndent1 (nx_fprints a) g_delim to:g_strBuffer
		format "%diffuse %%"  strIndent1 (nx_fprints d) g_delim to:g_strBuffer
		--format "%specular %%"  strIndent1 (nx_fprints sp) g_delim to:g_strBuffer
		--format "%shininess %%"  strIndent1 (nx_fprints sh) g_delim to:g_strBuffer
    )
    nx_FlushBuffer()

    odyssey_modifier = node.modifiers["OdysseyFlex"]
    if(odyssey_modifier != undefined) then
    (
        format "%period %%" strIndent1 (nx_fprints odyssey_modifier.period) g_delim to:g_strBuffer
        format "%tightness %%" strIndent1 (nx_fprints odyssey_modifier.tightness) g_delim to:g_strBuffer
        format "%displacement %%" strIndent1 (nx_fprints odyssey_modifier.displacement) g_delim to:g_strBuffer
    )
    nx_FlushBuffer()

    if DEBUG then format "#do_modifier_props:: End%" g_delim to:g_strBuffer
)

/*
    This function's job is printing out mesh geometry.
    -- Build the mesh
    -- Covers:
    -- * bitmap names (bitmap, bitmap2 for now)
    -- * verts
    -- * faces (also for channel2)
    -- * tverts (also for channel2)
    -- * colors (currently commented out)
    --
    -- This code is taken from Bioware's export script. It has been modified
    -- to suit the NWmax code structure and has been cross checked with
    -- Wayland's code to check for consistency.
    --
    -- Params:
    -- mesh = the mesh obj
    -- mat = the material
*/
fn do_mesh mesh mat =
(
    if mesh == undefined then return false

    if DEBUG then format "#do_mesh % %%" mesh mat g_delim to:g_strBuffer
    if SPEEDT then nx_startStopWatch txt:"do_mesh"

	-- determine bitmapnames
	local bitmapname
	local bitmap2name
	if mat == undefined then
    (
		bitmapname = "NULL"
		bitmap2name = "NULL"
    )
	else
	(
		bitmapname = nx_materialbitmapname(mat)
        bitmap2name = nx_materiallightmapname(mat)
    )
	
	format "%bitmap %%" strIndent1 bitmapname g_delim to:g_strBuffer
	if (meshop.getNumMaps mesh > 2 and meshop.getMapSupport mesh 2) then format "%bitmap2 %%" strIndent1 bitmap2name g_delim to:g_strBuffer

	-- build vertex entry
	format "%verts %%" strIndent1 mesh.numverts g_delim to:g_strBuffer
	for i = 1 to mesh.numverts do
	(
		local v,x,y,z
		local round,round_result
	
		v = getvert mesh i
		-- We round to the nearest centimetre before converting to metres
		-- MAXscript doesn't have a round function, so we make our own
		if (g_RoundOffVertices == true) then
			v = nx_roundp3 v
		x = v.x * 0.01 -- convert to application unit length (meters)
		y = v.y * 0.01
		z = v.z * 0.01
		format "%% % %%" strIndent2 x y z g_delim to:g_strBuffer
		
		nx_FlushBuffer()
	)

	-- build faces entry
	format "%faces %%" strIndent1 mesh.numfaces g_delim to:g_strBuffer
	for i=1 to mesh.numfaces do
	(
		local f, v0, v1, v2 ,s ,t0,t1,t2,matid
		f = getface mesh i
		-- remember to subtract 1 since maxscript indexes from 1 instead of 0
		v0 = (f.x as integer) - 1  -- fix the index by 1 problem
		v1 = (f.y as integer) - 1
		v2 = (f.z as integer) - 1
		s  = getFaceSmoothGroup mesh i
		t0=0
		t1=0
		t2=0
		matid=getfacematid mesh i
		if matid == 65536 then matid = 0	-- if the value is 65536 then there is no matid assigned
		if(mesh.numtverts>0) do
		(
			local f
			tvf = gettvface mesh i
			t0 = (tvf.x as integer) - 1
			t1 = (tvf.y as integer) - 1
			t2 = (tvf.z as integer) - 1
		)

		format  "%% % %  %  % % %  %%" strIndent2 v0 v1 v2  s  t0 t1 t2 matid g_delim to:g_strBuffer

		nx_FlushBuffer()
	)


	-- bead-v modification: texindices-style export	-- build faces entry
    -- bead-v: check if there are more than the default number of channels (2)
    if (meshop.getNumMaps mesh > 2 and meshop.getMapSupport mesh 2) then
    (
        if(meshop.getNumMapFaces mesh 2 > 0) do
        (
            format "%texindices1 %%" strIndent1 mesh.numfaces g_delim to:g_strBuffer
            for i=1 to mesh.numfaces do(
                local l0, l1, l2
                l0=0
                l1=0
                l2=0

                local l
                tvl = meshop.getMapFace mesh 2 i
                l0 = (tvl.x as integer) - 1
                l1 = (tvl.y as integer) - 1
                l2 = (tvl.z as integer) - 1

                format  "%% % %%" strIndent2 l0 l1 l2 g_delim to:g_strBuffer
                nx_FlushBuffer()
            )
         )
	)

	-- determine uv coordinate correction
	local clipu,clipv,clipw,cliph
	clipu=0
	clipv=0
	clipw=1
	cliph=1
	if(mat != undefined and mat.diffusemap!= undefined ) then
	(
		clipu = mat.diffusemap.clipu
		clipv = mat.diffusemap.clipv
		clipw = mat.diffusemap.clipw
		cliph = mat.diffusemap.cliph
		-- it might be upside down since
		-- from the aura exporter we had a line like the following:
		clipv = 1 - clipv - cliph
	)

	-- export texture coordinates if they exist
	if(mesh.numtverts > 0) do
	(
		format "%tverts %%" strIndent1 mesh.numtverts g_delim to:g_strBuffer
		for i=1 to mesh.numtverts do
		(
			local v
			v = getTVert mesh i
			format "%% %%" strIndent2 (v.x*clipw + clipu) (v.y*cliph + clipv) g_delim to:g_strBuffer
			nx_FlushBuffer()
		)
	)


     -- MagnusLL: export lightmap coordinates if they exist (we are assuming lightmap channel = 2)
     -- bead-v modification: check if there are more than the default number of channels (2)
     if (meshop.getNumMaps mesh > 2 and meshop.getMapSupport mesh 2) then
     (
        local lightmapverts = meshop.getNumMapVerts mesh 2
		format "%tverts1 %%" strIndent1 lightmapverts g_delim to:g_strBuffer
		for i=1 to lightmapverts do
		(
			local v
			v = meshop.getMapVert mesh 2 i
			format "%% %%" strIndent2 (v.x*clipw + clipu) (v.y*cliph + clipv) g_delim to:g_strBuffer
			nx_FlushBuffer()
		)

     )


	/*
	Not sure that this is actually required.  Wayland's script does not seem to
	make any use of colors on verts other than to calc the constraints for a
	danglymesh.  Will keep it in here comment at this point just in case ...
	
	bead-v: the Odyssey MDL format seems to have an MDX struct dedicated to colors.
	Therefore, this code should be preserved in case someday somebody figures out they actually do something.
	However, in KOTORmax, colors are already used in OdysseyFlex and OdysseyWalkmesh

	if (mesh.numcpvverts > 0) then
	(
		-- Taken from the MAXscript docs....
		--//   The mesh class contains a list of color vertices which are completely independent of the regular vertices
		--// in the mesh. There is no correlation between the number of vertices in a mesh and the number of color
		--// vertices. In addition to the color vertices there are also color faces. There needs to be one color face for
		--// every regular face in the mesh.

		local colourVertIndices, faceIndices
		local colourVerts = #()

		-- build up the color vetices
		for i=1 to mesh.numfaces do
		(
			colourVertIndices = getVCFace mesh i
			faceIndices = getFace mesh i

			colourVerts[faceIndices.x] = getvertcolor mesh colourVertIndices.x
			colourVerts[faceIndices.y] = getvertcolor mesh colourVertIndices.y
			colourVerts[faceIndices.z] = getvertcolor mesh colourVertIndices.z
		)

		--
		-- Not sure if color should be goiing out when the mesh has a
		-- Flex modifier
		--
		-- export the color vertices
		format "  colors %\r\n" colourVerts.count
		for i = 1 to colourVerts.count do
		(
			-- If you read the above passage from the MXS docs, you'll note that it implies that
			-- not all sequential colour vertices are necessarily valid, requiring the following
			-- check
			if (colourVerts[i] == undefined) then
				colourVerts[i] = color 255 255 255
			format "     % % %\r\n" (colourVerts[i].red/255.0) (colourVerts[i].green/255.0) (colourVerts[i].blue/255.0)
		)

	) 
	*/
	
    if DEBUG then format "#do_mesh:: End%" g_delim to:g_strBuffer
    if SPEEDT then nx_stopStopWatch txt:"do_mesh"
)

/*
    This function's job is printing out mesh data and odyssey props.
    Important: this function is not restricted to the OdysseyTrimesh modifier.
    It will export data for any mesh, and the props for any Odyssey modifier
    that has props to be exported.
    This function doesn't actually do all that work. All it does is determine
    the material, which it then passes to do_mesh() and do_modifier_props().
*/
function do_trimesh node =
(
    -- Joco: Code from Bioware's scripts with some enhancements/corrections
    -- based on data from Wayland's scripts and my own checking.
	-- Verts in 'node' are in worldspace but 'node.mesh' gives a mesh
	-- in object space which we use to export
    if DEBUG then format "#do_trimesh%" g_delim to:g_strBuffer

	/* DETERMINE MATERIAL */
	local mat = node.material

    -- MagnusLL: if we're using shell materials due to lightmap baking, we need to get the bakedmaterial subclass
    if classof mat == Shell_Material then
       mat = mat.bakedMaterial

	if((nx_strclassof mat) == "Multimaterial") then
	(
		format "%multimaterial %%" strIndent1 mat.count g_delim to:g_strBuffer
		local mesh
		for mesh in mat do (
			format "%%%"  strIndent2 (nx_materialbitmapname(mesh)) g_delim to:g_strBuffer
			nx_FlushBuffer()
		)
		-- we should work out what the correct material is based on the vertex.
		-- We use the first face in the mesh and get that mat id as the index
		-- into the multimaterial.

		-- bead-v: The MDL format does not support multimaterial anyway, so we will now just make the material undefined
		--mat = mat[(getFaceMatID node.mesh 1)]
        mat = undefined
	)

	/* Write out the props for all the modifiers that the mesh may have */
	do_modifier_props node mat

	/* Export out the mesh itself */
	-- NOTE: We pass a mesh to this function and the mesh has verts in object space.
	do_mesh node.mesh mat

    if DEBUG then format "#do_trimesh:: End%" g_delim to:g_strBuffer
) -- end fn

function do_skin node =
(
    -- Code from Bioware
	local save_selection = selection
	--clearSelection()
	--deselect selection
	select node
	max modify mode
    --setCommandPanelTaskMode mode:#modify
	--select node
	local m = node.modifiers["skin"]
    modPanel.setCurrentObject m
    --local oSelected = modPanel.getCurrentObject()
	
	--if selection[1] != undefined then messageBox ("Selected node: " + (selection[1]).name)
	--if oSelected != undefined then messageBox ("Selected modifier: " + oSelected.name)
	
    --modPanel.setCurrentObject m
	local i,j,zeroWeights
	--while modPanel.getCurrentObject != m do modPanel.setCurrentObject m
	try
	(
		local n = skinops.getnumbervertices m
	--/*
	) catch
	(
		--local n = skinops.getnumbervertices m
		format ";ERROR in do_skin%" g_delim to:g_strBuffer
		nx_FlushBuffer()
		select save_selection
		return 0
	)
	--*/
	format "%weights %%" strIndent1 n g_delim to:g_strBuffer
	for i = 1 to n do
	(
		local w_num = skinops.getvertexweightcount m i
		local counter = 0
		format "%" strIndent2 to:g_strBuffer
		for j = 1 to w_num do
		(
			local bone_id = (skinops.getvertexweightboneid m i j )
			local bone_name = "root"
			local weight_i_j = 1
			if(bone_id > 0) do
			(
				local nMaxVersion = (maxversion())[1]
				if (nMaxVersion <= 14000) then bone_name = (skinops.getbonename m bone_id 1)  -- per VP, the above doesn't work in later versions of max. Instead we should try the following:
				else if (nMaxVersion < 17000) then bone_name = (skinops.getbonenamebylistid m bone_id 1)
				else bone_name = skinops.getbonename m (skinOps.GetBoneIDByListID m bone_id) 1
			)
			weight_i_j = (skinops.getvertexweight m i j )
			if (weight_i_j != 0.0) then (
				format " % % "  bone_name weight_i_j to:g_strBuffer
				counter += 1
			)
		)
		if(( w_num ==0 ) or (counter == 0) ) do
		(
			format " root 1.00 " to:g_strBuffer
		)
		format "%" g_delim to:g_strBuffer
		nx_FlushBuffer()
	)
	if(save_selection != undefined) do
	(
		select save_selection
	)
	--max create mode
)

function do_dangly node =
(
    -- Code from BioWare & Wayland.
	-- Export the vertex constraints.
	-- The other parameters got exported with the rest of the OdysseyPoly stuff
	format "%constraints %%" strIndent1 node.numverts g_delim to:g_strBuffer

	-- Taken from the MAXscript docs....
	--//   The mesh class contains a list of color vertices which are completely independent of the regular vertices
	--// in the mesh. There is no correlation between the number of vertices in a mesh and the number of color
	--// vertices. In addition to the color vertices there are also color faces. There needs to be one color face for
	--// every regular face in the mesh.

	local colourVertIndices, faceIndices
	local colourVerts = #()

	-- collect the colour verts info by face and store in the
	-- colour 'colourVerts' array.
	for i = 1 to node.numfaces do
	(
		colourVertIndices = getVCFace node i
		faceIndices = getFace node i

		colourVerts[faceIndices.x] = getvertcolor node colourVertIndices.x
		colourVerts[faceIndices.y] = getvertcolor node colourVertIndices.y
		colourVerts[faceIndices.z] = getvertcolor node colourVertIndices.z
	)

	-- Work through the colour verts info collected above and out put it.
	local curcolour = color 255 255 255
	for i = 1 to colourVerts.count do
	(
		curcolour = colourVerts[i]

		-- If the colour is white, the vertex is fixed
		if ((curcolour != undefined) and (curcolour != (color 255 255 255))) then
		(
			-- A zero value causes discontinuities in the physics calculations,
			-- therefore we can ignore that case. Also only use one color value
			-- for the constraint. Have picked the first one in the rgb triplet.

			-- Setting this to 1 when it should be 0 seems to have undesired results. 0 is
			-- used to STOP dangly activity so setting to 1 defeats that purpose.
			--			if (curcolour.red == 0) then
			--				curcolour.red = 1
			format "%%%" strIndent2 (curcolour.red) g_delim to:g_strBuffer
		)
		else format "%0.0%" strIndent2 g_delim to:g_strBuffer
		nx_FlushBuffer()
	)
)

fn do_aabb node =
(
    if SPEEDT then nx_startStopWatch txt:"do_aabb"

	local ssTempBuffer = stringStream ""
	local nTransitions = 0

	for f = 1 to (meshop.getNumFaces node) do
	(
        local ClrVertInds = getVCFace node f
        for i = 1 to 3 do
        (
            local VertColor = getVertColor node ClrVertInds[i]
            if(VertColor.b == 0 and VertColor.r == 0 and VertColor.g >= 100) then
            (
                nTransitions += 1
                format "    % %%" ((f - 1)* 3 + i - 1) ((VertColor.g as Integer) - 100) g_delim to:ssTempBuffer
            )
        )
	)

	if(nTransitions > 0) then
	(
        format "  roomlinks %%" nTransitions g_delim to:g_strBuffer
        format "%" (ssTempBuffer as string) to:g_strBuffer
        nx_FlushBuffer()
    )

    if SPEEDT then nx_stopStopWatch txt:"do_aabb"
)

/*
	This function exports an ascii wok file if the option is checked.
*/
fn exportWok node = 
(
	local filename
	filename = nx_lowercase( g_exportPath + (nx_CreateExportName g_ModelName) + ".wok" )
	if g_ismax then (
	   nx_push g_FileHandles g_strBuffer
	   g_strBuffer = createFile filename
	   if g_strBuffer == undefined then
		   format "ERROR: File creatin failure for: %\r\n" filename
	)
	else format "<snoopstart file=%>%" filename g_delim to:g_strBuffer

	/* START WRITING FILE */
	format "# Exported from KOTORmax % at %%" gblVersion localtime g_delim to:g_strBuffer
	format "# WOKMESH  ASCII%" g_delim to:g_strBuffer
	format "node trimesh %%" node.name g_delim to:g_strBuffer
	
	do_dummy node
	
	local objPos = in coordsys world at time 0 node.pos
    objPos *= 0.01  -- scale the model down by 100 to make it in meters
	local meshcopy = node.mesh
	meshop.weldVertsByThreshold meshcopy meshcopy.vertices 0.01

	-- build vertex entry
	format "%verts %%" strIndent1 meshcopy.numverts g_delim to:g_strBuffer
	for i = 1 to meshcopy.numverts do
	(
		local v = getvert meshcopy i
		-- We round to the nearest centimetre before converting to metres
		-- MAXscript doesn't have a round function, so we make our own
		if (g_RoundOffVertices == true) then v = nx_roundp3 v
		v = v * 0.01 + objPos
		format "%% % %%" strIndent2 v.x v.y v.z g_delim to:g_strBuffer
		
		nx_FlushBuffer()
	)

	-- build faces entry
	format "%faces %%" strIndent1 meshcopy.numfaces g_delim to:g_strBuffer
	for i=1 to meshcopy.numfaces do
	(
		local f, v0, v1, v2, matid
		f = getface meshcopy i
		-- remember to subtract 1 since maxscript indexes from 1 instead of 0
		v0 = (f.x as integer) - 1  -- fix the index by 1 problem
		v1 = (f.y as integer) - 1
		v2 = (f.z as integer) - 1
		
		matid = getFaceMatID meshcopy i
		if matid == 65536 then matid = 0	-- if the value is 65536 then there is no matid assigned

		format  "%% % %  1  0 0 0  %%" strIndent2 v0 v1 v2 matid g_delim to:g_strBuffer

		nx_FlushBuffer()
	)
	
	do_aabb meshcopy
	
	format "endnode%" g_delim to:g_strBuffer
	/* STOP WRITING FILE */
	
	if g_ismax then (
		flush g_strBuffer
		close g_strBuffer
		g_strBuffer = nx_pop g_FileHandles
	)
	else format "</snoopstart>%" g_delim to:g_strBuffer
)

-------------------------------------------------
-- Function to process master Node Geometry data
-------------------------------------------------
sExtraNames = #()
fn Node_Geometry node type:"mdl" root:false =
(
    /*
       A mix of My, Waylands and Bioware's code.

       Parameters:
       node = node to operate on
       type = optional param. Type of file being generated.
              valid types: mdl, pwk, dwk
    */

    if DEBUG then format "#Node_Geometry: % of type %%" node.name (classof node) g_delim to:g_strBuffer
    if DEBUG then format "#Node_Geometry:: type=%%" type g_delim to:g_strBuffer

    g_nodeprog += 1
    nx_progressUpdate()

	--
	-- Work out what type of node we have here
	--

    local node_type = nx_getnodetype node
    if DEBUG then format "#Node_Geometry:: node_type=%%" node_type g_delim to:g_strBuffer
    /*
        possible values:
        GEOM:
         - trimesh
         - skin
         - danglymesh
         - aabb
         - lightsaber
        NO GEOM:
         - dummy
		 - base
         - light
         - emitter

         We should assume no geometry with dummy, light, emitter.
         Types trimesh, danglymesh, skin, aabb, lightsaber may or may not have an OdysseyTrimesh modifier. A further check will be necessary down the road.
         Lightsaber probably shouldn't have it at all, actually.
    */

    -- If we have a pwk or dwk root, start writing out the .pwk/.dwk file
    if matchPattern node.name pattern:"*_pwk" and (classof node.parent as string == "odysseybase") then
    (
        local filename
        filename = nx_lowercase( g_exportPath + (nx_CreateExportName g_ModelName) + ".pwk" )
        if g_ismax then (
           nx_push g_FileHandles g_strBuffer
           g_strBuffer = createFile filename
           if g_strBuffer == undefined then
               format "ERROR: File creatin failure for: %\r\n" filename
        )
        else format "<snoopstart file=%>%" filename g_delim to:g_strBuffer

        type = "pwk"
        format "# Exported from KOTORmax % at %%" gblVersion localtime g_delim to:g_strBuffer
        format "# PWKMESH  ASCII%" g_delim to:g_strBuffer
    )
    else if matchPattern node.name pattern:"*_dwk" and (classof node.parent as string == "odysseybase") then
    (
        local filename
        filename = nx_lowercase( g_exportPath + (nx_CreateExportName g_ModelName) + ".dwk" )
        if g_ismax then (
           nx_push g_FileHandles g_strBuffer
           g_strBuffer = createFile filename
           if g_strBuffer == undefined then
               format "ERROR: File creatin failure for: %\r\n" filename
        )
        else format "<snoopstart file=%>%" filename g_delim to:g_strBuffer

        type = "dwk"
        format "# Exported from KOTORmax % at %%" gblVersion localtime g_delim to:g_strBuffer
        format "# DWKMESH  ASCII%" g_delim to:g_strBuffer
    )
	
	--select node

    -- act on the node type
    case of
    (
        (node_type == "base" and type == "mdl"):
        (
        	format "node dummy %%" node.name g_delim to:g_strBuffer
			do_dummy node
            format "endnode%" g_delim to:g_strBuffer
        )

        (node_type == "dummy"): -- for either pwk, dwk or mdl
        (
        	format "node % %%" node_type node.name g_delim to:g_strBuffer
            do_dummy node
            format "endnode%" g_delim to:g_strBuffer
        )

        (node_type == "light" and type == "mdl"):
        (
        	format "node % %%" node_type node.name g_delim to:g_strBuffer
            do_dummy node
            do_light node
            format "endnode%" g_delim to:g_strBuffer
        )

        (node_type == "emitter" and type == "mdl"):
        (
        	format "node % %%" node_type node.name g_delim to:g_strBuffer
            do_dummy node
            do_emitter node
            format "endnode%" g_delim to:g_strBuffer
        )

        (node_type == "trimesh"): -- for either pwk, dwk or mdl
        (
        	format "node % %%" node_type node.name g_delim to:g_strBuffer
            do_dummy node
            do_trimesh node
            format "endnode%" g_delim to:g_strBuffer
        )

        (node_type == "skin" and type == "mdl"):
        (
        	format "node % %%" node_type node.name g_delim to:g_strBuffer
            do_dummy node
            do_trimesh node
            do_skin node
            format "endnode%" g_delim to:g_strBuffer
        )

        (node_type == "danglymesh" and type == "mdl"):
        (
        	format "node % %%" node_type node.name g_delim to:g_strBuffer
            do_dummy node
            do_trimesh node
            do_dangly node
            format "endnode%" g_delim to:g_strBuffer
        )

        (node_type == "aabb" and type == "mdl"):
        (
        	format "node % %%" node_type node.name g_delim to:g_strBuffer
            do_dummy node
            do_trimesh node
            do_aabb node
            format "endnode%" g_delim to:g_strBuffer
			if g_exportwok != 0 then exportWok node
        )

        (node_type == "lightsaber" and type == "mdl"):
        (
        	format "node % %%" node_type node.name g_delim to:g_strBuffer
            do_dummy node
            do_trimesh node
            format "endnode%" g_delim to:g_strBuffer
        )
    )

    -- save names that we will append into the .mdl
    if(type == "pwk" or type == "dwk") then append sExtraNames node.name

    -- After all this printing make sure we do a buffer flush
    nx_FlushBuffer()

	-- skip the children if this is a base, but don't skip if it's the root node!
	if node_type == "base" and not root then return false

    -- same thing if object is a door hook, stop processing now
    if matchPattern node.name pattern:"door_*" and node.name.count < 8 and node.parent != undefined and iskindof node.parent odysseybase then return false

    -- PROCESS CHILDREN
	for child in node.children do
	(
		unfreeze child
    	-- NB: we have a special way of ignoring nodes through a naming
    	-- convention (per Bioware scripts - good idea).
    	-- Must be in training material!!
		if (not (matchpattern child.name pattern:"ignore_*")) do
		(
            Node_Geometry child type:type
		)
	)

	-- We need to close off the file processing for pwk & dwk dummy children.
	if (node_type == "pwk_root" or node_type == "dwk_root") then
    (
        if g_ismax then (
            flush g_strBuffer
            close g_strBuffer
            g_strBuffer = nx_pop g_FileHandles
        )
        else format "</snoopstart>%" g_delim to:g_strBuffer
    )

    nx_FlushBuffer()

    if DEBUG then format "#Node_Geometry: End%" g_delim to:g_strBuffer
)


--------------------------------------------------------------------------------
-- Broad mdl types
--------------------------------------------------------------------------------

fn ExportOdysseyGeometry node =
(
    if DEBUG then format "#ExportOdysseyGeometry%" g_delim to:g_strBuffer

    format "\n%" g_delim to:g_strBuffer
	format "# GEOM ASCII%" g_delim to:g_strBuffer
	format "beginmodelgeom %%" node.name g_delim to:g_strBuffer

	--write lyt position if appropriate
	if (node.uselyt != 0) then(
        in coordsys world
        (
            local objPos = at time 0 node.position;
            objPos *= 0.01  -- scale the model down by 100 to make it in meters
            format "%layoutposition % % %%" strIndent1 objPos.x objPos.y objPos.z g_delim to:g_strBuffer
        )
    )

    -- DO MODEL GEOM
    sExtraNames = #() --clear name array
	--setCommandPanelTaskMode mode:#modify
    Node_Geometry node root:true

    --write out extra names
    for sName in sExtraNames do format "name %%" sName g_delim to:g_strBuffer      -- Writes out pwk/dwk related node names that we are removing from the mdl
    for sName in node.extranames do format "name %%" sName g_delim to:g_strBuffer  -- Writes out any names that were present in the mdl on import

    --end model geom
	format "endmodelgeom %%" node.name g_delim to:g_strBuffer

	nx_FlushBuffer()

    if DEBUG then format "#ExportOdysseyGeometry:: End%" g_delim to:g_strBuffer
)


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---   Animation export routines
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--
-- DynBuildList
-- by Joco
--
-- Build the key lists for a controller object
--
global gblDynBuildList_Node

fn DynBuildKeyList node firstframe lastframe datatype keyname mdlname:"" nodetype:"" =
(
    -- node: the node of the obj
    -- firstframe: first frame of the animation
    -- lastframe: last frame of the animation
    -- datatype: type of data to be used for export
    -- keyname: name of the data member of the object to be accessed
    -- mdlname: optional parameter for string to use in the resulting mdl

    local objController
    local bIsNegLight = false

    local strMdlName
    if mdlname != "" then
        strMdlName = mdlname
    else
        strMdlName = keyname

    -- only continue if node is valid
    if node == undefined then
    (
        if DEBUG then format "    #DEBUG: node not valid - exit DynBuildKeyList fn%" g_delim to:g_strBuffer
        return false
    )

    gblDynBuildList_Node = node
    -- using dynamic code obtain controller object
    try (
        objController = execute("gblDynBuildList_Node."+keyname+".controller")
    )
    catch (
        objController = undefined
    )

    if DEBUG then format "    #DEBUG: objController=% %" objController g_delim to:g_strBuffer

    local keycount = 0
    local bBezier = true;
    -- test to ensure that the controller is defined
    if objController != undefined then (
        -- determine if we have bezier
        if(classof objController != bezier_position and datatype == "position") then bBezier = false
        else if(classof objController != bezier_color and datatype == "color") then bBezier = false
        else if(classof objController != bezier_point3 and datatype == "point3") then bBezier = false
        else if(classof objController != bezier_float and datatype == "float") then bBezier = false
        else if(datatype == "orientation") then bBezier = false
        else (
            t = firstframe
            while(t < lastframe and bBezier) do (
                if ((getKeyIndex objController t) > 0) then(
                    try(
                        ourkey = getKey objController (getKeyIndex objController t)
                        if(ourkey.inTangentType == #linear and ourkey.outTangentType == #linear) then bBezier = false
                    )
                    catch(
                        bBezier = false
                    )
                )
                t += 1
            )
        )
        for t = firstframe to lastframe do
        (
            if (getKeyIndex objController t) > 0 then
            (
                -- we have an obj index > 0 so add a keylist entry
                if (keycount == 0) then
                (
                    format "        %" strMdlName to:g_strBuffer
                    if (bBezier) then format "bezier" to:g_strBuffer
                    format "key%" g_delim to:g_strBuffer
                )
                keycount += 1;
                at time t in coordsys parent
                (
                    objVal = execute("gblDynBuildList_Node."+keyname)
                )
                key_time = ((t-firstframe) as float) / (frameRate as float);
                local key_index = getKeyIndex objController t

                -- some special case unit conversion as needed
                case keyname of
                (
                    "radius":
                    (
                        -- convert radius into meters
                        objVal = objVal * 0.01
                    )
                )

                -- out put keys by data type
                local objIn
                local objOut
                case datatype of
                (
                    "float":
                    (
                        if(bBezier) then
                        (
                            objIn = objController.keys[key_index].inTangent
                            objOut = objController.keys[key_index].outTangent
                            format "            % % % % %" key_time objVal objIn objOut g_delim to:g_strBuffer
                        )
                        else format "            % % %" key_time objVal g_delim to:g_strBuffer
                    )
                    "integer":
                    (
                        if(bBezier) then
                        (
                            objIn = objController.keys[key_index].inTangent
                            objOut = objController.keys[key_index].outTangent
                            format "            % % % % %" key_time objVal objIn objOut g_delim to:g_strBuffer
                        )
                        else format "            % % %" key_time objVal g_delim to:g_strBuffer
                    )
                    "color":
                    (
                        -- deal with potential for animated negative light
                        try ( bIsNegLight = nx_itob(node.negativeLight) ) catch ( bIsNegLight = false )
						objVal = objVal as color
                        copyVal = [objVal.r, objVal.g, objVal.b] as color
                        if bIsNegLight then copyVal *= -1

                        if(bBezier) then
                        (
                            objIn = objController.keys[key_index].inTangent as color
                            objOut = objController.keys[key_index].outTangent as color
                            format "            % % % % % % % % % % %" key_time (copyVal.r / 255) (copyVal.g / 255) (copyVal.b / 255) objIn.r objIn.g objIn.b objOut.r objOut.g objOut.b g_delim to:g_strBuffer
                        )
                        else format "            % % % % %" key_time (copyVal.r / 255) (copyVal.g / 255) (copyVal.b / 255) g_delim to:g_strBuffer
                    )
                    "point3":
                    (
                        if(bBezier) then
                        (
                            objIn = objController.keys[key_index].inTangent
                            objOut = objController.keys[key_index].outTangent
                            format "            % % % % % % % % % % %" key_time objVal.x objVal.y objVal.z objIn.x objIn.y objIn.z objOut.x objOut.y objOut.z g_delim to:g_strBuffer
                        )
                        else format "            % % % % %" key_time objVal.x objVal.y objVal.z g_delim to:g_strBuffer
                    )
                    "point4":   format "            % % % % % %" key_time objVal.x objVal.y objVal.z objVal.r g_delim to:g_strBuffer
                    "position":
                    (
                        at time t in coordsys parent
                        (
                            objVal = execute("gblDynBuildList_Node."+keyname)
                            local objPos = objVal * 0.01

                            if(bBezier) then
                            (
                                objIn = objController.keys[key_index].inTangent
                                objOut = objController.keys[key_index].outTangent
                                format "            % % % % % % % % % %%" key_time objPos.x objPos.y objPos.z objIn.x objIn.y objIn.z objOut.x objOut.y objOut.z g_delim to:g_strBuffer
                            )
                            else format "            % % % %%" key_time objPos.x objPos.y objPos.z g_delim to:g_strBuffer
                        )
                    )
                    "orientation":
                    (
                        local rotVector
                        if nodetype == "emitter" then
                        (
                            -- to be consistent with the 180' rotation we apply to the orientation in normal export
                            -- apply it to the orientation animation data as well
                            objVal += quat -180 (point3 1 0 0);
                        )

                        --rotVector = point3 -objVal.x -objVal.y -objVal.z
                        -- bead-v modification: getting rid of the minus signs that are flipping our original values
                        rotVector = point3 objVal.x objVal.y objVal.z
                        -- end bead-v modification

                        --format "# raw  %" rotVector

                        --
                        -- Normalising a [0,0,0] vector results in [1,0,0].
                        -- The desired result is [0,0,0].

                        -- Due to some VERY strange behaviour with MAXScript the only way to get correct
                        -- behaviour on the below boolean test is to work with strings!
                        if (rotVector as string) != "[0,0,0]" then
                        (
                            rotVector = normalize (rotVector)
                        )
                        --local angle = -DegToRad(objVal.angle)
                        -- bead-v modification: getting rid of the minus signs that are flipping our original values
                        local angle = DegToRad(objVal.angle)
                        -- end bead-v modification
                        format "            % % % % %%" key_time rotVector.x rotVector.y rotVector.z angle g_delim to:g_strBuffer
                    )
                    default:    format "#ERROR - keylist data type not defined in code. Contact the author for support. %"
                )
                if(mod keycount 10 == 0) then nx_FlushBuffer()
            )
        )
        if(keycount > 0) then format "        endlist%" g_delim to:g_strBuffer
        nx_FlushBuffer()
    )

    -- Just do a tidy up. Not really necessary.  :-)
    gblDynBuildList_Node = undefined
)


--
-- Exports out the various key lists for each animation.
-- Called by ExportAnimByNumber
--
fn ExportAnimKeys node firstframe lastframe root:false =
(
    -- From Wayland's original script with emitter/light enhancements by Joco

	-- if node name starts with "ignore_" we don't process it or any of it's children
	if (matchpattern node.name pattern:"ignore_*") then return false

    -- check node and all its descendants. If none of them have any keys in this interval, skip this tree completely.
    if not nx_isnodetreeanimated node firstframe lastframe then return false


    g_nodeprog += 1
    nx_progressUpdate()

    -- determine node type
    local node_type = nx_getnodetype node

    -- build the start of the animation node
    format "    node dummy %%" (node.name) g_delim to:g_strBuffer --to:g_strBuffer
    if (node.parent != undefined) then
        format "        parent %%" (node.parent.name) g_delim to:g_strBuffer --to:g_strBuffer
    else
        format "        parent NULL%" g_delim to:g_strBuffer --to:g_strBuffer

    /*
    We need to determine if there are any keys on the node to be exported
    before continuing. This is to prevent a memory leak situation that
    exists in the v1.62 (and perhaps before) of the game.
    */
    local to_export = true	-- set base premise TO export the node

	-- only supress skinmesh nodes at this point - not happy that this is correct.
	-- Is this just a toolset issue?
    if node_type == "skin" then (
	    to_export = false
    )

    if to_export then
    (
	    --
	    -- build position keylist
	    --
	    if DEBUG then format "        #DEBUG: Build position list%" g_delim to:g_strBuffer
	    DynBuildKeyList node firstframe lastframe "position" "position"

	    --
	    -- build orientation keylist
	    --
	    if DEBUG then format "        #DEBUG: Build orientation list%" g_delim to:g_strBuffer
	    DynBuildKeyList node firstframe lastframe "orientation" "rotation" mdlname:"orientation" nodetype:node_type

        if node.modifiers["OdysseyTrimesh"] != undefined and (node_type == "trimesh" or node_type == "danglymesh" or node_type == "skin" or node_type == "aabb" or node_type == "lightsaber") then
        (
            ----------------------------------------------------------------
            -- Joco 31-Mar-04: Modifer properties                         --
            ----------------------------------------------------------------
            --
            -- build scale from trimesh modifier
            --
            if DEBUG then format "        #DEBUG: Build scale list%" g_delim to:g_strBuffer
            DynBuildKeyList (node.modifiers["OdysseyTrimesh"]) firstframe lastframe "float" "scale"

            --
            -- build alpha from trimesh modifier
            --
            if DEBUG then format "        #DEBUG: Build alpha list%" g_delim to:g_strBuffer
            DynBuildKeyList (node.modifiers["OdysseyTrimesh"]) firstframe lastframe "float" "alpha"

            --
            -- build selfillumcolor from trimesh modifier
            --
            if DEBUG then format "        #DEBUG: Build selfillumcolor list%" g_delim to:g_strBuffer
            DynBuildKeyList (node.modifiers["OdysseyTrimesh"]) firstframe lastframe "color" "selfillumcolor"
        )

        if node_type == "emitter" then
        (
            ----------------------------------------------------------------
            -- Joco 14-Aug-03: Emitter export code                        --
            --                                                            --
            -- NB: controllers on the custom addtributes only seem to be  --
            --     created when a key frame has been set. Otherwise an    --
            --     attempt to access the undefined controller returns     --
            --     a script error.                                        --
            ----------------------------------------------------------------
        /*
            --
            -- build alpha keylist
            --
            if DEBUG then format "        #DEBUG: Build alpha list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "alpha"
        */

            --
            -- build alphaStart keylist
            --
            if DEBUG then format "        #DEBUG: Build alphaStart list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "alphaStart"

            --
            -- build alphaMid keylist
            --
            if DEBUG then format "        #DEBUG: Build alphaMid list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "alphaMid"

            --
            -- build alphaEnd keylist
            --
            if DEBUG then format "        #DEBUG: Build alphaEnd list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "alphaEnd"

            --
            -- build percentStart keylist
            --
            if DEBUG then format "        #DEBUG: Build percentStart list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "percentStart"

            --
            -- build percentMid keylist
            --
            if DEBUG then format "        #DEBUG: Build percentMid list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "percentMid"

            --
            -- build percentEnd keylist
            --
            if DEBUG then format "        #DEBUG: Build percentEnd list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "percentEnd"

            --
            -- build birthrate keylist
            --
            if DEBUG then format "        #DEBUG: Build birthrate list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "birthrate"

            --
            -- build m_fRandomBirthRate keylist
            --
            if DEBUG then format "        #DEBUG: Build m_fRandomBirthRate list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "m_fRandomBirthRate"

            --
            -- build bounce_co keylist
            --
            if DEBUG then format "        #DEBUG: Build bounce_co list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "bounce_co"

            --
            -- build colorStart keylist
            --
            if DEBUG then format "        #DEBUG: Build colorStart list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "color" "colorStart"

            --
            -- build colorMid keylist
            --
            if DEBUG then format "        #DEBUG: Build colorMid list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "color" "colorMid"

            --
            -- build colorEnd keylist
            --
            if DEBUG then format "        #DEBUG: Build colorEnd list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "color" "colorEnd"

            --
            -- build combinetime keylist
            --
            if DEBUG then format "        #DEBUG: Build combinetime list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "combinetime"

            --
            -- build drag keylist
            --
            if DEBUG then format "        #DEBUG: Build drag list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "drag"

            --
            -- build fps keylist
            --
            if DEBUG then format "        #DEBUG: Build fps list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "integer" "fps"

            --
            -- build frameStart keylist
            --
            if DEBUG then format "        #DEBUG: Build frameStart list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "integer" "frameStart"

            --
            -- build frameEnd keylist
            --
            if DEBUG then format "        #DEBUG: Build frameEnd list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "integer" "frameEnd"

            --
            -- build grav keylist
            --
            if DEBUG then format "        #DEBUG: Build grav list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "grav"

            --
            -- build lifeExp keylist
            --
            if DEBUG then format "        #DEBUG: Build lifeExp list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "lifeExp"

            --
            -- build lightningDelay keylist
            --
            if DEBUG then format "        #DEBUG: Build lightningDelay list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "lightningDelay"

            --
            -- build lightningRadius keylist
            --
            if DEBUG then format "        #DEBUG: Build lightningRadius list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "lightningRadius"

            --
            -- build lightningScale keylist
            --
            if DEBUG then format "        #DEBUG: Build lightningScale list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "lightningScale"

            --
            -- build lightningSubDiv keylist
            --
            if DEBUG then format "        #DEBUG: Build lightningSubDiv list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "lightningSubDiv"

            --
            -- build lightningzigzag keylist
            --
            if DEBUG then format "        #DEBUG: Build lightningzigzag list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "lightningzigzag"

            --
            -- build blurlength keylist
            --
            if DEBUG then format "        #DEBUG: Build blurlength list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "blurlength"

            --
            -- build sizeStart_y keylist
            --
            if DEBUG then format "        #DEBUG: Build sizeStart_y list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "sizeStart_y"

            --
            -- build sizeMid_y keylist
            --
            if DEBUG then format "        #DEBUG: Build sizeMid_y list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "sizeMid_y"

            --
            -- build sizeEnd_y keylist
            --
            if DEBUG then format "        #DEBUG: Build sizeEnd_y list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "sizeEnd_y"

            --
            -- build mass keylist
            --
            if DEBUG then format "        #DEBUG: Build mass list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "mass"

            --
            -- build p2p_bezier2 keylist
            --
            if DEBUG then format "        #DEBUG: Build p2p_bezier2 list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "p2p_bezier2"

            --
            -- build p2p_bezier3 keylist
            --
            if DEBUG then format "        #DEBUG: Build p2p_bezier3 list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "p2p_bezier3"

            --
            -- build particleRot keylist
            --
            if DEBUG then format "        #DEBUG: Build particleRot list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "particleRot"

            --
            -- build randvel keylist
            --
            if DEBUG then format "        #DEBUG: Build randvel list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "randvel"

            --
            -- build sizeStart keylist
            --
            if DEBUG then format "        #DEBUG: Build sizeStart list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "sizeStart"

            --
            -- build sizeMid keylist
            --
            if DEBUG then format "        #DEBUG: Build sizeMid list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "sizeMid"

            --
            -- build sizeEnd keylist
            --
            if DEBUG then format "        #DEBUG: Build sizeEnd list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "sizeEnd"

            --
            -- build spread keylist
            --
            if DEBUG then format "        #DEBUG: Build spread list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "spread"

            --
            -- build velocity keylist
            --
            if DEBUG then format "        #DEBUG: Build velocity list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "velocity"

            --
            -- build xsize keylist
            --
            if DEBUG then format "        #DEBUG: Build xsize list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "xsize"

            --
            -- build ysize keylist
            --
            if DEBUG then format "        #DEBUG: Build ysize list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "ysize"

            --
            -- build threshold keylist
            --
            if DEBUG then format "        #DEBUG: Build threshold list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "threshold"

            --
            -- build targetsize keylist
            --
            if DEBUG then format "        #DEBUG: Build targetsize list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "targetsize"

            --
            -- build numcontrolpts keylist
            --
            if DEBUG then format "        #DEBUG: Build numcontrolpts list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "numcontrolpts"

            --
            -- build controlptradius keylist
            --
            if DEBUG then format "        #DEBUG: Build controlptradius list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "controlptradius"

            --
            -- build controlptdelay keylist
            --
            if DEBUG then format "        #DEBUG: Build controlptdelay list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "controlptdelay"

            --
            -- build tangentlength keylist
            --
            if DEBUG then format "        #DEBUG: Build tangentlength list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "tangentlength"

            --
            -- build tangentspread keylist
            --
            if DEBUG then format "        #DEBUG: Build tangentspread list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "tangentspread"

            --
            -- build detonate keylist
            --
            if DEBUG then format "        #DEBUG: Build detonate list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "detonate"

        /*
            --
            -- build replace keylist
            --
            if DEBUG then format "        #DEBUG: Build replace list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "replace"
        */
            -----------------------------
            -- END Emitter export code --
            -----------------------------
        )

        if node_type == "light" then
        (
            ----------------------------------------------------------------
            -- Joco 19-Aug-03: Light export code                          --
            --                                                            --
            -- NB: controllers on the custom addtributes only seem to be  --
            --     created when a key frame has been set. Otherwise an    --
            --     attempt to access the undefined controller returns     --
            --     a script error.                                        --
            ----------------------------------------------------------------
            --
            -- build color keylist
            --
            if DEBUG then format "        #DEBUG: Build color list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "color" "rgb" mdlname:"color"

            --
            -- build radius keylist
            --
            if DEBUG then format "        #DEBUG: Build radius list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "radius"

            --
            -- build shadowradius keylist
            --
            if DEBUG then format "        #DEBUG: Build shadowradius list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "shadowradius"

            --
            -- build verticaldisplacement keylist
            --
            if DEBUG then format "        #DEBUG: Build verticaldisplacement list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "verticaldisplacement"

            --
            -- build multiplier keylist
            --
            if DEBUG then format "        #DEBUG: Build multiplier list%" g_delim to:g_strBuffer
            DynBuildKeyList node firstframe lastframe "float" "multiplier"

            -----------------------------
            -- END Light export code   --
            -----------------------------
        )
	)

    format "    endnode%" g_delim to:g_strBuffer

    nx_FlushBuffer()

	-- skip the children if this is a base, but don't skip if it's the root node!
	if node_type == "base" and not root then return false

    -- same thing if object is a door hook, stop processing now
    if matchPattern node.name pattern:"door_*" and node.name.count < 8 and node.parent != undefined and iskindof node.parent odysseybase then return false

    for c in node.children do
    (
        local sChildString = ExportAnimKeys c firstframe lastframe
    )
)

fn ExportAnimEvents node firstframe lastframe =
(
    -- From Wayland's original script
    -- Find the events that have the same frame number as 'firstframe'
    local event_data
    local event_name
    local event_frame
    local event_time
    for str_eventdata in node.events do
    (
        event_data = filterString str_eventdata " "
        event_name = event_data[1]
        event_frame = (event_data[2] as integer)
        if ( (event_frame >= firstframe) and (event_frame <= lastframe) ) then
        (
            event_time = ((event_frame - firstframe) as float) / (frameRate as float)
            format "  event % %%" event_time event_name g_delim to:g_strBuffer
            nx_FlushBuffer()
        )
    )
)

--
-- Starts the Animation Export
--
fn ExportOdysseyAnimations node =
(
	-- From Wayland's original script
	-- Modified by Joco to suit MDL Tool structure
	if (node == undefined) then return false

	local anim_data
	local name
	local firstframe
	local lastframe
	local transtime
	local anim_length
	local will_export
	local anim_root

	animIndex = 0
	-- Cycle through the animations and export each one in the array
	for str_animdata in node.animations do
	(
		animIndex += 1
		g_animprog = animIndex
		g_nodeprog = 0
		nx_progressUpdate()
		-- parse out the animation data
		anim_data =   filterString str_animdata " "
		name = anim_data[1]
		firstframe = (anim_data[2] as integer)
		lastframe = (anim_data[3] as integer)
		transtime = (anim_data[4] as float)

		-- deal with any backwards compatability issues where this flag
		-- might not be present. If not there is assumed to == 1
		if anim_data[5] == undefined then will_export = true
		else will_export = (nx_itob (anim_data[5] as integer))

		anim_length = ((lastframe - firstframe) as float) / (frameRate as float)
		if anim_data.count > 5 then anim_root = anim_data[6]
		else anim_root = node.name

		if will_export then
		(
		   format "%" g_delim to:g_strBuffer
		   format "\n%" g_delim to:g_strBuffer
		   format "# ANIM ASCII%" g_delim to:g_strBuffer
		   format "newanim % %%" name node.name g_delim to:g_strBuffer
		   format "  length %%" anim_length g_delim to:g_strBuffer
		   format "  transtime %%" transtime g_delim to:g_strBuffer
		   format "  animroot %%" anim_root g_delim to:g_strBuffer
		   ExportAnimEvents node firstframe lastframe
		   ExportAnimKeys node firstframe lastframe root:true
		   format "doneanim % %%" name node.name g_delim to:g_strBuffer
		   format "%" g_delim to:g_strBuffer
		)
		nx_FlushBuffer()
	)
)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---   Exporting Starting Point
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
fn ExportOdysseyModel node anim:true showprogress:true =
(
    -- Determine what type of node we are dealing with and set the
    -- export routines down the appropriate path.
    -- We can parse the tree for:
    -- a. WalkMesh - got rid of this for kotormax
    -- b. Tile - got rid of this for kotormax
    -- c. Standard Geometry
    -- d. Animations
	
	showprogress = false

    -- Perform some basic sanity checking before we start trying to
    -- make a model file.
    -- 1. only do this work if we have an odysseybase
    if (nx_strclassof node) != "odysseybase" then return 0
    -- 2. so we have an odysseybase, but does it have any children?
    if not (nx_basehascontent node) then return 0

    if showprogress then progressStart "Exporting MDL"
    g_nodestotal = (getNumDescendants node)
    g_exptotal = g_nodestotal * (node.animations.count + 1)
    g_animprog = 0
    g_nodeprog = 0
	g_showprogress = showprogress

    -- make sure we are exporting starting at frame 0
    local currentFrame = sliderTime
    sliderTime = 0

    if SPEEDT then nx_startStopWatch txt:"ExportOdysseyModel"

    -- set the global name for the model. Used for pwk/dwk etc processing
    g_ModelName = node.name

    -- START WRITING
	format "# Exported from KOTORmax % at %%" gblVersion localtime g_delim to:g_strBuffer
	format "# MODEL ASCII%" g_delim to:g_strBuffer

	if maxfilename != "" then (
		format "#local file: %%" (maxfilepath + maxfilename) g_delim to:g_strBuffer
		format "filedependancy %%" maxfilename g_delim to:g_strBuffer
 	)

	format "newmodel %%" node.name g_delim to:g_strBuffer

	-- Output the SuperModel of this model:
	local sm = "NULL"
	if( node.setsupermodel != #undefined and \
	    (filterstring node.setsupermodel " ").count > 0 ) \
	then
		sm = (filterstring node.setsupermodel " ")[1]

	format "setsupermodel % %%" node.name sm g_delim to:g_strBuffer
	format "classification %%" node.classification g_delim to:g_strBuffer
    format "setanimationscale %%" node.setanimationscale g_delim to:g_strBuffer

	nx_FlushBuffer()

    -- export geometry
	if DEBUG then format "#ExportOdysseyModel: process geometry%" g_delim to:g_strBuffer
    ExportOdysseyGeometry node

	-- export animations
	if DEBUG then format "#ExportOdysseyModel: process animations%" g_delim to:g_strBuffer
	if anim then
    	ExportOdysseyAnimations node

    -- close the model syntax
	if DEBUG then format "#ExportOdysseyModel: End%" g_delim to:g_strBuffer
    format "donemodel %%" node.name g_delim to:g_strBuffer

	nx_FlushBuffer force:true

	-- restore slider time
	sliderTime = currentFrame

	-- do a general clean up as we eat some memory in these scripts
	gc()

	if showprogress then progressEnd()

    if SPEEDT then nx_stopStopWatch txt:"ExportOdysseyModel"
)

fn nx_exportmodelsilent node filename doanims =
(
	nx_FlushBuffer()

	if g_ismax then (
	   nx_push g_FileHandles g_strBuffer
	   g_strBuffer = createFile filename
	   if g_strBuffer == undefined then
		   format "ERROR: File creation failure for: %\r\n" filename
	)
	else format "<snoopstart file=%>%" filename g_delim to:g_strBuffer

	ExportOdysseyModel node anim:doanims showprogress:true

	if g_ismax then (
		flush g_strBuffer
		close g_strBuffer
		g_strBuffer = nx_pop g_FileHandles
	)
	else format "</snoopstart>%" g_delim to:g_strBuffer

	-- copy the tga files to export dir. If converting to dds then put in a tga dir inside export dir
	if node.copy_tga == 1 then
		nx_getTextures node node

	-- perform the tga to dds conversion
	if node.tga2dds == 1 then
	(
		-- process dds
		local cmd = g_kotormaxPath + "tga2dds\\processtextures.exe "
		cmd += g_exportPath + "\\tga "
		cmd += g_exportPath
		DOSCommand cmd
	)

	nx_FlushBuffer()
)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
---   Export Layout File
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
fn ExportOdysseyLayout pFile Rooms Tracks Obstacles Doorhooks withvis:true withmodels:false doanims:true showprogress:true =
(
	local basestotal = Rooms.count + Tracks.count + Obstacles.count + Doorhooks.count
	local progress = 0

    if showprogress and not withmodels then progressStart "Exporting LYT"

    -- START WRITING
	if DEBUG then format "#ExportOdysseyLayout: Begin%" g_delim to:g_strBuffer
	format "#Exported from KOTORmax % at %%" gblVersion localtime g_delim to:g_strBuffer
	format "#%" g_delim to:g_strBuffer
	format "#MAXLAYOUT ASCII%" g_delim to:g_strBuffer

	if maxfilename == "" then (
		format "#local file: Unknown%" g_delim to:g_strBuffer
		format "filedependancy Unknown%" g_delim to:g_strBuffer
	)
	else (
		format "#local file: %%" (maxfilepath + maxfilename) g_delim to:g_strBuffer
		format "filedependancy %%" maxfilename g_delim to:g_strBuffer
 	)

	format "beginlayout%" g_delim to:g_strBuffer

	-- rooms
	format "%roomcount %%" strIndent1 Rooms.count g_delim to:g_strBuffer
	for i = 1 to Rooms.count do
	(
		local room = (for base in Rooms where base.layoutnum == (i - 1) collect base)[1]
		-- we've already checked that all room numbers exist, if this is undefined now then god really must hate me
		local vPosition = (in coordsys world room.pos) * 0.01
		format "%% % % %%" strIndent2 room.name vPosition.x vPosition.y vPosition.z g_delim to:g_strBuffer

		if withmodels and nx_basehascontent room then
		(
			local filename = nx_lowercase( g_exportPath + (nx_CreateExportName room.name) + ".mdl" )

			nx_exportmodelsilent room filename doanims
		)

		nx_FlushBuffer()

		progress += 1
		if showprogress and not withmodels then progressUpdate ((progress * 100 ) / basestotal)
	)

	-- tracks
	format "%trackcount %%" strIndent1 Tracks.count g_delim to:g_strBuffer
	for track in Tracks do
	(
		local vPosition = (in coordsys world track.pos) * 0.01
		format "%% % % %%" strIndent2 track.name vPosition.x vPosition.y vPosition.z g_delim to:g_strBuffer

		if withmodels and nx_basehascontent track then
		(
			local filename = nx_lowercase( g_exportPath + (nx_CreateExportName track.name) + ".mdl" )

			nx_exportmodelsilent track filename doanims
		)

		nx_FlushBuffer()

		progress += 1
		if showprogress and not withmodels then progressUpdate ((progress * 100 ) / basestotal)
	)

	-- obstacles
	format "%obstaclecount %%" strIndent1 Obstacles.count g_delim to:g_strBuffer
	for obstacle in Obstacles do
	(
		local vPosition = (in coordsys world obstacle.pos) * 0.01
		format "%% % % %%" strIndent2 obstacle.name vPosition.x vPosition.y vPosition.z g_delim to:g_strBuffer

		if withmodels and nx_basehascontent obstacle then
		(
			local filename = nx_lowercase( g_exportPath + (nx_CreateExportName obstacle.name) + ".mdl" )

			nx_exportmodelsilent obstacle filename doanims
		)

		nx_FlushBuffer()

		progress += 1
		if showprogress and not withmodels then progressUpdate ((progress * 100 ) / basestotal)
	)

	-- doorhook
	format "%doorhookcount %%" strIndent1 Doorhooks.count g_delim to:g_strBuffer
	for doorhook in Doorhooks do
	(
		local vPosition = (in coordsys world at time 0 doorhook.pos) * 0.01
		local objRot = in coordsys world at time 0 doorhook.rotation as quat

		format "%% % 0 % % % % % % %%" strIndent2 doorhook.parent.name doorhook.name vPosition.x vPosition.y vPosition.z objRot.w objRot.x objRot.y objRot.z g_delim to:g_strBuffer

		progress += 1
		if showprogress and not withmodels then progressUpdate ((progress * 100 ) / basestotal)

		nx_FlushBuffer()
	)

    -- close the model syntax
	if DEBUG then format "#ExportOdysseyLayout: End%" g_delim to:g_strBuffer
    format "donelayout%" g_delim to:g_strBuffer

	nx_FlushBuffer()

	if showprogress and not withmodels then progressEnd()
	
	if withvis then
	(
		if showprogress then progressStart "Exporting VIS"
		local currentProgress = 0
		
		local visfilename = nx_lowercase( g_exportPath + pFile + ".vis" )

		if g_ismax then (
		   nx_push g_FileHandles g_strBuffer
		   g_strBuffer = createFile visfilename
		   if g_strBuffer == undefined then
			   format "ERROR: File creation failure for: %\r\n" visfilename
		)
		else format "<snoopstart file=%>%" visfilename g_delim to:g_strBuffer
		
		-- EXPORT CONTENTS
		
		-- get all rooms
		local Rooms = for room in $helpers where iskindof room odysseybase and room.layouttype == 2 collect room
		--print Rooms
		
		-- find max room number
		local LayoutNumArray = #()
		for room in Rooms where room.layoutnum > -1 do append LayoutNumArray room.layoutnum
		sort LayoutNumArray
		
		-- first append all the rooms that have a non -1 number
		for i in LayoutNumArray do
		(
			-- get all rooms with this layoutnum
			for room in Rooms where (room.layoutnum == i) do
			(
				-- first get rid of any invalid nodes that may be present in the room's data
				room.visrooms = for sName in room.visrooms where (getNodeByName sName) != undefined and iskindof (getNodeByName sName) odysseybase and (getNodeByName sName).layouttype == 2 collect sName
				
				format "% %%" (nx_lowercase room.name) room.visrooms.count g_delim to:g_strBuffer
				for sName in room.visrooms do
					format "%%%" strIndent1 (nx_lowercase sName) g_delim to:g_strBuffer
				
				nx_FlushBuffer()
				
				progress += 1
				if showprogress then progressUpdate ((progress * 100) / Rooms.count)
			)
		)
		
		-- now append those that do have a -1 num
		for room in Rooms where room.layoutnum == -1 do
		(
			-- first get rid of any invalid nodes that may be present in the room's data
			room.visrooms = for sName in room.visrooms where (getNodeByName sName) != undefined and iskindof (getNodeByName sName) odysseybase and (getNodeByName sName).layouttype == 2 collect sName
			
			format "% %%" (nx_lowercase room.name) room.visrooms.count g_delim to:g_strBuffer
			for sName in room.visrooms do
				format "%%%" strIndent1 (nx_lowercase sName) g_delim to:g_strBuffer
			
			nx_FlushBuffer()
			
			progress += 1
			if showprogress then progressUpdate ((progress * 100) / Rooms.count)
		)
		
		-- DONE EXPORTING CONTENTS

		if g_ismax then (
			flush g_strBuffer
			close g_strBuffer
			g_strBuffer = nx_pop g_FileHandles
		)
		else format "</snoopstart>%" g_delim to:g_strBuffer

		nx_FlushBuffer()
		
		if showprogress then progressEnd()
	)

	-- do a general clean up as we eat some memory in these scripts
	gc()
)

-------------------------------------------------
-- Mass export function
-------------------------------------------------
function ExportAll =
(
    -- Strictly speaking is based on Bioware's code but at the end of the
    -- day there are only so many ways to do this sensibly and they will all
    -- look the same.
	local export_path
	local bases
	local passSanityCheck = true
	local bSanityCheck
    local mdlextn

	local count=0;
	local models=""
	local totalBaseCount = 0
	local percentComplete = 0
	local continueExport=true


	-- before doing anything check for prescence of skins in scene
	for s in $objects do
	(
		if (s.modifiers["Skin"] != undefined) then
		(
			-- we have skins!!
			local msgStr = "At least one skin found in the scene.\rExporting skins using Export-All can crash KOTORmax.\r" + \
			" Please use the export buttons held on the models OdysseyBase.\rThank you. Export-All stopped."
			messageBox msgStr title:"Skins detected!" beep:true
			return 0
		)
	)


	--progressStart "Exporting all AuraBases..."

	bases = #()
	if selection.count == 0 then
	(
		for s in $helpers do
		(
    		if (nx_strclassof s) == "odysseybase" then
    		    append bases s
	    )
	) else
	(
		for s in selection do
		(
    		if (nx_strclassof s) == "odysseybase" then
    		    append bases s
	    )
	)

	unfreeze $geometry
	unfreeze bases

	clearListener()

	if not g_ismax then format "<snoopstart file=%batchexport.txt>%" "c:\\" g_delim to:g_strBuffer
	for obj in bases do
	(
    	-- Check to see if we should be continuing with the export
		if (continueExport == false) then
			continue
		if ((nx_strclassof obj) == "odysseybase") and (not (matchPattern obj.name pattern:"*	")) then
		(
    		-- Only do something if there are some children.
			if (obj.children.count > 0) then
			(
	 			max modify mode -- needed?
    			select obj
     			if (obj.export_path[obj.export_path.count] != "\\") then obj.export_path = obj.export_path + "\\"
    			g_exportPath = obj.export_path
        		mdlextn = "mdl"
        		if not g_ismax then format "<snoopstart file=%%.%>%" obj.export_path (nx_CreateExportName obj.name) mdlextn g_delim to:g_strBuffer
        		-- we can now do some sanity checks and record the results for review
        		if g_ismax then (
	           		g_strBuffer = createFile (nx_lowercase( g_kotormaxPath + "sanity/" + (nx_CreateExportName obj.name) + "_sanitycheck.txt") )
					if g_strBuffer == undefined then
					(
					   format "ERROR: File creatin failure for: %\r\n" (obj.export_path + (nx_CreateExportName obj.name) + "_sanitycheck.txt")
					)
        		) else (
	           		format "<snoopstart file=%%_sanitycheck.txt>%" (g_kotormaxPath + "sanity/") (nx_CreateExportName obj.name) g_delim to:g_strBuffer
        		)
        		bSanityCheck = SanityCheck obj
        		if g_ismax then
        		(
	           		flush g_strBuffer
	           		close g_strBuffer
        		)
				else (
	           		format "</snoopstart>%" g_delim to:g_strBuffer
        		)
				if (bSanityCheck != 0) then
				(
        			select obj
        			max modify mode
        			if g_ismax then (
						g_strBuffer = createFile (nx_lowercase( obj.export_path + obj.name + "." + mdlextn) )
						if g_strBuffer == undefined then
						(
						   format "ERROR: File creatin failure for: %\r\n" (obj.export_path + obj.name + "." + mdlextn)
						)
        			)
					ExportOdysseyModel obj
					if g_ismax then
					(
						flush g_strBuffer
						close g_strBuffer
	   				)
					models += (obj.name + " ")
					count = count +1
				)
				else
					passSanityCheck = false

				if not g_ismax then format "</snoopstart>%" g_delim to:g_strBuffer
			)
		)
		totalBaseCount += 1
		percentComplete = 100.0*(totalBaseCount as float)/(bases.count as float)
		--continueExport = progressUpdate percentComplete
	)
	--progressEnd()

	if (continueExport == false) then (
		if g_ismax then (
			format "Export cancelled: exported % models out of a possible %.%" count bases.count g_delim
		) else (
			format "Export cancelled: exported % models out of a possible %.%" count bases.count g_delim to:g_strBuffer
		)
	) else (
		if g_ismax then (
			format "Exported % models%" count g_delim
		) else (
			format "Exported % models%" count g_delim to:g_strBuffer
		)
	)
	if not g_ismax then
	(
	   	format "</snoopstart>%" g_delim to:g_strBuffer
	   	format "</snoopend>%" g_delim to:g_strBuffer
	)

	if (passSanityCheck == false) then (
		str = "SanityCheck failed for some models.  See the sanity check file for each model."
		messageBox str title:"Failed Sanity Check" beep:true
	)
	nx_FlushBuffer force:true
	-- do a general clean up as we eat some memory in these scripts
	gc()
)


-- listener command line command
-- Usage: massexport <file pattern> <target> {<anims:true>}
fn massexport pattern:undefined target:undefined anims:true =
(
	if (pattern == undefined) or (target==undefined) then
	(
		format "Usage:  massexport pattern:<filepath\pattern> target:<target dir> {<anims:true|false>}\r\n"
		format "example:  massexport pattern:\"d:\\\\mygmaxfiles\\\\*.gmax\" target:\"d:\\\\mymdls\"\r\n"
		format "Limitations: The total size the accumulated mdl data must be less than 3.6MB.\r\n"
		return 0
	)

	if not (nx_existDir target) then
	(
		messageBox "Target directory does not exist"
		return 0
	)

    -- get all the files to load from the pattern provided
    local modelBase
    local filesToLoad = getFiles pattern
    if target[target.count] != "\\" then
        target += "\\"
    -- reset scene
    resetMaxFile #noPrompt
	progressStart "Mass Export"
    clearListener()
	local doneCount = 0
    -- set the external control snoop bracket.
    if not g_ismax then format "<snoopstart file=%%>%" g_kotormaxPath "scratch\\exportcontrol.txt" g_delim to:g_strBuffer
    for file in filesToLoad do
    (
        -- load the file
        if (loadMaxFile file) then
        (
            for h in $helpers do
            (
                if (nx_strclassof h) == "odysseybase" then
                (
                    modelBase = h
                    exit
                )
            )
            -- export the file
            if isSceneRedrawDisabled() then enableSceneRedraw()
            modelBase.export_path = target
            select modelBase
            max modify mode
            if not g_ismax then
                format "<snoopstart file=%%.%>%" target (nx_CreateExportName( modelBase.name )) "mdl" g_delim to:g_strBuffer

            -- we can now do some sanity checks and record the results for review
            if g_ismax then (
                g_strBuffer = createFile ((g_kotormaxPath + "sanity/") + (nx_CreateExportName( modelBase.name )) + "_sanitycheck.txt")
                if g_strBuffer == undefined then
                    format "ERROR: File creatin failure for: %\r\n" (target + (nx_CreateExportName( modelBase.name )) + "_sanitycheck.txt")
            )
            format "<snoopstart file=%%_sanitycheck.txt>%" (g_kotormaxPath + "sanity/") (nx_CreateExportName( modelBase.name )) g_delim to:g_strBuffer
            bSanityCheck = SanityCheck modelBase
            if g_ismax then
            (
                flush g_strBuffer
                close g_strBuffer
            )
            else format "</snoopstart>%" g_delim to:g_strBuffer

            nx_FlushBuffer()
            if g_ismax then
            (
                g_strBuffer = createFile (target + (nx_CreateExportName( modelBase.name )) + ".mdl")
                if g_strBuffer == undefined then
                    format "ERROR: File creatin failure for: %\r\n" (target + nx_CreateExportName(modelBase.name) + ".mdl")
            )
            ExportOdysseyModel modelBase anim:anims
            if g_ismax then
            (
                flush g_strBuffer
                close g_strBuffer
            )
            else format "</snoopstart>%" g_delim to:g_strBuffer  -- closes model export
            nx_FlushBuffer()
            -- reset scene
            resetMaxFile #noPrompt
            doneCount += 1
            if not (progressUpdate ((doneCount*100)/filesToLoad.count)) then exit
	    )
   )
   if not g_ismax then
   (
	   format "</snoopstart>%" g_delim to:g_strBuffer  -- closes exportcontrol.txt
	   format "</snoopend>%" g_delim to:g_strBuffer
   )
	nx_FlushBuffer force:true
	progressEnd()
	if not g_ismax then messageBox "Processing Complete.\nDO NOT CLOSE until\nSnoop has finsihed exporting out the MDLs."
)
