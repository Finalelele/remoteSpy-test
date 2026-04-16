-- [[ KRALLDEN SPY v9.6.0 ]] --

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TextService = game:GetService("TextService")

-- Очистка старых версий
if playerGui:FindFirstChild("KralldenSpyUI") then 
    playerGui.KralldenSpyUI:Destroy() 
end
for _, gui in ipairs(game.CoreGui:GetChildren()) do
    pcall(function()
        if gui.Name == "KralldenSpyUI" then 
            gui:Destroy()
        elseif gui:FindFirstChild("KralldenSpyUI") then 
            gui.KralldenSpyUI:Destroy() 
        end
    end)
end

local targetParent = (gethui and gethui()) or (game:GetService("CoreGui"):FindFirstChild("RobloxGui")) or playerGui
local ScreenGui = Instance.new("ScreenGui", targetParent)
ScreenGui.Name = "KralldenSpyUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 10
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Anti-Hide
task.spawn(function()
    while task.wait(1) do 
        if ScreenGui and ScreenGui.Parent and not ScreenGui.Enabled then 
            ScreenGui.Enabled = true 
        end 
    end
end)

local Main = Instance.new("Frame", ScreenGui)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.Size = UDim2.new(0, 820, 0, 440)
Main.Position = UDim2.new(0.5, -410, 0.5, -220)
Main.Active = true
Main.Draggable = true
Main.BorderSizePixel = 0

local MainMemory, PathFilter, ManualBannedPaths = {}, {}, {}
local AntiSpamCooldowns, AntiSpamCounts = {}, {}
local selfMode, controlMode, antiSpam = true, true, true
local spyFS, spyFC, spyIS = true, false, false
local currentSelectionGUID, lastCount = nil, 0
local isMin = false
local sortArgs = false

local function generateGUID() 
    return tostring(tick()) .. "-" .. tostring(math.random(1, 100000)) 
end

local RedListScroll, Scroll, DetailsScroll, Details, ContentFrame

-- Функция фидбека
local activeFeedbacks = {}
local function feedback(button, tempText)
    if not button or activeFeedbacks[button] then return end
    activeFeedbacks[button] = true
    local oldText = button.Text
    button.Text = tempText
    task.delay(1, function() 
        if button and button.Parent then 
            button.Text = oldText
            activeFeedbacks[button] = nil 
        end 
    end)
end

local function refreshSelectionColors()
    if not Scroll or not RedListScroll then return end
    for _, v in pairs(Scroll:GetChildren()) do
        if v:IsA("TextButton") then
            local isSelected = (v:GetAttribute("GUID") == currentSelectionGUID)
            local isSelf = v:GetAttribute("IsSelf")
            if isSelected then
                v.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
            else
                if isSelf then
                    v.BackgroundColor3 = Color3.fromRGB(45, 90, 45)
                else
                    v.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
                end
            end
        end
    end
    for _, v in pairs(RedListScroll:GetChildren()) do
        if v:IsA("TextButton") then
            local isSelected = (v:GetAttribute("GUID") == currentSelectionGUID)
            if isSelected then
                v.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
            else
                v.BackgroundColor3 = Color3.fromRGB(100, 35, 35)
            end
        end
    end
end

-- ВНЕДРЕННАЯ ФУНКЦИЯ TEXTSERVICE
local function forceUpdateCanvas()
    if not Details or not DetailsScroll then return end

    local width = DetailsScroll.AbsoluteSize.X - 20 -- Учитываем Padding
    if width <= 0 then width = 428 end -- Фолбэк если UI еще не отрисован

    local text = (Details.Text ~= "" and Details.Text) or " "

    -- Математический расчет размера текста
    local size = TextService:GetTextSize(
        text,
        Details.TextSize,
        Details.Font,
        Vector2.new(width, math.huge)
    )

    local textHeight = size.Y + 10

    Details.Size = UDim2.new(1, 0, 0, textHeight)
    DetailsScroll.CanvasSize = UDim2.new(0, 0, 0, textHeight + 20)
    DetailsScroll.CanvasPosition = Vector2.new(0, 0)
