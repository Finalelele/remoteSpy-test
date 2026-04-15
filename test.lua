-- [[ KRALLDEN SPY v9.5.0 - FIXED CAPABILITY & BAN LIST ]] --

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Очистка старых версий
if playerGui:FindFirstChild("KralldenSpyUI") then playerGui.KralldenSpyUI:Destroy() end
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
ScreenGui.Name = "KralldenSpyUI"; ScreenGui.ResetOnSpawn = false; ScreenGui.DisplayOrder = 10; ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Anti-Hide
task.spawn(function()
    while task.wait(1) do 
        if ScreenGui and ScreenGui.Parent and not ScreenGui.Enabled then
            ScreenGui.Enabled = true
        end
    end
end)

local Main = Instance.new("Frame", ScreenGui)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); Main.Size = UDim2.new(0, 820, 0, 440)
Main.Position = UDim2.new(0.5, -410, 0.5, -220); Main.Active = true; Main.Draggable = true; Main.BorderSizePixel = 0

local MainMemory, PathFilter, ManualBannedPaths = {}, {}, {}
local AntiSpamCooldowns, AntiSpamCounts = {}, {}
local selfMode, controlMode, antiSpam, sortEnabled = true, true, true, false
local spyFS, spyFC, spyIS = true, false, false
local currentSelectionGUID, lastCount = nil, 0
local isMin = false

local function generateGUID() return tostring(tick()) .. "-" .. tostring(math.random(1, 100000)) end

local RedListScroll, Scroll, Details, ContentFrame, DetailsScroll

-- ФУНКЦИЯ PRETTY PRINT
local function formatTable(t, indent)
    indent = indent or 0
    local spacing = string.rep("    ", indent + 1)
    local result = "{\n"
    
    local isArray = true
    local count = 0
    for k, _ in pairs(t) do
        count = count + 1
        if type(k) ~= "number" or k ~= count then
            isArray = false
            break
        end
    end

    for k, v in pairs(t) do
        local valStr = ""
        if type(v) == "table" then
            valStr = formatTable(v, indent + 1)
        elseif typeof(v) == "CFrame" then
            local components = {v:GetComponents()}
            for i, comp in ipairs(components) do 
                components[i] = string.format("%.3f", comp):gsub("%.?0+$", "") 
            end
            valStr = "CFrame.new(" .. table.concat(components, ", ") .. ")"
        elseif typeof(v) == "Vector3" then
            valStr = string.format("Vector3.new(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z):gsub("%.?0+,", ",")
        elseif typeof(v) == "Color3" then
            valStr = "Color3.new(" .. tostring(v) .. ")"
        elseif type(v) == "string" then
            valStr = '"' .. v .. '"'
        else
            valStr = tostring(v)
        end

        if isArray then
            result = result .. spacing .. valStr .. ",\n"
        else
            local keyStr = type(k) == "string" and '["'..k..'"]' or "["..tostring(k).."]"
            result = result .. spacing .. keyStr .. " = " .. valStr .. ",\n"
        end
    end
    return result .. string.rep("    ", indent) .. "}"
end

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

-- SMART PARSER (FIXED FOR CAPABILITY)
local function getSafePath(obj)
    local p = ""
    local success = pcall(function()
        local t = obj
        while t and t ~= game do
            local n = tostring(t.Name)
            local safeName = (n:match("^%d") or n:match("[%s%W]")) and '["'..n..'"]' or n
            p = (p == "") and safeName or safeName .. "." .. p
            t = t.Parent
        end
    end)
    if not success or p == "" then return "Unknown_Path" end
    return "game." .. p:gsub("%.%[", "[")
end

-- Обновление текста в Details
local function updateDetailsText()
    if not currentSelectionGUID then return end
    local data = nil
    for _, m in ipairs(MainMemory) do if m.guid == currentSelectionGUID then data = m; break end end
    
    if not data then 
        for path, d in pairs(ManualBannedPaths) do 
            if d.guid == currentSelectionGUID then 
                data = d
                break 
            end 
        end 
    end
    
    if data then
        local argDisplay = sortEnabled and formatTable(data.rawArgs) or data.argsStr
        local methodName = (data.type == "IS" and "InvokeServer" or (data.type == "FC" and "FireClient" or "FireServer"))
        local scriptArgs = sortEnabled and formatTable(data.rawArgs):gsub("^\n", "") or data.argsStr
        
        Details.Text = string.format("Type: %s\n\nPath: %s\n\nArgs: %s\n\nScript:\n%s:%s(%s)", 
            data.type, data.path, argDisplay, data.path, methodName, scriptArgs)
        DetailsScroll.CanvasSize = UDim2.new(0, 0, 0, Details.TextBounds.Y + 20)
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

-- ОБНОВЛЕНИЕ RED LIST (FIXED)
local function updateRedListUI()
    if not RedListScroll then return end
    for _, v in pairs(RedListScroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
    
    for path, data in pairs(ManualBannedPaths) do
        local b = Instance.new("TextButton", RedListScroll)
        b.Size = UDim2.new(1, -6, 0, 25)
        b:SetAttribute("GUID", data.guid)
        b.BackgroundColor3 = (currentSelectionGUID == data.guid) and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(100, 35, 35)
        b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 10; b.BorderSizePixel = 0
        b.Text = " [X] " .. (path:match("[^%.%[%]]+$") or path)
        b.MouseButton1Click:Connect(function() 
            currentSelectionGUID = data.guid
            updateDetailsText()
            refreshSelectionColors()
        end)
    end
end

-- UI ELEMENTS (Header, Buttons, etc.)
local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 35); Header.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Header.ZIndex = 10; Header.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(0, 200, 1, 0); Title.BackgroundTransparency = 1; Title.Position = UDim2.new(0, 15, 0, 0)
Title.Text = "KRALLDEN SPY v9.5.0"; Title.TextColor3 = Color3.new(1, 1, 1); Title.Font = Enum.Font.SourceSansBold; Title.TextSize = 16; Title.ZIndex = 11; Title.TextXAlignment = 0

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.new(0, 45, 0, 35); MinBtn.Position = UDim2.new(1, -45, 0, 0); MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 180); MinBtn.Text = "_"; MinBtn.TextColor3 = Color3.new(1, 1, 1); MinBtn.TextSize = 22; MinBtn.ZIndex = 12; MinBtn.BorderSizePixel = 0

