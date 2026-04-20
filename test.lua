-- [[ KRALLDEN SPY v9.7.7 FIXED & OPTIMIZED ]] --

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
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KralldenSpyUI"; ScreenGui.ResetOnSpawn = false; ScreenGui.DisplayOrder = 10; ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; ScreenGui.Parent = targetParent

-- Anti-Hide
task.spawn(function()
    while task.wait(1) do 
        if ScreenGui and ScreenGui.Parent and not ScreenGui.Enabled then 
            ScreenGui.Enabled = true 
        end 
    end
end)

local Main = Instance.new("Frame")
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); Main.Size = UDim2.new(0, 820, 0, 440)
Main.Position = UDim2.new(0.5, -410, 0.5, -220); Main.Active = true; Main.Draggable = true; Main.BorderSizePixel = 0; Main.Parent = ScreenGui

local MainMemory, PathFilter, ManualBannedPaths = {}, {}, {}
local AntiSpamCooldowns, AntiSpamCounts = {}, {}
local selfMode, controlMode, antiSpam = true, true, true
local spyFS, spyFC, spyIS = true, false, false
local sortEnabled, currentSelectionGUID, lastCount = false, nil, 0
local isMin = false

local function generateGUID() return tostring(tick()) .. "-" .. tostring(math.random(1, 100000)) end

local RedListScroll, Scroll, Details, ContentFrame, DetailsScroll

-- FeedBack
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

-- Canvas Scroll Fix
local function updateDetailsCanvas()
    if DetailsScroll and Details then
        task.defer(function()
            DetailsScroll.CanvasSize = UDim2.new(0, 0, 0, Details.TextBounds.Y + 40)
        end)
    end
end

local function refreshSelectionColors()
    if not Scroll or not RedListScroll then return end
    for _, v in pairs(Scroll:GetChildren()) do
        if v:IsA("TextButton") then
            local isSelected = (v:GetAttribute("GUID") == currentSelectionGUID)
            v.BackgroundColor3 = isSelected and Color3.fromRGB(100, 50, 200) or (v:GetAttribute("IsSelf") and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45))
        end
    end
    for _, v in pairs(RedListScroll:GetChildren()) do
        if v:IsA("TextButton") then
            v.BackgroundColor3 = (v:GetAttribute("GUID") == currentSelectionGUID) and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(100, 35, 35)
        end
    end
end