end

local function updateDetailsView()
    if not currentSelectionGUID then 
        Details.Text = ""
        forceUpdateCanvas()
        return 
    end
    
    local found = false
    for _, d in ipairs(MainMemory) do
        if d.guid == currentSelectionGUID then 
            Details.Text = sortArgs and d.fullTextPretty or d.fullText
            found = true
            break 
        end
    end
    
    if not found then
        for _, data in pairs(ManualBannedPaths) do
            if data.guid == currentSelectionGUID then 
                Details.Text = sortArgs and (data.detailsPretty or data.details) or data.details
                found = true
                break 
            end
        end
    end
    
    forceUpdateCanvas()
end

local function updateRedListUI()
    if not RedListScroll then return end
    for _, v in pairs(RedListScroll:GetChildren()) do 
        if v:IsA("TextButton") then v:Destroy() end 
    end
    for path, data in pairs(ManualBannedPaths) do
        local b = Instance.new("TextButton", RedListScroll)
        b.Size = UDim2.new(1, -6, 0, 25)
        b:SetAttribute("GUID", data.guid)
        b:SetAttribute("Path", path)
        
        b.BackgroundColor3 = (currentSelectionGUID == data.guid) and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(100, 35, 35)
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.SourceSans
        b.TextSize = 11
        b.BorderSizePixel = 0
        
        local shortName = data.name or (path:match("[^%.%[%]]+$") or path):gsub('^%["', ''):gsub('"%]$', '')
        b.Text = " [X] " .. shortName
        
        b.MouseButton1Click:Connect(function() 
            currentSelectionGUID = data.guid
            updateDetailsView()
            refreshSelectionColors() 
        end)
    end
end

-- HEADER
local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
Header.ZIndex = 10
Header.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(0, 200, 1, 0)
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 15, 0, 0)
Title.Text = "KRALLDEN SPY v9.6.0"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.ZIndex = 11
Title.TextXAlignment = 0

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.new(0, 45, 0, 35)
MinBtn.Position = UDim2.new(1, -45, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 180)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.new(1, 1, 1)
MinBtn.TextSize = 22
MinBtn.ZIndex = 12
MinBtn.BorderSizePixel = 0

local function createHeaderBtn(text, offset, color, sizeX)
    local b = Instance.new("TextButton", Header)
    b.Size = UDim2.new(0, sizeX or 100, 0, 24)
    b.Position = UDim2.new(1, offset, 0.5, -12)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 11
    b.ZIndex = 11
    b.BorderSizePixel = 0
    return b
end

local ControlBtn = createHeaderBtn("CONTROL: ON", -150, Color3.fromRGB(0, 170, 190))
local SelfBtn = createHeaderBtn("SELF: ON", -235, Color3.fromRGB(45, 90, 45), 80)
local DelBtn = createHeaderBtn("DEL BTN", -310, Color3.fromRGB(200, 100, 0), 70)
local AntiSpamBtn = createHeaderBtn("ANTI-SPAM: ON", -420, Color3.fromRGB(180, 150, 40))
AntiSpamBtn.Visible = false
local BlockBtn = createHeaderBtn("BLOCK EVENT", -530, Color3.fromRGB(150, 50, 50))
BlockBtn.Visible = false

ContentFrame = Instance.new("Frame", Main)
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, 0, 1, -35)
ContentFrame.Position = UDim2.new(0, 0, 0, 35)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ClipsDescendants = true

Scroll = Instance.new("ScrollingFrame", ContentFrame)
Scroll.Position = UDim2.new(0, 8, 0, 8)
Scroll.Size = UDim2.new(0, 190, 1, -16)
Scroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.BorderSizePixel = 0
local scrollList = Instance.new("UIListLayout", Scroll)
scrollList.SortOrder = Enum.SortOrder.LayoutOrder

