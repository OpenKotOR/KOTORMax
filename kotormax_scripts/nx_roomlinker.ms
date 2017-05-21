/*-----------------------------------------------------------------------------\

    Animation Editor

	KOTORmax
	by bead-v
	
	Derived from:
    NWmax
    by Joco (jameswalker@clear.net.nz)

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

global nx_roomlinker_flag
rollout nx_roomlinker "Room Link Editor"
(
    local nodesel = undefined

	-- gui
	multilistbox list_links pos:[5,5] height:10 width:140
	button btn_removetrans "Remove Link(s)" pos:[5,145] width:140 toolTip:"Removes selected link(s)."

	spinner spn_transition "Room:" range:[-1,100,-1] pos:[175,10] width:60 type:#integer
	button btn_addtrans "Apply" pos:[239,7] width:50 toolTip:"Adds room link to the currently selected edge(s)."
	listbox lst_rooms pos:[150,30] height:10 width:140 selection:0

	-- actions
	
	-- this function will make sure we are in the right node, its mesh baseobject and edge subobject
	-- if all checks out, then it returns the baseobject, otherwise it returns undefined
	fn GetValidBaseObject =
	(
		-- get selected node, and make sure it's a mesh, otherwise return
		if nodesel == undefined then return undefined
		if modpanel.getcurrentobject() == undefined then
		(
			messagebox "Error: Modify Panel not open or nothing is selected."
			return undefined
		)
		if nodesel != selection[1] then
		(
			messagebox "Error: The selected node is not the node for which the data is open."
			return undefined
		)
		if not iskindof nodesel.baseobject editable_mesh and not iskindof nodesel.baseobject trimesh then
		(
			messagebox "Error: Node base object is not an Editable Mesh."
			return undefined
		)
		if modpanel.getcurrentobject() != nodesel.baseobject then
		(
			messagebox "Error: A modifier is selected instead of the Editable Mesh base object."
			return undefined
		)
		if subobjectlevel != 2 then
		(
			messagebox "Error: Not in Edge Editing Mode."
			return undefined
		)
		return nodesel
	)

	on lst_rooms doubleclicked sel do
	(
		lst_rooms.selection = sel
		local tokens = filterString lst_rooms.selected " "
		local room = getnodebyname tokens[tokens.count]
		if room != undefined and iskindof room odysseybase then spn_transition.value = room.layoutnum
		else messageBox "An error occurred: the base \"" + lst_rooms.selected + "\" cannot be found."
	)
	
	fn GetLinks =
	(
		-- get selected node, and make sure it's a mesh, otherwise return
		local mesh = GetValidBaseObject()
		if mesh == undefined then return false
		
		local temp = #()
		
		for f = 1 to (meshop.getNumFaces mesh) do
		(
			local ClrVertInds = getVCFace mesh f
			for i = 1 to 3 do
			(
				local VertColor = getVertColor mesh ClrVertInds[i]
				if(VertColor.b == 0 and VertColor.r == 0 and VertColor.g >= 100) then
				(
					append temp ("Edge " + ((f - 1)* 3 + i) as string + " to Room " + ((VertColor.g as Integer) - 100) as string)
				)
			)
		)
		list_links.items = temp
	)
	fn GetSelectedLinkEdges =
	(
		local returnArray = #()
		
		for i = 1 to list_links.items.count do
		(
			if findItem list_links.selection i == 0 then continue
			
			local s = list_links.items[i]
			if s[1] != "#" then
			(
				local tok = filterString s " "
				append returnArray (tok[2] as integer - 1)
			)
		)
		
		return returnArray
	)
	on btn_addtrans pressed do
	(
		-- get selected node, and make sure it's a mesh, otherwise return
		local mesh = GetValidBaseObject()
		if mesh == undefined then return false
		
		local selEdges = #()
		for curEdge in (getEdgeSelection mesh) do
		(
			append selEdges curEdge
		)
		
		local room = spn_transition.value
		local cColor = point3 0.0 ((100.0+room)/255.0) 0.0
		local nNewIndex = 0
		if(room == -1) then nNewIndex = 1
		else(
			for i = 1 to (meshop.getNumMapVerts mesh 0) do
			(
				local ColorVert = meshop.getMapVert mesh 0 i
				--local ColorVert = color (p3.x * 255.0) (p3.y * 255.0) (p3.z * 255.0)
				--format "Comparing colors: % and % \n" (ColorVert as color) cColor
				if((ColorVert as color) == cColor) then
				(
					nNewIndex = i
					exit
				)
			)
			if(nNewIndex == 0) then
			(
				nNewIndex = (meshop.getNumMapVerts mesh 0) + 1
				meshop.setNumMapVerts mesh 0 nNewIndex keep:true
				meshop.setMapVert mesh 0 nNewIndex (cColor)
			)
		)
		for i in selEdges do
		(
			local nFace = (i - 1) / 3
			local nEdge = mod (i - 1) 3
			local FaceInds = meshop.getMapFace mesh 0 (nFace+1)
			FaceInds[nEdge+1] = nNewIndex
			meshop.setMapFace mesh 0 (nFace+1) FaceInds
		)
		GetLinks()
		redrawViews()
	)
	
	on list_links selected ind do
	(
		-- get selected node, and make sure it's a mesh, otherwise return
		local mesh = GetValidBaseObject()
		if mesh == undefined then return false
		   
/*
		local bSelected = false
		if findItem list_links.selection ind > 0 then bSelected = true
		
		local nEdge = 0
		local s = list_links.items[ind]
		if s[1] != "#" then
		(
			local tok = filterString s " "
			nEdge = tok[2] as integer
		)
		
		if nEdge > 0 then
		(
			--local SelectedEdgesArray = for i = 1 to mesh.selectedEdges.count collect mesh.selectedEdges[i].index
			local SelectedEdgesArray = for i = 1 to list_links.items.count where findItem list_links.selection i and (list_links.items[i])[1] != "#" collect ((filterString (list_links.items[i]) " ")[2] as integer)
				mesh.selectedEdges = SelectedEdgesArray
				redrawViews()
			
			if findItem SelectedEdgesArray nEdge > 0 and not bSelected then
			(
				deleteItem SelectedEdgesArray (findItem SelectedEdgesArray nEdge)
				mesh.selectedEdges = SelectedEdgesArray
				redrawViews()
			)
			else if findItem SelectedEdgesArray nEdge == 0 and bSelected then
			(
				append SelectedEdgesArray nEdge
				mesh.selectedEdges = SelectedEdgesArray
				redrawViews()
			)
		)     
*/
		local SelectedEdgesArray = for i = 1 to list_links.items.count where findItem list_links.selection i > 0 and (list_links.items[i])[1] != "#" collect ((filterString (list_links.items[i]) " ")[2] as integer)
		mesh.selectedEdges = SelectedEdgesArray
		redrawViews()                              
	)

	on btn_removetrans pressed do
	(
		-- get selected node, and make sure it's a mesh, otherwise return
		local mesh = GetValidBaseObject()
		if mesh == undefined then return false
		
		local nIndices = GetSelectedLinkEdges()
		for nIndex in nIndices do
		(
			local nFace = nIndex / 3
			local nEdge = mod nIndex 3
			local FaceInds = meshop.getMapFace mesh 0 (nFace+1)
			FaceInds[nEdge+1] = 1
			meshop.setMapFace mesh 0 (nFace+1) FaceInds
		)
		GetLinks()
		redrawViews()
	)
		
	on nx_roomlinker open do
	(
		if modpanel.getcurrentobject() == undefined then return false
		nodesel = selection[1]
		mesh = nodesel
		modpanel.setcurrentobject nodesel.baseobject
		subobjectlevel = 2
		
		-- setup the colors if needed
		if(not (meshop.GetMapSupport mesh 0)) then (
			meshop.setMapSupport mesh 0 true
		)
		if((meshop.getNumMapVerts mesh 0) == 0 or (meshop.getNumMapFaces mesh 0) == 0) then (
			meshop.setNumMapVerts mesh 0 1
			meshop.setMapVert mesh 0 1 [1, 1, 1]
			meshop.buildMapFaces mesh 0
			for i = 1 to (meshop.getMapFace mesh 0) do (
				meshop.setMapFace mesh 0 i [1, 1, 1]
			)
		)

		-- get links that are present on the mesh, if there are color faces and verts
		if((meshop.getNumMapVerts mesh 0) > 0 and (meshop.getNumMapFaces mesh 0) > 0) then GetLinks()
		
		-- get rooms with numbers if there are any and this is an aabb
		local SceneRooms = for obj in $helpers where iskindof obj odysseybase and obj.layouttype == 2 collect obj
		local RoomNames = #()
		for room in SceneRooms do
		(
			-- if the node name is unique and layout num isn't -1, append the name
			local SameNamedNodes = for obj in $objects where obj.name == room.name collect obj
			if SameNamedNodes.count == 1 and room.layoutnum > -1 then
				append RoomNames (room.layoutnum as string + "  " + room.name)
		)
		-- update listbox
		lst_rooms.items = RoomNames
			
    	nx_roomlinker_flag = true
	)

	on nx_roomlinker close do
	(
    	nx_roomlinker_flag = false
	)
)

if nx_roomlinker_flag != true then
(
    --format "firing roomlinker dialog!\n"
    createDialog nx_roomlinker width:295
)