local function createHeaderBtn(text, offset, color, sizeX)
    local b = Instance.new("TextButton", Header)
    b.Size = UDim2.new(0, sizeX or 100, 0, 24); b.Position = UDim2.new(1, offset, 0.5, -12); b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 11; b.ZIndex = 11; b.BorderSizePixel = 0
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
ContentFrame.Size = UDim2.new(1, 0, 1, -35); ContentFrame.Position = UDim2.new(0, 0, 0, 35); ContentFrame.BackgroundTransparency = 1; ContentFrame.ClipsDescendants = true

Scroll = Instance.new("ScrollingFrame", ContentFrame)
Scroll.Position = UDim2.new(0, 8, 0, 8); Scroll.Size = UDim2.new(0, 190, 1, -16); Scroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; Scroll.BorderSizePixel = 0
Instance.new("UIListLayout", Scroll).SortOrder = Enum.SortOrder.LayoutOrder

DetailsScroll = Instance.new("ScrollingFrame", ContentFrame)
DetailsScroll.Position = UDim2.new(0, 205, 0, 8); DetailsScroll.Size = UDim2.new(0, 448, 0, 255); DetailsScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 12); DetailsScroll.BorderSizePixel = 0; DetailsScroll.ScrollBarThickness = 4; DetailsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

Details = Instance.new("TextBox", DetailsScroll)
Details.Size = UDim2.new(1, -10, 0, 0); Details.BackgroundTransparency = 1; Details.TextColor3 = Color3.new(1, 1, 1); Details.MultiLine = true; Details.TextWrapped = true; Details.TextEditable = true; Details.Font = Enum.Font.Code; Details.TextSize = 12; Details.TextXAlignment = 0; Details.TextYAlignment = 0; Details.ClearTextOnFocus = false; Details.AutomaticSize = Enum.AutomaticSize.Y

local SortBtn = Instance.new("TextButton", ContentFrame)
SortBtn.Size = UDim2.new(0, 60, 0, 20); SortBtn.Position = UDim2.new(0, 590, 0, 12); SortBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 150); SortBtn.Text = "SORT: OFF"; SortBtn.TextColor3 = Color3.new(1,1,1); SortBtn.Font = Enum.Font.SourceSansBold; SortBtn.TextSize = 10; SortBtn.ZIndex = 15; SortBtn.BorderSizePixel = 0

SortBtn.MouseButton1Click:Connect(function()
    sortEnabled = not sortEnabled
    SortBtn.Text = "SORT: " .. (sortEnabled and "ON" or "OFF")
    SortBtn.BackgroundColor3 = sortEnabled and Color3.fromRGB(30, 120, 255) or Color3.fromRGB(40, 60, 150)
    updateDetailsText()
end)