DetailsScroll = Instance.new("ScrollingFrame", ContentFrame)
DetailsScroll.Name = "DetailsScroll"
DetailsScroll.Position = UDim2.new(0, 205, 0, 8)
DetailsScroll.Size = UDim2.new(0, 448, 0, 255)
DetailsScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
DetailsScroll.BorderSizePixel = 0
DetailsScroll.ScrollBarThickness = 6
DetailsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local detailPad = Instance.new("UIPadding", DetailsScroll)
detailPad.PaddingLeft = UDim.new(0, 10)
detailPad.PaddingRight = UDim.new(0, 10)
detailPad.PaddingTop = UDim.new(0, 10)
detailPad.PaddingBottom = UDim.new(0, 10)

Details = Instance.new("TextBox", DetailsScroll)
Details.Name = "DetailsBox"
Details.Size = UDim2.new(1, 0, 0, 0)
Details.BackgroundTransparency = 1
Details.TextColor3 = Color3.new(1, 1, 1)
Details.TextWrapped = true
Details.MultiLine = true
Details.ClearTextOnFocus = false
Details.Font = Enum.Font.Code
Details.TextSize = 13
Details.TextXAlignment = Enum.TextXAlignment.Left
Details.TextYAlignment = Enum.TextYAlignment.Top
Details.Text = ""

local BanListTitle = Instance.new("TextLabel", ContentFrame)
BanListTitle.Size = UDim2.new(0, 150, 0, 20)
BanListTitle.Position = UDim2.new(0, 662, 0, 125)
BanListTitle.BackgroundTransparency = 1
BanListTitle.Text = "BAN LIST"
BanListTitle.TextColor3 = Color3.fromRGB(255, 100, 100)
BanListTitle.Font = Enum.Font.SourceSansBold
BanListTitle.TextSize = 14

RedListScroll = Instance.new("ScrollingFrame", ContentFrame)
RedListScroll.Position = UDim2.new(0, 662, 0, 145)
RedListScroll.Size = UDim2.new(0, 150, 0, 250)
RedListScroll.BackgroundColor3 = Color3.fromRGB(30, 15, 15)
RedListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
RedListScroll.BorderSizePixel = 0
Instance.new("UIListLayout", RedListScroll).SortOrder = Enum.SortOrder.LayoutOrder

-- PARSER & HOOKS
local function getSafePath(obj)
    local p = ""
    pcall(function() 
        local t = obj
        while t and t ~= game do 
            local n = tostring(t.Name)
            local safeName = (n:match("^%d") or n:match("[%s%W]")) and '["'..n..'"]' or n
            p = (p == "") and safeName or safeName .. (safeName:sub(1,1) == "[" and "" or ".") .. p
            t = t.Parent 
        end 
    end)
    return "game." .. p:gsub("%.%[", "[")
end

