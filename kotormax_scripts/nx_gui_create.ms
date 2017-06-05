


rollout nx_util0 "Create" width:162
(
    -- ui
    group "Odyssey Objects"
    (
        checkbutton btn_odydummy "Dummy" width:68 height:17 align:#left across:2
        checkbutton btn_odybase "Base" width:68 height:17 align:#right
        checkbutton btn_odylight "Light" width:68 height:17 align:#left across:2 offset:[0, -2]
        checkbutton btn_odyemitter "Emitter" width:68 height:17 align:#right offset:[0, -2]
        checkbutton btn_odylightsaber "Lightsaber" width:68 height:17 align:#left across:2 offset:[0, -2]
        label lbl_placeholder "" width:68 height:17 align:#right offset:[0, -2]
    )
    group "Odyssey Modifiers"
    (
        button btn_odytrimesh "Trimesh" width:68 height:17 align:#left across:2
        button btn_odyflex "Flex" width:68 height:17 align:#right
        button btn_odywalkmesh "Walkmesh" width:68 height:17 align:#left across:2 offset:[0, -2]
        button btn_skin "Skin" width:68 height:17 align:#right offset:[0, -2]
    )

    -- tools
    tool create_odydummy
    (
        on mousePoint clickNo do
        (
            if clickNo > 1 then
            (
                local oObject = createOdysseyDummy gridPoint
                select oObject
                if not ctrlKey then
                (
                    stopTool create_odydummy
                    #stop
                )
            )
        )
    )
    tool create_odylight
    (
        on mousePoint clickNo do
        (
            if clickNo > 1 then
            (
                local oObject = createOdysseyLight gridPoint
                select oObject
                if not ctrlKey then
                (
                    stopTool create_odylight
                    #stop
                )
            )
        )
    )
    tool create_odyemitter
    (
        on mousePoint clickNo do
        (
            if clickNo > 1 then
            (
                local oObject = createOdysseyEmitter gridPoint
                select oObject
                if not ctrlKey then
                (
                    stopTool create_odyemitter
                    #stop
                )
            )
        )
    )
    tool create_odylightsaber
    (
        on mousePoint clickNo do
        (
            if clickNo > 1 then
            (
                local oObject = createOdysseyLightsaber gridPoint
                select oObject
                if not ctrlKey then
                (
                    stopTool create_odylightsaber
                    #stop
                )
            )
        )
    )
    tool create_odybase
    (
        on mousePoint clickNo do
        (
            if clickNo > 1 then
            (
                local oObject = createOdysseyBase gridPoint
				if not ctrlkey then
				(
					stopTool create_odybase
					select oObject
					createDialog basewiz modal:true
					#stop -- stop odysseybase creation in all cases, because we have a dialog
				)
            )
        )
    )

    -- actions
	on btn_odydummy changed state do
	(
        if state then
        (
            startTool create_odydummy
            btn_odydummy.state = false
        )
        else stopTool create_odydummy
	)
	on btn_odylight changed state do
	(
        if state then
        (
            startTool create_odylight
            btn_odylight.state = false
        )
        else stopTool create_odylight
	)
	on btn_odyemitter changed state do
	(
        if state then
        (
            startTool create_odyemitter
            btn_odyemitter.state = false
        )
        else stopTool create_odyemitter
	)
	on btn_odylightsaber changed state do
	(
        if state then
        (
            startTool create_odylightsaber
            btn_odylightsaber.state = false
        )
        else stopTool create_odylightsaber
	)
	on btn_odybase changed state do
	(
        if state then
        (
            startTool create_odybase
            btn_odybase.state = false
        )
        else stopTool create_odybase
	)
	on btn_odytrimesh pressed do
	(
        for node in selection do
        (
            local odyssey_mod = odysseytrimesh()
            try(
                if validModifier node odyssey_mod then addModifier node odyssey_mod
            ) catch()
        )
	)
	on btn_odywalkmesh pressed do
	(
        for node in selection do
        (
            local odyssey_mod = odysseywalkmesh()
            try(
                if validModifier node odyssey_mod then addModifier node odyssey_mod
            ) catch()
        )
	)
	on btn_odyflex pressed do
	(
        for node in selection do
        (
            local odyssey_mod = odysseyflex()
            try(
                if validModifier node odyssey_mod then addModifier node odyssey_mod
            ) catch()
        )
	)
	on btn_skin pressed do
	(
        for node in selection do
        (
            local skin_mod = skin()
            try(
                if validModifier node skin_mod and iskindof node editable_mesh then addModifier node skin_mod
            ) catch()
        )
	)

    on nx_util0 moved val do
    (
		if gNX_dock == 0 then
		(
			-- store the current location of the KOTORmax Speedbar
			nx_setinivalue #(#("init", "position", (val as string), (g_kotormaxPath + "kotormax.ini")))
			/*
			if g_ismax then (
				setINISetting (scriptsPath+"nxlocalprefs.ini") "position" "kotormax" (val as string)
			)
			*/
		)
    )
)
