-- CUSH FOLDER ITEMS
-- REAPER 7+

local ITEM_Y      = 0.0
local ITEM_HEIGHT = 1.0

local SELECT_CHILDREN = true

-- 0.45 = 45% of original brightness
-- smaller = darker
-- larger = brighter
local CHILD_DARKEN = 0.45

local TAG = "CUSH_FOLDER_ITEM"

local TIMER = 0.05

local r = reaper

local _, _, sectionID, cmdID =
    r.get_action_context()


------------------------------------------------------------
-- TOGGLE / START / STOP
------------------------------------------------------------

local RUNNING_KEY = "RUNNING"
local STOP_KEY    = "STOP"

local alreadyRunning =
    r.GetExtState(TAG, RUNNING_KEY) == "1"

if alreadyRunning then

    r.SetExtState(
        TAG,
        STOP_KEY,
        "1",
        false
    )

    if sectionID and cmdID then

        r.SetToggleCommandState(
            sectionID,
            cmdID,
            0
        )

        r.RefreshToolbar2(
            sectionID,
            cmdID
        )

    end

    return

end


r.SetExtState(
    TAG,
    RUNNING_KEY,
    "1",
    false
)

r.SetExtState(
    TAG,
    STOP_KEY,
    "0",
    false
)


if sectionID and cmdID then

    r.SetToggleCommandState(
        sectionID,
        cmdID,
        1
    )

    r.RefreshToolbar2(
        sectionID,
        cmdID
    )

end


------------------------------------------------------------
-- BASIC FUNCTIONS
------------------------------------------------------------

local function Pos(item)

    return r.GetMediaItemInfo_Value(
        item,
        "D_POSITION"
    )

end


local function Len(item)

    return r.GetMediaItemInfo_Value(
        item,
        "D_LENGTH"
    )

end


local function End(item)

    return Pos(item) + Len(item)

end


local function IsFolder(track)

    if not track then
        return false
    end

    return
        r.GetMediaTrackInfo_Value(
            track,
            "I_FOLDERDEPTH"
        ) > 0

end


------------------------------------------------------------
-- GET FOLDER CHILD TRACKS
------------------------------------------------------------