local function addLog(rem, args, isSelf, typeLabel)
    if (typeLabel == "FS" and not spyFS) or (typeLabel == "FC" and not spyFC) or (typeLabel == "IS" and not spyIS) then return end
    local eventPath = getSafePath(rem)
    if not isSelf and ManualBannedPaths[eventPath] then return end

    local function parseValue(v, d, pretty, indent)
        d = d or 0
        indent = indent or 0
        if d > 128 then return "..." end
        local t = type(v)
        if t == "string" then return '"' .. v .. '"'
        elseif t == "table" then
            local isArray, count = true, 0
            for k, val in pairs(v) do count = count + 1; if type(k) ~= "number" or k ~= count then isArray = false break end end
            local res = "{" .. (pretty and "\n" or "")
            local i = 0
            for k, val in pairs(v) do
                i = i + 1
                if i > 100 then res = res .. (pretty and string.rep("  ", indent + 1) or "") .. "..." break end
                local vStr = parseValue(val, d + 1, pretty, indent + 1)
                if isArray then
                    res = res .. (pretty and string.rep("  ", indent + 1) or "") .. vStr .. "," .. (pretty and "\n" or " ")
                else
                    local key = type(k) == "number" and "["..k.."]" or '["'..tostring(k)..'"]'
                    res = res .. (pretty and string.rep("  ", indent + 1) or "") .. key .. " = " .. vStr .. "," .. (pretty and "\n" or " ")
                end
            end
            res = res:gsub(",%s*$", "") .. (pretty and "\n" .. string.rep("  ", indent) or "") .. "}"
            return res == "{}" and "{}" or res
        elseif t == "userdata" then
            local tn = typeof(v)
            if tn == "CFrame" or tn == "Vector3" or tn == "Color3" then return tn .. ".new(" .. tostring(v) .. ")"
            elseif tn == "Instance" then return getSafePath(v) end
            return tostring(v)
        else return tostring(v) end
    end

    local argList, argListPretty = {}, {}
    for i, v in ipairs(args) do 
        table.insert(argList, parseValue(v, 0, false, 0))
        table.insert(argListPretty, parseValue(v, 0, true, 0))
    end
    
    local fArgs, fArgsP = table.concat(argList, ", "), table.concat(argListPretty, ",\n")
    
    for _, m in ipairs(MainMemory) do
        if m.path == eventPath and m.isSelf == isSelf then
            if (isSelf and (selfMode or m.argsStr == fArgs)) or (not isSelf and controlMode) or m.argsStr == fArgs then return end
        end
    end

    local method = (typeLabel == "IS" and "InvokeServer" or (typeLabel == "FC" and "FireClient" or "FireServer"))
    local log = string.format("Type: %s\nPath: %s\nArgs: %s\n\nScript:\n%s:%s(%s)", typeLabel, eventPath, fArgs == "" and "None" or fArgs, eventPath, method, fArgs)
    local logP = string.format("Type: %s\nPath: %s\nArgs: %s\n\nScript:\n%s:%s(%s)", typeLabel, eventPath, fArgsP == "" and "None" or "\n"..fArgsP, eventPath, method, fArgs)

    if not isSelf and not controlMode and antiSpam then
        if (tick() - (AntiSpamCooldowns[eventPath] or 0)) < 0.4 then
            AntiSpamCounts[eventPath] = (AntiSpamCounts[eventPath] or 0) + 1
            if AntiSpamCounts[eventPath] >= 4 then
                ManualBannedPaths[eventPath] = {guid = generateGUID(), name = tostring(rem.Name), details = "AUTO-SPAM BANNED\n"..log, detailsPretty = "AUTO-SPAM BANNED\n"..logP}
                local nM = {}
                for _, m in ipairs(MainMemory) do if not (m.path == eventPath and not m.isSelf) then table.insert(nM, m) end end
                MainMemory, lastCount, currentSelectionGUID = nM, -1, nil
                updateRedListUI() return 
            end
        else AntiSpamCounts[eventPath] = 0 end
        AntiSpamCooldowns[eventPath] = tick()
    end

    table.insert(MainMemory, 1, {guid = generateGUID(), name = tostring(rem.Name), type = typeLabel, isSelf = isSelf, fullText = log, fullTextPretty = logP, path = eventPath, argsStr = fArgs})
end

local mt = getrawmetatable(game)
local old = mt.__namecall
setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local m, s = getnamecallmethod():lower(), checkcaller()
    if m == "fireserver" then task.spawn(addLog, self, {...}, s, "FS")
    elseif m == "fireclient" then task.spawn(addLog, self, {...}, s, "FC")
    elseif m == "invokeserver" then task.spawn(addLog, self, {...}, s, "IS") end
    return old(self, ...)
end)
setreadonly(mt, true)

-- BTNS LOGIC
ControlBtn.MouseButton1Click:Connect(function() 
    controlMode = not controlMode
    ControlBtn.Text = "CONTROL: "..(controlMode and "ON" or "OFF")
    ControlBtn.BackgroundColor3 = controlMode and Color3.fromRGB(0, 170, 190) or Color3.fromRGB(80, 80, 85)
    AntiSpamBtn.Visible, BlockBtn.Visible, lastCount = not controlMode, not controlMode, -1 
end)