local BanListTitle = Instance.new("TextLabel", ContentFrame)
BanListTitle.Size = UDim2.new(0, 150, 0, 20); BanListTitle.Position = UDim2.new(0, 662, 0, 125); BanListTitle.BackgroundTransparency = 1
BanListTitle.Text = "BAN LIST"; BanListTitle.TextColor3 = Color3.fromRGB(255, 100, 100); BanListTitle.Font = Enum.Font.SourceSansBold; BanListTitle.TextSize = 14

RedListScroll = Instance.new("ScrollingFrame", ContentFrame)
RedListScroll.Position = UDim2.new(0, 662, 0, 145); RedListScroll.Size = UDim2.new(0, 150, 0, 250); RedListScroll.BackgroundColor3 = Color3.fromRGB(30, 15, 15); RedListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; RedListScroll.BorderSizePixel = 0
Instance.new("UIListLayout", RedListScroll).SortOrder = Enum.SortOrder.LayoutOrder

-- LOGIC & HOOKS
local function addLog(rem, args, isSelf, typeLabel)
    if (typeLabel == "FS" and not spyFS) or (typeLabel == "FC" and not spyFC) or (typeLabel == "IS" and not spyIS) then return end
    
    local eventPath = getSafePath(rem)
    if not isSelf and ManualBannedPaths[eventPath] then return end

    local function parseValue(v, d)
        d = d or 0; if d > 4 then return "..." end
        local t = type(v)
        if t == "string" then return '"' .. v .. '"'
        elseif t == "table" then
            local isArray, count = true, 0
            for k, val in pairs(v) do count = count + 1; if type(k) ~= "number" or k ~= count then isArray = false break end end
            local res, i = "{", 0
            for k, val in pairs(v) do i = i + 1; if i > 15 then res = res .. "... " break end
                if isArray then res = res .. parseValue(val, d + 1) .. ", "
                else local key = type(k) == "number" and "["..k.."]" or '["'..tostring(k)..'"]'
                    res = res .. key .. " = " .. parseValue(val, d + 1) .. ", "
                end
            end
            local result = res:gsub(", $", "") .. "}"
            return result == "}" and "{}" or result
        elseif t == "userdata" then
            local tn = typeof(v)
            if tn == "CFrame" then return "CFrame.new(" .. tostring(v) .. ")"
            elseif tn == "Vector3" then return "Vector3.new(" .. tostring(v) .. ")"
            elseif tn == "Color3" then return "Color3.new(" .. tostring(v) .. ")"
            elseif tn == "Instance" then return getSafePath(v) end
            return tostring(v)
        else return tostring(v) end
    end

    local argList = {}
    for i, v in ipairs(args) do argList[#argList + 1] = parseValue(v) end
    local finalArgsStr = table.concat(argList, ", ")
    
    local alreadyExists = false
    for _, m in ipairs(MainMemory) do
        if m.path == eventPath and m.isSelf == isSelf then
            if isSelf then
                if selfMode or m.argsStr == finalArgsStr then alreadyExists = true; break end
            else
                if controlMode or m.argsStr == finalArgsStr then alreadyExists = true; break end
            end
        end
    end

    if alreadyExists then return end

    -- ANTI-SPAM
    if not isSelf and not controlMode and antiSpam then
        if (tick() - (AntiSpamCooldowns[eventPath] or 0)) < 0.4 then
            AntiSpamCounts[eventPath] = (AntiSpamCounts[eventPath] or 0) + 1
            if AntiSpamCounts[eventPath] >= 4 then
                ManualBannedPaths[eventPath] = { guid = generateGUID(), rawArgs = args, argsStr = finalArgsStr, type = typeLabel, path = eventPath }
                updateRedListUI(); return 
            end
        else AntiSpamCounts[eventPath] = 0 end
        AntiSpamCooldowns[eventPath] = tick()
    end

    local data = { guid = generateGUID(), name = tostring(rem.Name), type = typeLabel, isSelf = isSelf, path = eventPath, argsStr = finalArgsStr, rawArgs = args }
    table.insert(MainMemory, 1, data)
    if #MainMemory > 100 then table.remove(MainMemory, 101) end
end

local mt = getrawmetatable(game); local old = mt.__namecall; setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local m = getnamecallmethod(); local a = {...}; local s = checkcaller()
    local success, res = pcall(function()
        if m:lower() == "fireserver" then task.spawn(addLog, self, a, s, "FS")
        elseif m:lower() == "fireclient" then task.spawn(addLog, self, a, s, "FC")
        elseif m:lower() == "invokeserver" then task.spawn(addLog, self, a, s, "IS") end
    end)
    return old(self, ...)
end); setreadonly(mt, true)