local function GetChildren(folder)

    local result = {}

    local folderIndex =
        math.floor(
            r.GetMediaTrackInfo_Value(
                folder,
                "IP_TRACKNUMBER"
            )
        ) - 1

    local depth = 0

    local i =
        folderIndex + 1

    local count =
        r.CountTracks(0)

    while i < count do

        local track =
            r.GetTrack(0, i)

        if not track then
            break
        end

        result[#result + 1] =
            track

        depth =
            depth +
            r.GetMediaTrackInfo_Value(
                track,
                "I_FOLDERDEPTH"
            )

        if depth < 0 then
            break
        end

        i = i + 1

    end

    return result

end


------------------------------------------------------------
-- CUSH ITEM TAG
------------------------------------------------------------

local function Mark(item)

    r.GetSetMediaItemInfo_String(
        item,
        "P_EXT:" .. TAG,
        "1",
        true
    )

end


local function IsFolderItem(item)

    if not item then
        return false
    end

    local ok, value =
        r.GetSetMediaItemInfo_String(
            item,
            "P_EXT:" .. TAG,
            "",
            false
        )

    return
        ok
        and
        value == "1"

end


------------------------------------------------------------
-- GET EXISTING CUSH FOLDER ITEMS
------------------------------------------------------------

local function GetFolderItems(folder)

    local result = {}

    local count =
        r.CountTrackMediaItems(folder)

    for i = 0, count - 1 do

        local item =
            r.GetTrackMediaItem(
                folder,
                i
            )

        if IsFolderItem(item) then

            result[#result + 1] =
                item

        end

    end

    table.sort(
        result,
        function(a, b)

            return Pos(a) < Pos(b)

        end
    )

    return result

end


------------------------------------------------------------
-- GET CHILD AUDIO RANGES
------------------------------------------------------------

local function GetChildRanges(folder)

    local ranges = {}

    local children =
        GetChildren(folder)

    for _, track in ipairs(children) do

        local count =
            r.CountTrackMediaItems(track)

        for i = 0, count - 1 do

            local item =
                r.GetTrackMediaItem(
                    track,
                    i
                )

            if item and not IsFolderItem(item) then

                local s =
                    Pos(item)

                local e =
                    End(item)

                if e > s then

                    ranges[#ranges + 1] =
                    {
                        s,
                        e
                    }

                end

            end

        end

    end


    table.sort(
        ranges,
        function(a, b)

            if a[1] == b[1] then
                return a[2] < b[2]
            end

            return a[1] < b[1]

        end
    )


    local merged = {}

    for _, range in ipairs(ranges) do

        local last =
            merged[#merged]

        if not last then

            merged[#merged + 1] =
            {
                range[1],
                range[2]
            }

        elseif range[1] < last[2] then

            if range[2] > last[2] then
                last[2] =
                    range[2]
            end

        else

            merged[#merged + 1] =
            {
                range[1],
                range[2]
            }

        end

    end

    return merged

end


------------------------------------------------------------
-- GET FOLDER COLOR
------------------------------------------------------------

local function GetColor(folder)

    local color =
        r.GetTrackColor(folder)

    if color and color ~= 0 then
        return color
    end


    for _, track in ipairs(
        GetChildren(folder)
    ) do

        color =
            r.GetTrackColor(track)

        if color and color ~= 0 then
            return color
        end

    end


    return 0

end


------------------------------------------------------------
-- DARKER CHILD COLOR
------------------------------------------------------------

local function GetChildColor(folder)

    local color =
        GetColor(folder)

    if not color or color == 0 then
        return 0
    end


    local red, green, blue =
        r.ColorFromNative(color)


    red =
        math.floor(
            red * CHILD_DARKEN
            + 0.5
        )

    green =
        math.floor(
            green * CHILD_DARKEN
            + 0.5
        )

    blue =
        math.floor(
            blue * CHILD_DARKEN
            + 0.5
        )


    return
        r.ColorToNative(
            red,
            green,
            blue
        )

end


------------------------------------------------------------
-- COLOR ALL CHILD AUDIO ITEMS
------------------------------------------------------------

local function UpdateChildItemColors(folder)

    local childColor =
        GetChildColor(folder)

    if childColor == 0 then
        return
    end


    local children =
        GetChildren(folder)


    for _, track in ipairs(children) do

        local count =
            r.CountTrackMediaItems(track)


        for i = 0, count - 1 do

            local item =
                r.GetTrackMediaItem(
                    track,
                    i
                )


            if item and not IsFolderItem(item) then

                r.SetMediaItemInfo_Value(
                    item,
                    "I_CUSTOMCOLOR",
                    childColor
                )

            end

        end

    end

end


------------------------------------------------------------
-- CREATE FOLDER ITEM
------------------------------------------------------------

local function CreateFolderItem(
    folder,
    startPos,
    endPos
)

    local item =
        r.AddMediaItemToTrack(
            folder
        )

    if not item then
        return nil
    end


    r.SetMediaItemInfo_Value(
        item,
        "D_POSITION",
        startPos
    )


    r.SetMediaItemInfo_Value(
        item,
        "D_LENGTH",
        math.max(
            0.000001,
            endPos - startPos
        )
    )


    r.SetMediaItemInfo_Value(
        item,
        "F_FREEMODE_Y",
        ITEM_Y
    )


    r.SetMediaItemInfo_Value(
        item,
        "F_FREEMODE_H",
        ITEM_HEIGHT
    )


    local color =
        GetColor(folder)


    if color ~= 0 then

        r.SetMediaItemInfo_Value(
            item,
            "I_CUSTOMCOLOR",
            color
        )

    end


    r.GetSetMediaItemInfo_String(
        item,
        "P_NOTES",
        "",
        true
    )


    Mark(item)


    r.SetMediaItemSelected(
        item,
        false
    )


    return item

end


------------------------------------------------------------
-- BUILD FOLDER
------------------------------------------------------------

local function BuildFolder(folder)

    local existing =
        GetFolderItems(folder)


    if #existing > 0 then
        return
    end


    local ranges =
        GetChildRanges(folder)


    for _, range in ipairs(ranges) do

        CreateFolderItem(
            folder,
            range[1],
            range[2]
        )

    end

end


------------------------------------------------------------
-- BUILD ALL
------------------------------------------------------------

local function BuildAll()

    r.PreventUIRefresh(1)


    for i = 0,
        r.CountTracks(0) - 1
    do

        local track =
            r.GetTrack(0, i)


        if IsFolder(track) then

            BuildFolder(track)

            UpdateChildItemColors(track)

        end

    end


    r.PreventUIRefresh(-1)

    r.UpdateArrange()

end


------------------------------------------------------------
-- CHECK ITEM INSIDE FOLDER ITEM
------------------------------------------------------------

local function Inside(
    parent,
    child
)

    local ps =
        Pos(parent)

    local pe =
        End(parent)

    local cs =
        Pos(child)

    local ce =
        End(child)

    local eps =
        0.000001


    return
        cs >= ps - eps
        and
        ce <= pe + eps

end


------------------------------------------------------------
-- SELECT CHILDREN
------------------------------------------------------------

local function SelectChildren(
    folder,
    folderItem
)

    local children =
        GetChildren(folder)


    local ps =
        Pos(folderItem)

    local pe =
        End(folderItem)


    for _, track in ipairs(children) do

        local count =
            r.CountTrackMediaItems(
                track
            )


        for i = 0, count - 1 do

            local item =
                r.GetTrackMediaItem(
                    track,
                    i
                )


            if item then

                local cs =
                    Pos(item)

                local ce =
                    End(item)


                if
                    cs >= ps - 0.000001
                    and
                    ce <= pe + 0.000001
                then

                    r.SetMediaItemSelected(
                        item,
                        true
                    )

                end

            end

        end

    end

end


------------------------------------------------------------
-- PROCESS SELECTION
------------------------------------------------------------

local lastSelectedFolderItem = nil


local function ProcessSelection()

    if not SELECT_CHILDREN then
        return
    end


    local selectedFolderItem = nil
    local selectedFolder = nil


    for i = 0,
        r.CountTracks(0) - 1
    do

        local folder =
            r.GetTrack(0, i)


        if IsFolder(folder) then

            local items =
                GetFolderItems(folder)


            for _, item in ipairs(items) do

                if r.IsMediaItemSelected(item) then

                    selectedFolderItem =
                        item

                    selectedFolder =
                        folder

                    break

                end

            end

        end


        if selectedFolderItem then
            break
        end

    end


    if
        selectedFolderItem
        and
        selectedFolderItem
        ~= lastSelectedFolderItem
    then

        lastSelectedFolderItem =
            selectedFolderItem


        SelectChildren(
            selectedFolder,
            selectedFolderItem
        )


        r.UpdateArrange()

        return

    end


    if not selectedFolderItem then

        lastSelectedFolderItem =
            nil

    end

end


------------------------------------------------------------
-- UPDATE FOLDER VISUAL
------------------------------------------------------------

local function UpdateFolderVisual(
    folder
)

    local folderItems =
        GetFolderItems(folder)


    local ranges =
        GetChildRanges(folder)


    if #folderItems == 0 then

        for _, range in ipairs(ranges) do

            CreateFolderItem(
                folder,
                range[1],
                range[2]
            )

        end


        UpdateChildItemColors(folder)

        return

    end


    local selectedTop = false


    for _, item in ipairs(folderItems) do

        if r.IsMediaItemSelected(item) then

            selectedTop = true

            break

        end

    end


    if
        not selectedTop
        and
        #folderItems ~= #ranges
    then

        for i = #folderItems, 1, -1 do

            r.DeleteTrackMediaItem(
                folder,
                folderItems[i]
            )

        end


        for _, range in ipairs(ranges) do

            CreateFolderItem(
                folder,
                range[1],
                range[2]
            )

        end


        UpdateChildItemColors(folder)

        return

    end


    if selectedTop then

        UpdateChildItemColors(folder)

        return

    end


    if #folderItems == #ranges then

        for i = 1, #ranges do

            local item =
                folderItems[i]


            local s =
                ranges[i][1]

            local e =
                ranges[i][2]


            if
                math.abs(
                    Pos(item) - s
                ) > 0.000001
            then

                r.SetMediaItemInfo_Value(
                    item,
                    "D_POSITION",
                    s
                )

            end


            local wantedLength =
                e - s


            if
                math.abs(
                    Len(item)
                    -
                    wantedLength
                ) > 0.000001
            then

                r.SetMediaItemInfo_Value(
                    item,
                    "D_LENGTH",
                    math.max(
                        0.000001,
                        wantedLength
                    )
                )

            end


            local color =
                GetColor(folder)


            if color ~= 0 then

                r.SetMediaItemInfo_Value(
                    item,
                    "I_CUSTOMCOLOR",
                    color
                )

            end

        end

    end


    UpdateChildItemColors(folder)

end


------------------------------------------------------------
-- SYNC ALL
------------------------------------------------------------

local function SyncAll()

    for i = 0,
        r.CountTracks(0) - 1
    do

        local folder =
            r.GetTrack(0, i)


        if IsFolder(folder) then

            UpdateFolderVisual(
                folder
            )

        end

    end

end


------------------------------------------------------------
-- MAIN LOOP
------------------------------------------------------------

local lastState =
    r.GetProjectStateChangeCount(0)


local function Main()

    --------------------------------------------------------
    -- CHECK FOR STOP REQUEST
    --------------------------------------------------------

    if r.GetExtState(
        TAG,
        STOP_KEY
    ) == "1" then

        r.SetExtState(
            TAG,
            STOP_KEY,
            "0",
            false
        )

        return

    end


    ProcessSelection()


    local state =
        r.GetProjectStateChangeCount(0)


    if state ~= lastState then

        lastState =
            state


        r.PreventUIRefresh(1)


        SyncAll()


        r.PreventUIRefresh(-1)


        r.UpdateArrange()

    end


    r.defer(Main)

end


------------------------------------------------------------
-- EXIT
------------------------------------------------------------

local function Exit()

    r.PreventUIRefresh(1)


    for i =
        r.CountTracks(0) - 1,
        0,
        -1
    do

        local track =
            r.GetTrack(0, i)


        if IsFolder(track) then

            local items =
                GetFolderItems(track)


            for j = #items, 1, -1 do

                r.DeleteTrackMediaItem(
                    track,
                    items[j]
                )

            end

        end

    end


    r.PreventUIRefresh(-1)


    r.SetExtState(
        TAG,
        RUNNING_KEY,
        "0",
        false
    )


    r.SetExtState(
        TAG,
        STOP_KEY,
        "0",
        false
    )


    if sectionID and cmdID then

        r.SetToggleCommandState(
            sectionID,
            cmdID,
            0
        )


        r.RefreshToolbar2(
            sectionID,
            cmdID
        )

    end


    r.UpdateArrange()

end


------------------------------------------------------------
-- START
------------------------------------------------------------

BuildAll()


lastState =
    r.GetProjectStateChangeCount(0)


r.atexit(Exit)


r.defer(Main)