DelBtn.MouseButton1Click:Connect(function()
    if not currentSelectionGUID then return end
    local target, foundInBan = nil, false
    for path, data in pairs(ManualBannedPaths) do
        if data.guid == currentSelectionGUID then target, foundInBan = {path = path}, true break end
    end
    if not foundInBan then
        local nM = {}
        for _, m in ipairs(MainMemory) do if m.guid == currentSelectionGUID then target = m else table.insert(nM, m) end end
        MainMemory = nM
    else ManualBannedPaths[target.path] = nil updateRedListUI() end
    if target then feedback(DelBtn, foundInBan and "UNBANNED" or "DELETED") lastCount, currentSelectionGUID, Details.Text = -1, nil, "" forceUpdateCanvas() end
end)

BlockBtn.MouseButton1Click:Connect(function()
    if not currentSelectionGUID then return end
    for i, d in ipairs(MainMemory) do
        if d.guid == currentSelectionGUID and not d.isSelf then
            ManualBannedPaths[d.path] = {guid = d.guid, name = d.name, details = "MANUAL BANNED:\n"..d.fullText, detailsPretty = "MANUAL BANNED:\n"..d.fullTextPretty}
            local nM = {}
            for _, m in ipairs(MainMemory) do if not (m.path == d.path and not m.isSelf) then table.insert(nM, m) end end
            MainMemory, lastCount, currentSelectionGUID, Details.Text = nM, -1, nil, "Banned."
            updateRedListUI() forceUpdateCanvas() feedback(BlockBtn, "BANNED") break
        end
    end
end)

MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    local curX, curY = Main.AbsolutePosition.X + Main.AbsoluteSize.X, Main.AbsolutePosition.Y
    if isMin then
        ContentFrame.Visible, ControlBtn.Visible, SelfBtn.Visible, AntiSpamBtn.Visible, BlockBtn.Visible, DelBtn.Visible = false, false, false, false, false, false
        Main:TweenSizeAndPosition(UDim2.new(0, 250, 0, 35), UDim2.new(0, curX - 250, 0, curY), "Out", "Quad", 0.15, true)
        MinBtn.Text = "+"
    else
        Main:TweenSizeAndPosition(UDim2.new(0, 820, 0, 440), UDim2.new(0, curX - 820, 0, curY), "Out", "Quad", 0.15, true, function()
            ContentFrame.Visible, ControlBtn.Visible, SelfBtn.Visible, DelBtn.Visible = true, true, true, true
            if not controlMode then AntiSpamBtn.Visible, BlockBtn.Visible = true, true end
        end)
        MinBtn.Text, lastCount = "_", -1
    end
end)

-- RENDER
task.spawn(function()
    while task.wait(0.5) do
        if not ContentFrame.Visible or #MainMemory == lastCount then continue end
        lastCount = #MainMemory
        for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        
        local sorted = {}
        for _, d in ipairs(MainMemory) do if d.isSelf then table.insert(sorted, d) end end
        for _, d in ipairs(MainMemory) do if not d.isSelf then table.insert(sorted, d) end end
        
        for i, d in ipairs(sorted) do
            local b = Instance.new("TextButton", Scroll)
            b.Size, b.LayoutOrder, b.BorderSizePixel = UDim2.new(1, -6, 0, 30), i, 0
            b.Text = string.format("[%s]%s %s", d.type, (d.isSelf and " [S]" or ""), d.name)
            b:SetAttribute("GUID", d.guid)
            b:SetAttribute("IsSelf", d.isSelf)
            b.BackgroundColor3 = (currentSelectionGUID == d.guid) and Color3.fromRGB(100, 50, 200) or (d.isSelf and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45))
            b.TextColor3, b.Font, b.TextSize = Color3.new(1,1,1), Enum.Font.SourceSans, 12
            b.MouseButton1Click:Connect(function() currentSelectionGUID = d.guid updateDetailsView() refreshSelectionColors() end)
        end
    end