local function formatTableVisual(val, indent)
    indent = indent or 0
    local tab = string.rep("    ", indent)
    local t = typeof(val)
    if t == "table" then
        local res, isArray, count = "{\n", true, 0
        for k, v in pairs(val) do count = count + 1; if type(k) ~= "number" or k ~= count then isArray = false break end end
        for k, v in pairs(val) do
            local keyStr = isArray and "" or (type(k) == "string" and k .. " = " or "[" .. tostring(k) .. "] = ")
            res = res .. tab .. "    " .. keyStr .. formatTableVisual(v, indent + 1) .. ",\n"
        end
        return res .. tab .. "}"
    elseif t == "string" then return '"' .. val .. '"'
    elseif t == "Vector3" then return string.format("Vector3.new(%.3f, %.3f, %.3f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then return "CFrame.new(" .. tostring(val) .. ")"
    else return tostring(val) end
end

local function getSortedDetails(d)
    local prefix = d.prefix or ""
    if not sortEnabled then return prefix .. d.fullText end
    local displayArgs = formatTableVisual(d.rawArgs)
    local methodName = (d.type == "IS" and "InvokeServer" or (d.type == "FC" and "FireClient" or "FireServer"))
    return prefix .. string.format("Type: %s\n\nPath: %s\n\nArgs: %s\n\nScript:\n%s:%s(%s)", d.type, d.path, displayArgs, d.path, methodName, d.argsStr)
end

local function updateRedListUI()
    if not RedListScroll then return end
    for _, v in pairs(RedListScroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
    for path, data in pairs(ManualBannedPaths) do
        local b = Instance.new("TextButton")
        b.Size, b.BackgroundColor3 = UDim2.new(1, -6, 0, 25), (currentSelectionGUID == data.guid) and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(100, 35, 35)
        b.TextColor3, b.Font, b.TextSize, b.BorderSizePixel, b.ClipsDescendants = Color3.new(1,1,1), Enum.Font.SourceSansBold, 10, 0, true
        b:SetAttribute("GUID", data.guid); b:SetAttribute("Path", path)
        b.Text = " [X] " .. (path:match("[^%.%[%]]+$") or path); b.Parent = RedListScroll
        b.MouseButton1Click:Connect(function() 
            currentSelectionGUID = data.guid
            Details.Text = getSortedDetails(data) 
            updateDetailsCanvas()
            refreshSelectionColors()
        end)
    end
end

-- HEADER
local Header = Instance.new("Frame")
Header.Size, Header.BackgroundColor3, Header.ZIndex, Header.BorderSizePixel = UDim2.new(1, 0, 0, 35), Color3.fromRGB(25, 25, 30), 10, 0
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size, Title.BackgroundTransparency, Title.Position = UDim2.new(0, 200, 1, 0), 1, UDim2.new(0, 15, 0, 0)
Title.Text, Title.TextColor3, Title.Font, Title.TextSize, Title.ZIndex, Title.TextXAlignment = "KRALLDEN SPY v9.7.7", Color3.new(1, 1, 1), Enum.Font.SourceSansBold, 16, 11, 0
Title.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Size, MinBtn.Position, MinBtn.BackgroundColor3 = UDim2.new(0, 45, 0, 35), UDim2.new(1, -45, 0, 0), Color3.fromRGB(60, 60, 180)
MinBtn.Text, MinBtn.TextColor3, MinBtn.TextSize, MinBtn.ZIndex, MinBtn.BorderSizePixel = "_", Color3.new(1, 1, 1), 22, 12, 0
MinBtn.Parent = Header

local function createHeaderBtn(text, offset, color, sizeX)
    local b = Instance.new("TextButton")
    b.Size, b.Position, b.BackgroundColor3 = UDim2.new(0, sizeX or 100, 0, 24), UDim2.new(1, offset, 0.5, -12), color
    b.Text, b.TextColor3, b.Font, b.TextSize, b.ZIndex, b.BorderSizePixel = text, Color3.new(1,1,1), Enum.Font.SourceSansBold, 11, 11, 0
    b.Parent = Header
    return b
end

local ControlBtn = createHeaderBtn("CONTROL: ON", -150, Color3.fromRGB(0, 170, 190))
local SelfBtn = createHeaderBtn("SELF: ON", -235, Color3.fromRGB(45, 90, 45), 80)
local DelBtn = createHeaderBtn("DEL BTN", -310, Color3.fromRGB(200, 100, 0), 70)
local AntiSpamBtn = createHeaderBtn("ANTI-SPAM: ON", -420, Color3.fromRGB(180, 150, 40))
AntiSpamBtn.Visible = false
local BlockBtn = createHeaderBtn("BLOCK EVENT", -530, Color3.fromRGB(150, 50, 50))
BlockBtn.Visible = false

ContentFrame = Instance.new("Frame")
ContentFrame.Name, ContentFrame.Size, ContentFrame.Position, ContentFrame.BackgroundTransparency, ContentFrame.ClipsDescendants = "ContentFrame", UDim2.new(1, 0, 1, -35), UDim2.new(0, 0, 0, 35), 1, true
ContentFrame.Parent = Main

Scroll = Instance.new("ScrollingFrame")
Scroll.Position, Scroll.Size, Scroll.BackgroundColor3, Scroll.AutomaticCanvasSize, Scroll.BorderSizePixel, Scroll.ScrollBarThickness = UDim2.new(0, 8, 0, 8), UDim2.new(0, 190, 1, -16), Color3.fromRGB(20, 20, 25), 2, 0, 4
Scroll.Parent = ContentFrame
Instance.new("UIListLayout", Scroll).SortOrder = Enum.SortOrder.LayoutOrder

DetailsScroll = Instance.new("ScrollingFrame")
DetailsScroll.Position, DetailsScroll.Size, DetailsScroll.BackgroundColor3, DetailsScroll.BorderSizePixel, DetailsScroll.ScrollBarThickness, DetailsScroll.AutomaticCanvasSize = UDim2.new(0, 205, 0, 8), UDim2.new(0, 448, 0, 255), Color3.fromRGB(10, 10, 12), 0, 4, 2
DetailsScroll.Parent = ContentFrame

Details = Instance.new("TextBox")
Details.Size, Details.Position, Details.BackgroundTransparency = UDim2.new(1, -10, 0, 0), UDim2.new(0, 5, 0, 5), 1
Details.TextColor3, Details.MultiLine, Details.TextWrapped, Details.TextEditable, Details.Font, Details.TextSize = Color3.new(1, 1, 1), true, true, true, Enum.Font.Code, 12
Details.TextXAlignment, Details.TextYAlignment, Details.ClearTextOnFocus, Details.AutomaticSize = 0, 0, false, 2
Details.Parent = DetailsScroll
Details:GetPropertyChangedSignal("Text"):Connect(updateDetailsCanvas)

local BanListTitle = Instance.new("TextLabel")
BanListTitle.Size, BanListTitle.Position, BanListTitle.BackgroundTransparency = UDim2.new(0, 150, 0, 20), UDim2.new(0, 662, 0, 125), 1
BanListTitle.Text, BanListTitle.TextColor3, BanListTitle.Font, BanListTitle.TextSize = "BAN LIST", Color3.fromRGB(255, 100, 100), Enum.Font.SourceSansBold, 14
BanListTitle.Parent = ContentFrame

RedListScroll = Instance.new("ScrollingFrame")
RedListScroll.Position, RedListScroll.Size, RedListScroll.BackgroundColor3, RedListScroll.AutomaticCanvasSize, RedListScroll.BorderSizePixel, RedListScroll.ScrollBarThickness = UDim2.new(0, 662, 0, 145), UDim2.new(0, 150, 0, 250), Color3.fromRGB(30, 15, 15), 2, 0, 4
RedListScroll.Parent = ContentFrame
Instance.new("UIListLayout", RedListScroll).SortOrder = Enum.SortOrder.LayoutOrder

-- Path Logic
local function getSafePath(obj)
    local p = ""
    pcall(function() 
        local t = obj; while t and t ~= game do 
            local n = tostring(t.Name); local safeName = (n:match("^%d") or n:match("[%s%W]")) and '["'..n..'"]' or n
            if p == "" then p = safeName else p = (safeName:sub(1,1) == "[" and safeName .. "." .. p or safeName .. "." .. p) end
            t = t.Parent 
        end 
    end)
    return ("game." .. p):gsub("%.%[", "[") 
end

local function addLog(rem, args, isSelf, typeLabel)
    if (typeLabel == "FS" and not spyFS) or (typeLabel == "FC" and not spyFC) or (typeLabel == "IS" and not spyIS) then return end
    local eventPath = getSafePath(rem)
    if not isSelf and ManualBannedPaths[eventPath] then return end

    local function parseValue(v, d)
        d = d or 0; if d > 4 then return "..." end
        local t = type(v)
        if t == "string" then return '"' .. v .. '"'
        elseif t == "table" then
            local isArray, count = true, 0; for k, val in pairs(v) do count = count + 1; if type(k) ~= "number" or k ~= count then isArray = false break end end
            local res, i = "{", 0; for k, val in pairs(v) do i = i + 1; if i > 15 then res = res .. "... " break end
                if isArray then res = res .. parseValue(val, d + 1) .. ", " else res = res .. (type(k) == "number" and "["..k.."]" or '["'..tostring(k)..'"]') .. " = " .. parseValue(val, d + 1) .. ", " end
            end
            local result = res:gsub(", $", "") .. "}"; return result == "}" and "{}" or result
        elseif t == "userdata" then
            local tn = typeof(v)
            if tn == "CFrame" then return "CFrame.new(" .. tostring(v) .. ")"
            elseif tn == "Vector3" then return "Vector3.new(" .. tostring(v) .. ")"
            elseif tn == "Instance" then return getSafePath(v) end
            return tostring(v)
        else return tostring(v) end
    end

    local argList = {}; for i, v in ipairs(args) do argList[#argList + 1] = parseValue(v) end
    local finalArgsStr = table.concat(argList, ", ")
    
    local alreadyExists = false
    for _, m in ipairs(MainMemory) do
        if m.path == eventPath and m.isSelf == isSelf then
            if isSelf then if (selfMode and true) or (not selfMode and m.argsStr == finalArgsStr) then alreadyExists = true; break end
            else if controlMode then alreadyExists = true; break else if m.argsStr == finalArgsStr then alreadyExists = true; break end end end
        end
    end
    if alreadyExists then return end

    local logDetails = string.format("Type: %s\n\nPath: %s\n\nArgs: %s\n\nScript:\n%s:%s(%s)", typeLabel, eventPath, (finalArgsStr == "" and "None" or finalArgsStr), eventPath, (typeLabel == "IS" and "InvokeServer" or (typeLabel == "FC" and "FireClient" or "FireServer")), finalArgsStr)

    if not isSelf and not controlMode and antiSpam then
        if (tick() - (AntiSpamCooldowns[eventPath] or 0)) < 0.4 then
            AntiSpamCounts[eventPath] = (AntiSpamCounts[eventPath] or 0) + 1
            if AntiSpamCounts[eventPath] >= 4 then
                ManualBannedPaths[eventPath] = {guid = generateGUID(), prefix = "AUTO-BANNED\n\n", fullText = logDetails, rawArgs = args, type = typeLabel, path = eventPath, argsStr = finalArgsStr}
                local nM = {}; for _, m in ipairs(MainMemory) do if not (m.path == eventPath and not m.isSelf) then nM[#nM+1] = m end end
                MainMemory = nM; lastCount = -1; currentSelectionGUID = nil; updateRedListUI(); return 
            end
        else AntiSpamCounts[eventPath] = 0 end; AntiSpamCooldowns[eventPath] = tick()
    end

    table.insert(MainMemory, 1, { guid = generateGUID(), name = tostring(rem.Name), type = typeLabel, isSelf = isSelf, fullText = logDetails, path = eventPath, argsStr = finalArgsStr, rawArgs = args })
end

-- HOOKS
local mt = getrawmetatable(game); local old = mt.__namecall; setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local m = getnamecallmethod(); local a = {...}; local s = checkcaller()
    if m:lower() == "fireserver" then task.spawn(addLog, self, a, s, "FS")
    elseif m:lower() == "fireclient" then task.spawn(addLog, self, a, s, "FC")
    elseif m:lower() == "invokeserver" then task.spawn(addLog, self, a, s, "IS") end
    return old(self, ...)
end); setreadonly(mt, true)

-- INTERACTIONS
ControlBtn.MouseButton1Click:Connect(function() 
    controlMode = not controlMode
    ControlBtn.Text, ControlBtn.BackgroundColor3, AntiSpamBtn.Visible, BlockBtn.Visible, lastCount = "CONTROL: "..(controlMode and "ON" or "OFF"), controlMode and Color3.fromRGB(0, 170, 190) or Color3.fromRGB(80, 80, 85), not controlMode, not controlMode, -1 
end)

DelBtn.MouseButton1Click:Connect(function()
    if currentSelectionGUID then
        local targetData, foundInBanList = nil, false
        for path, data in pairs(ManualBannedPaths) do if data.guid == currentSelectionGUID then targetData = {path = path, guid = data.guid}; foundInBanList = true; break end end
        if not foundInBanList then
            local nM = {}; for _, m in ipairs(MainMemory) do if m.guid == currentSelectionGUID then targetData = m else nM[#nM+1] = m end end
            if targetData then MainMemory = nM end
        end
        if targetData then
            if foundInBanList then ManualBannedPaths[targetData.path] = nil; updateRedListUI(); feedback(DelBtn, "UNBANNED") else feedback(DelBtn, "DELETED") end
            lastCount, currentSelectionGUID, Details.Text = -1, nil, ""; updateDetailsCanvas()
        end
    end
end)

BlockBtn.MouseButton1Click:Connect(function()
    if currentSelectionGUID then
        for i, d in ipairs(MainMemory) do
            if d.guid == currentSelectionGUID and not d.isSelf then
                ManualBannedPaths[d.path] = {guid = d.guid, prefix = "MANUAL BANNED:\n\n", fullText = d.fullText, rawArgs = d.rawArgs, type = d.type, path = d.path, argsStr = d.argsStr}
                local nM = {}; for _, m in ipairs(MainMemory) do if not (m.path == d.path and not m.isSelf) then nM[#nM+1] = m end end
                MainMemory, lastCount, currentSelectionGUID = nM, -1, nil; updateRedListUI(); Details.Text = "Banned."; updateDetailsCanvas(); feedback(BlockBtn, "BANNED"); break
            end
        end
    end
end)

MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin; local curX, curY = Main.AbsolutePosition.X + Main.AbsoluteSize.X, Main.AbsolutePosition.Y
    if isMin then
        ContentFrame.Visible, ControlBtn.Visible, SelfBtn.Visible, AntiSpamBtn.Visible, BlockBtn.Visible, DelBtn.Visible = false, false, false, false, false, false
        Main:TweenSizeAndPosition(UDim2.new(0, 250, 0, 35), UDim2.new(0, curX - 250, 0, curY), "Out", "Quad", 0.15, true); MinBtn.Text = "+"
    else
        Main:TweenSizeAndPosition(UDim2.new(0, 820, 0, 440), UDim2.new(0, curX - 820, 0, curY), "Out", "Quad", 0.15, true, function()
            ContentFrame.Visible, ControlBtn.Visible, SelfBtn.Visible, DelBtn.Visible = true, true, true, true; if not controlMode then AntiSpamBtn.Visible, BlockBtn.Visible = true, true end
        end); MinBtn.Text, lastCount = "_", -1
    end
end)

-- RENDER
task.spawn(function()
    while task.wait(0.5) do
        if not ContentFrame or not ContentFrame.Visible or #MainMemory == lastCount then continue end
        lastCount = #MainMemory; for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        local sortedMemory = {}
        for _, d in ipairs(MainMemory) do if d.isSelf then table.insert(sortedMemory, d) end end
        for _, d in ipairs(MainMemory) do if not d.isSelf then table.insert(sortedMemory, d) end end
        for i, d in ipairs(sortedMemory) do
            local b = Instance.new("TextButton")
            b.Size, b.LayoutOrder = UDim2.new(1, -6, 0, 30), i
            b.Text = string.format("[%s]%s %s", d.type, (d.isSelf and " [S]" or ""), d.name)
            b.BackgroundColor3 = (currentSelectionGUID == d.guid) and Color3.fromRGB(100, 50, 200) or (d.isSelf and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45))
            b.TextColor3, b.BorderSizePixel, b.ClipsDescendants = Color3.new(1,1,1), 0, true
            b:SetAttribute("GUID", d.guid); b:SetAttribute("IsSelf", d.isSelf)
            b.Parent = Scroll
            b.MouseButton1Click:Connect(function()
                currentSelectionGUID = d.guid; Details.Text = getSortedDetails(d); updateDetailsCanvas(); refreshSelectionColors()
            end)
        end
    end
end)

local function createBotBtn(text, pos, size, color)
    local b = Instance.new("TextButton")
    b.Size, b.Position, b.BackgroundColor3 = size or UDim2.new(0, 220, 0, 58), pos, color
    b.Text, b.TextColor3, b.Font, b.TextSize, b.BorderSizePixel = text, Color3.new(1,1,1), Enum.Font.SourceSansBold, 14, 0
    b.Parent = ContentFrame; return b
end

local CopyArgsBtn = createBotBtn("COPY ARGS", UDim2.new(0, 205, 0.68, 0), UDim2.new(0, 95, 0, 58), Color3.fromRGB(45, 90, 45))
CopyArgsBtn.MouseButton1Click:Connect(function() 
    local a = Details.Text:match("Args: (.-)\n\nScript")
    if a then setclipboard(a); feedback(CopyArgsBtn, "COPIED!") end
end)

local SortBtn = createBotBtn("SORT: OFF", UDim2.new(0, 305, 0.68, 0), UDim2.new(0, 120, 0, 58), Color3.fromRGB(40, 70, 70))
SortBtn.MouseButton1Click:Connect(function()
    sortEnabled = not sortEnabled
    SortBtn.Text, SortBtn.BackgroundColor3 = "SORT: "..(sortEnabled and "ON" or "OFF"), sortEnabled and Color3.fromRGB(0, 140, 140) or Color3.fromRGB(40, 70, 70)
    if currentSelectionGUID then
        local found = false
        for _, m in ipairs(MainMemory) do if m.guid == currentSelectionGUID then Details.Text = getSortedDetails(m); found = true; break end end
        if not found then for _, d in pairs(ManualBannedPaths) do if d.guid == currentSelectionGUID then Details.Text = getSortedDetails(d); break end end end
        updateDetailsCanvas()
    end
end)

local CopyScriptBtn = createBotBtn("COPY SCRIPT", UDim2.new(0, 205, 0.83, 0), nil, Color3.fromRGB(60, 60, 120))
CopyScriptBtn.MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)")
    if s then setclipboard(s); feedback(CopyScriptBtn, "COPIED!") end
end)

local ClearLogBtn = createBotBtn("CLEAR LOG", UDim2.new(0, 432, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(80, 80, 85))
ClearLogBtn.MouseButton1Click:Connect(function()
    local nM = {}; for _, m in ipairs(MainMemory) do if m.isSelf then table.insert(nM, m) end end
    MainMemory, lastCount = nM, -1; feedback(ClearLogBtn, "CLEARED")
end)

local ClearSelfBtn = createBotBtn("CLEAR SELF", UDim2.new(0, 544, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(100, 80, 60))
ClearSelfBtn.MouseButton1Click:Connect(function()
    local nM = {}; for _, m in ipairs(MainMemory) do if not m.isSelf then table.insert(nM, m) end end
    MainMemory, lastCount = nM, -1; feedback(ClearSelfBtn, "CLEARED")
end)

local ExecuteBtn = createBotBtn("EXECUTE", UDim2.new(0, 432, 0.83, 0), nil, Color3.fromRGB(120, 60, 60))
ExecuteBtn.MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)") or Details.Text
    if s and s ~= "" then local f = loadstring(s); if f then task.spawn(f); feedback(ExecuteBtn, "DONE!") end end 
end)

SelfBtn.MouseButton1Click:Connect(function() 
    selfMode = not selfMode
    SelfBtn.Text, SelfBtn.BackgroundColor3, lastCount = "SELF: "..(selfMode and "ON" or "OFF"), selfMode and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(150, 50, 50), -1
end)

AntiSpamBtn.MouseButton1Click:Connect(function() 
    antiSpam = not antiSpam
    AntiSpamBtn.Text, AntiSpamBtn.BackgroundColor3 = "ANTI-SPAM: "..(antiSpam and "ON" or "OFF"), antiSpam and Color3.fromRGB(180, 150, 40) or Color3.fromRGB(80, 80, 85)
end)

local function createTypeBtn(text, pos, state, color, varName)
    local b = Instance.new("TextButton")
    b.Size, b.Position = UDim2.new(0, 150, 0, 35), pos
    b.BackgroundColor3 = state and color or Color3.fromRGB(40, 40, 45)
    b.Text, b.TextColor3, b.Font, b.TextSize, b.BorderSizePixel = text, Color3.new(1,1,1), Enum.Font.SourceSansBold, 12, 0
    b.MouseButton1Click:Connect(function()
        -- Прямая смена состояний без конфликтов
        if varName == "FS" then 
            spyFS = not spyFS 
        elseif varName == "FC" then 
            spyFC = not spyFC 
        elseif varName == "IS" then 
            spyIS = not spyIS 
        end

        -- Обновление UI конкретной кнопки на основе её переменной
        local currentVarState = false
        if varName == "FS" then currentVarState = spyFS
        elseif varName == "FC" then currentVarState = spyFC
        elseif varName == "IS" then currentVarState = spyIS end

        b.Text = varName .. " SPY: " .. (currentVarState and "ON" or "OFF")
        b.BackgroundColor3 = currentVarState and color or Color3.fromRGB(40, 40, 45)
    end)
    b.Parent = ContentFrame
end

createTypeBtn("FS SPY: ON", UDim2.new(0, 662, 0, 8), spyFS, Color3.fromRGB(130, 70, 220), "FS")
createTypeBtn("FC SPY: OFF", UDim2.new(0, 662, 0, 48), spyFC, Color3.fromRGB(50, 150, 255), "FC")
createTypeBtn("IS SPY: OFF", UDim2.new(0, 662, 0, 88), spyIS, Color3.fromRGB(255, 150, 50), "IS")