-- BUTTON ACTIONS
ControlBtn.MouseButton1Click:Connect(function() 
    controlMode = not controlMode
    ControlBtn.Text = "CONTROL: "..(controlMode and "ON" or "OFF")
    ControlBtn.BackgroundColor3 = controlMode and Color3.fromRGB(0, 170, 190) or Color3.fromRGB(80, 80, 85)
    AntiSpamBtn.Visible = not controlMode; BlockBtn.Visible = not controlMode
    lastCount = -1 
end)

BlockBtn.MouseButton1Click:Connect(function()
    if currentSelectionGUID then
        for i, d in ipairs(MainMemory) do
            if d.guid == currentSelectionGUID and not d.isSelf then
                ManualBannedPaths[d.path] = d
                table.remove(MainMemory, i)
                lastCount = -1; updateRedListUI(); feedback(BlockBtn, "BANNED"); break
            end
        end
    end
end)

DelBtn.MouseButton1Click:Connect(function()
    if currentSelectionGUID then
        for path, data in pairs(ManualBannedPaths) do
            if data.guid == currentSelectionGUID then ManualBannedPaths[path] = nil; updateRedListUI(); break end
        end
        for i, m in ipairs(MainMemory) do
            if m.guid == currentSelectionGUID then table.remove(MainMemory, i); break end
        end
        currentSelectionGUID = nil; Details.Text = ""; lastCount = -1; feedback(DelBtn, "DELETED")
    end
end)

-- RENDER LOOP
task.spawn(function()
    while task.wait(0.5) do
        if not ContentFrame or not ContentFrame.Visible or #MainMemory == lastCount then continue end
        lastCount = #MainMemory; for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        
        for i, d in ipairs(MainMemory) do
            local b = Instance.new("TextButton", Scroll); b.Size = UDim2.new(1, -6, 0, 30); b.LayoutOrder = i
            b.Text = string.format("[%s]%s %s", d.type, (d.isSelf and " [S]" or ""), d.name)
            b:SetAttribute("GUID", d.guid); b:SetAttribute("IsSelf", d.isSelf)
            b.BackgroundColor3 = (currentSelectionGUID == d.guid) and Color3.fromRGB(100, 50, 200) or (d.isSelf and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45))
            b.TextColor3 = Color3.new(1,1,1); b.BorderSizePixel = 0
            b.MouseButton1Click:Connect(function()
                currentSelectionGUID = d.guid; updateDetailsText(); refreshSelectionColors()
            end)
        end
    end
end)

-- ОСТАЛЬНЫЕ КНОПКИ (COPY, EXECUTE, TYPE)
local function createBotBtn(text, pos, size, color)
    local b = Instance.new("TextButton", ContentFrame); b.Size = size or UDim2.new(0, 220, 0, 58); b.Position = pos; b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 14; b.BorderSizePixel = 0; return b
end

createBotBtn("COPY ARGS", UDim2.new(0, 205, 0.68, 0), nil, Color3.fromRGB(45, 90, 45)).MouseButton1Click:Connect(function() 
    local a = Details.Text:match("Args: (.-)\n\nScript"); if a then setclipboard(a) end
end)

createBotBtn("COPY SCRIPT", UDim2.new(0, 205, 0.83, 0), nil, Color3.fromRGB(60, 60, 120)).MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)"); if s then setclipboard(s) end
end)

createBotBtn("EXECUTE", UDim2.new(0, 432, 0.83, 0), nil, Color3.fromRGB(120, 60, 60)).MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)"); if s then loadstring(s)() end
end)

local function createTypeBtn(text, pos, state, color, varName)
    local b = Instance.new("TextButton", ContentFrame); b.Size = UDim2.new(0, 150, 0, 35); b.Position = pos; b.BackgroundColor3 = state and color or Color3.fromRGB(40, 40, 45); b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 12; b.BorderSizePixel = 0
    b.MouseButton1Click:Connect(function()
        if varName == "FS" then spyFS = not spyFS elseif varName == "FC" then spyFC = not spyFC elseif varName == "IS" then spyIS = not spyIS end
        local ns = (varName == "FS" and spyFS or varName == "FC" and spyFC or spyIS)
        b.Text = varName.." SPY: "..(ns and "ON" or "OFF"); b.BackgroundColor3 = ns and color or Color3.fromRGB(40, 40, 45)
    end)
end
createTypeBtn("FS SPY: ON", UDim2.new(0, 662, 0, 8), spyFS, Color3.fromRGB(130, 70, 220), "FS")
createTypeBtn("FC SPY: OFF", UDim2.new(0, 662, 0, 48), spyFC, Color3.fromRGB(50, 150, 255), "FC")
createTypeBtn("IS SPY: OFF", UDim2.new(0, 662, 0, 88), spyIS, Color3.fromRGB(255, 150, 50), "IS")