end)

-- BOTTOM BTNS
local function createBotBtn(text, pos, size, color)
    local b = Instance.new("TextButton", ContentFrame)
    b.Size, b.Position, b.BackgroundColor3, b.BorderSizePixel = size or UDim2.new(0, 220, 0, 58), pos, color, 0
    b.Text, b.TextColor3, b.Font, b.TextSize = text, Color3.new(1,1,1), Enum.Font.SourceSansBold, 14
    return b
end

createBotBtn("COPY ARGS", UDim2.new(0, 205, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(45, 90, 45)).MouseButton1Click:Connect(function() 
    local a = Details.Text:match("Args:?%s*(.-)\n\nScript")
    if a then setclipboard(a) feedback(activeFeedbacks, "COPIED!") end
end)

local SortBtn = createBotBtn("SORT: OFF", UDim2.new(0, 317, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(80, 80, 85))
SortBtn.MouseButton1Click:Connect(function()
    sortArgs = not sortArgs
    SortBtn.Text, SortBtn.BackgroundColor3 = "SORT: "..(sortArgs and "ON" or "OFF"), sortArgs and Color3.fromRGB(0, 170, 190) or Color3.fromRGB(80, 80, 85)
    updateDetailsView()
end)

createBotBtn("COPY SCRIPT", UDim2.new(0, 205, 0.83, 0), nil, Color3.fromRGB(60, 60, 120)).MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)")
    if s then setclipboard(s) feedback(activeFeedbacks, "COPIED!") end
end)

createBotBtn("CLEAR LOG", UDim2.new(0, 432, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(80, 80, 85)).MouseButton1Click:Connect(function()
    local nM = {}
    for _, m in ipairs(MainMemory) do if m.isSelf then table.insert(nM, m) end end
    MainMemory, lastCount = nM, -1 feedback(activeFeedbacks, "CLEARED")
end)

createBotBtn("CLEAR SELF", UDim2.new(0, 544, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(100, 80, 60)).MouseButton1Click:Connect(function()
    local nM = {}
    for _, m in ipairs(MainMemory) do if not m.isSelf then table.insert(nM, m) end end
    MainMemory, lastCount = nM, -1 feedback(activeFeedbacks, "CLEARED")
end)

createBotBtn("EXECUTE", UDim2.new(0, 432, 0.83, 0), nil, Color3.fromRGB(120, 60, 60)).MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)") or Details.Text
    if s and s ~= "" then 
        local f, err = loadstring(s)
        if f then task.spawn(f) feedback(activeFeedbacks, "DONE!") else feedback(activeFeedbacks, "ERROR!") end 
    end 
end)

SelfBtn.MouseButton1Click:Connect(function() 
    selfMode = not selfMode
    SelfBtn.Text, SelfBtn.BackgroundColor3, lastCount = "SELF: "..(selfMode and "ON" or "OFF"), selfMode and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(150, 50, 50), -1
end)

AntiSpamBtn.MouseButton1Click:Connect(function() 
    antiSpam = not antiSpam
    AntiSpamBtn.Text, AntiSpamBtn.BackgroundColor3 = "ANTI-SPAM: "..(antiSpam and "ON" or "OFF"), antiSpam and Color3.fromRGB(180, 150, 40) or Color3.fromRGB(80, 80, 85)
end)

createTypeBtn("FS SPY: ON", UDim2.new(0, 662, 0, 8), spyFS, Color3.fromRGB(130, 70, 220), "FS")
createTypeBtn("FC SPY: OFF", UDim2.new(0, 662, 0, 48), spyFC, Color3.fromRGB(50, 150, 255), "FC")
createTypeBtn("IS SPY: OFF", UDim2.new(0, 662, 0, 88), spyIS, Color3.fromRGB(255, 150, 50), "IS")
