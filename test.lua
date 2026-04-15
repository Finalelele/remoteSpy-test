-- [[ KRALLDEN SPY v9.5.1 - CLEAN SORT + COMPACT UI + SCROLL ]] --

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("KralldenSpyUI") then playerGui.KralldenSpyUI:Destroy() end
for _, gui in ipairs(game.CoreGui:GetChildren()) do
    pcall(function() if gui.Name == "KralldenSpyUI" then gui:Destroy() elseif gui:FindFirstChild("KralldenSpyUI") then gui.KralldenSpyUI:Destroy() end end)
end

local targetParent = (gethui and gethui()) or (game:GetService("CoreGui"):FindFirstChild("RobloxGui")) or playerGui
local ScreenGui = Instance.new("ScreenGui", targetParent)
ScreenGui.Name = "KralldenSpyUI"; ScreenGui.ResetOnSpawn = false; ScreenGui.DisplayOrder = 10; ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

task.spawn(function() while task.wait(1) do if ScreenGui and ScreenGui.Parent and not ScreenGui.Enabled then ScreenGui.Enabled = true end end end)

local Main = Instance.new("Frame", ScreenGui)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); Main.Size = UDim2.new(0, 820, 0, 440); Main.Position = UDim2.new(0.5, -410, 0.5, -220); Main.Active = true; Main.Draggable = true; Main.BorderSizePixel = 0

local MainMemory, ManualBannedPaths, AntiSpamCooldowns, AntiSpamCounts = {}, {}, {}, {}
local selfMode, controlMode, antiSpam, spyFS, spyFC, spyIS, sortEnabled, currentSelectionGUID, lastCount, isMin = true, true, true, true, false, false, false, nil, 0, false

local function generateGUID() return tostring(tick()) .. "-" .. tostring(math.random(1, 100000)) end

local RedListScroll, Scroll, Details, ContentFrame, DetailsScroll

-- [[ ЧИСТЫЙ СОРТИРОВЩИК (БЕЗ ЦИФР) ]] --
local function getSafePath(obj)
    local p = ""; pcall(function() 
        local t = obj; while t and t ~= game do 
            local n = tostring(t.Name); local safe = (n:match("^%d") or n:match("[%s%W]")) and '["'..n..'"]' or n
            p = (p == "" and safe or safe .. "." .. p); t = t.Parent 
        end 
    end)
    return ("game." .. p):gsub("%.%[", "[")
end

local function formatTableVisual(val, indent)
    indent = indent or 0; local tab = string.rep("    ", indent); local t = typeof(val)
    if t == "table" then
        local res = "{\n"; local isArray = true; local count = 0
        for k, v in pairs(val) do count = count + 1; if type(k) ~= "number" or k ~= count then isArray = false break end end
        for k, v in pairs(val) do
            local keyStr = isArray and "" or (type(k) == "string" and k .. " = " or "[" .. tostring(k) .. "] = ")
            res = res .. tab .. "    " .. keyStr .. formatTableVisual(v, indent + 1) .. ",\n"
        end
        return res .. tab .. "}"
    elseif t == "string" then return '"' .. val .. '"'
    elseif t == "Vector3" then return string.format("Vector3.new(%.3f, %.3f, %.3f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then return "CFrame.new(" .. tostring(val) .. ")"
    elseif t == "Instance" then return getSafePath(val)
    else return tostring(val) end
end

local function parseRaw(v, depth)
    depth = (depth or 0) + 1; if depth > 8 then return "..." end
    local t = typeof(v)
    if t == "table" then
        local res, i = "{", 0; for k, val in pairs(v) do i = i + 1; if i > 15 then res = res .. "... " break end
            local key = type(k) == "number" and "" or '["'..tostring(k)..'"] = '
            res = res .. key .. parseRaw(val, depth) .. ", "
        end
        return res:gsub(", $", "") .. "}"
    elseif t == "string" then return '"' .. v .. '"'
    elseif t == "Instance" then return getSafePath(v)
    else return tostring(v) end
end

local activeFeedbacks = {}
local function feedback(button, tempText)
    if not button or activeFeedbacks[button] then return end
    activeFeedbacks[button] = true; local oldText = button.Text; button.Text = tempText
    task.delay(1, function() if button and button.Parent then button.Text = oldText; activeFeedbacks[button] = nil end end)
end

-- [[ HEADER ]] --
local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 35); Header.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Header.BorderSizePixel = 0; Header.ZIndex = 10

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(0, 200, 1, 0); Title.BackgroundTransparency = 1; Title.Position = UDim2.new(0, 15, 0, 0); Title.Text = "KRALLDEN SPY v9.5.1"; Title.TextColor3 = Color3.new(1, 1, 1); Title.Font = Enum.Font.SourceSansBold; Title.TextSize = 16; Title.TextXAlignment = 0

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.new(0, 45, 0, 35); MinBtn.Position = UDim2.new(1, -45, 0, 0); MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 180); MinBtn.Text = "_"; MinBtn.TextColor3 = Color3.new(1, 1, 1); MinBtn.TextSize = 22; MinBtn.BorderSizePixel = 0

local function createHeaderBtn(text, offset, color, sizeX)
    local b = Instance.new("TextButton", Header)
    b.Size = UDim2.new(0, sizeX or 100, 0, 24); b.Position = UDim2.new(1, offset, 0.5, -12); b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 11; b.BorderSizePixel = 0
    return b
end

local ControlBtn = createHeaderBtn("CONTROL: ON", -150, Color3.fromRGB(0, 170, 190))
local SelfBtn = createHeaderBtn("SELF: ON", -235, Color3.fromRGB(45, 90, 45), 80)
local DelBtn = createHeaderBtn("DEL BTN", -310, Color3.fromRGB(200, 100, 0), 70)
local AntiSpamBtn = createHeaderBtn("ANTI-SPAM: ON", -420, Color3.fromRGB(180, 150, 40)); AntiSpamBtn.Visible = false
local BlockBtn = createHeaderBtn("BLOCK EVENT", -530, Color3.fromRGB(150, 50, 50)); BlockBtn.Visible = false

-- [[ CONTENT UI ]] --
ContentFrame = Instance.new("Frame", Main)
ContentFrame.Size = UDim2.new(1, 0, 1, -35); ContentFrame.Position = UDim2.new(0, 0, 0, 35); ContentFrame.BackgroundTransparency = 1; ContentFrame.ClipsDescendants = true

Scroll = Instance.new("ScrollingFrame", ContentFrame)
Scroll.Position = UDim2.new(0, 8, 0, 8); Scroll.Size = UDim2.new(0, 190, 1, -16); Scroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; Scroll.BorderSizePixel = 0; Scroll.ScrollBarThickness = 4
Instance.new("UIListLayout", Scroll).SortOrder = Enum.SortOrder.LayoutOrder

DetailsScroll = Instance.new("ScrollingFrame", ContentFrame)
DetailsScroll.Position = UDim2.new(0, 205, 0, 8); DetailsScroll.Size = UDim2.new(0, 448, 0, 255); DetailsScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 12); DetailsScroll.BorderSizePixel = 0; DetailsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; DetailsScroll.ScrollingDirection = Enum.ScrollingDirection.Y; DetailsScroll.ScrollBarThickness = 4

Details = Instance.new("TextBox", DetailsScroll)
Details.Size = UDim2.new(1, -10, 1, 0); Details.BackgroundTransparency = 1; Details.TextColor3 = Color3.new(1, 1, 1); Details.MultiLine = true; Details.TextWrapped = true; Details.TextEditable = true; Details.Font = Enum.Font.Code; Details.TextSize = 12; Details.TextXAlignment = 0; Details.TextYAlignment = 0; Details.ClearTextOnFocus = false

local BanListTitle = Instance.new("TextLabel", ContentFrame)
BanListTitle.Size = UDim2.new(0, 150, 0, 20); BanListTitle.Position = UDim2.new(0, 662, 0, 125); BanListTitle.BackgroundTransparency = 1; BanListTitle.Text = "BAN LIST"; BanListTitle.TextColor3 = Color3.fromRGB(255, 100, 100); BanListTitle.Font = Enum.Font.SourceSansBold; BanListTitle.TextSize = 14

RedListScroll = Instance.new("ScrollingFrame", ContentFrame)
RedListScroll.Position = UDim2.new(0, 662, 0, 145); RedListScroll.Size = UDim2.new(0, 150, 0, 250); RedListScroll.BackgroundColor3 = Color3.fromRGB(30, 15, 15); RedListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; RedListScroll.BorderSizePixel = 0; RedListScroll.ScrollBarThickness = 2
Instance.new("UIListLayout", RedListScroll).SortOrder = Enum.SortOrder.LayoutOrder

-- [[ LOGIC ]] --
local function updateDetailsText(d)
    if not d then return end
    local disp = sortEnabled and formatTableVisual(d.rawArgs) or (d.argsStr == "" and "None" or d.argsStr)
    local scriptCode = string.format("%s:%s(%s)", d.path, d.method, d.argsStr)
    Details.Text = string.format("Type: %s\n\nPath: %s\n\nArgs: %s\n\nScript:\n%s", d.type, d.path, disp, scriptCode)
end

local function refreshColors()
    for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextButton") then v.BackgroundColor3 = (v:GetAttribute("GUID") == currentSelectionGUID) and Color3.fromRGB(100, 50, 200) or (v:GetAttribute("IsSelf") and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45)) end end
    for _, v in pairs(RedListScroll:GetChildren()) do if v:IsA("TextButton") then v.BackgroundColor3 = (v:GetAttribute("GUID") == currentSelectionGUID) and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(100, 35, 35) end end
end

local function updateRedListUI()
    for _, v in pairs(RedListScroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
    for path, data in pairs(ManualBannedPaths) do
        local b = Instance.new("TextButton", RedListScroll); b.Size = UDim2.new(1, -6, 0, 25); b:SetAttribute("GUID", data.guid); b.BackgroundColor3 = (currentSelectionGUID == data.guid) and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(100, 35, 35); b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 10; b.BorderSizePixel = 0; b.Text = " [X] " .. (path:match("[^%.%[%]]+$") or path)
        b.MouseButton1Click:Connect(function() currentSelectionGUID = data.guid; Details.Text = data.details; refreshColors() end)
    end
end

local function addLog(rem, args, isSelf, typeLabel)
    if (typeLabel == "FS" and not spyFS) or (typeLabel == "FC" and not spyFC) or (typeLabel == "IS" and not spyIS) then return end
    local path = getSafePath(rem); if not isSelf and ManualBannedPaths[path] then return end
    local argList = {}; for _, v in ipairs(args) do table.insert(argList, parseRaw(v)) end
    local argsStr = table.concat(argList, ", ")
    for _, m in ipairs(MainMemory) do if m.path == path and m.isSelf == isSelf then if isSelf then if selfMode or m.argsStr == argsStr then return end else if controlMode or m.argsStr == argsStr then return end end end end
    
    if not isSelf and not controlMode and antiSpam then
        local now = tick(); if (now - (AntiSpamCooldowns[path] or 0)) < 0.4 then AntiSpamCounts[path] = (AntiSpamCounts[path] or 0) + 1
            if AntiSpamCounts[path] >= 4 then ManualBannedPaths[path] = {guid = generateGUID(), details = "AUTO-BANNED (SPAM)\nPath: "..path}; local nM = {}; for _, m in ipairs(MainMemory) do if m.path ~= path or m.isSelf then table.insert(nM, m) end end; MainMemory = nM; lastCount = -1; updateRedListUI(); return end
        else AntiSpamCounts[path] = 0 end; AntiSpamCooldowns[path] = now
    end

    local data = { guid = generateGUID(), name = tostring(rem.Name), type = typeLabel, isSelf = isSelf, path = path, argsStr = argsStr, rawArgs = args, method = (typeLabel == "IS" and "InvokeServer" or (typeLabel == "FC" and "FireClient" or "FireServer")) }
    table.insert(MainMemory, 1, data); if #MainMemory > 250 then table.remove(MainMemory, #MainMemory) end
end

local mt = getrawmetatable(game); local old = mt.__namecall; setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local m = getnamecallmethod():lower(); local a = {...}; local s = checkcaller()
    if m == "fireserver" then task.spawn(addLog, self, a, s, "FS") elseif m == "fireclient" then task.spawn(addLog, self, a, s, "FC") elseif m == "invokeserver" then task.spawn(addLog, self, a, s, "IS") end
    return old(self, ...)
end); setreadonly(mt, true)

-- [[ BUTTONS ]] --
ControlBtn.MouseButton1Click:Connect(function() controlMode = not controlMode; ControlBtn.Text = "CONTROL: "..(controlMode and "ON" or "OFF"); ControlBtn.BackgroundColor3 = controlMode and Color3.fromRGB(0, 170, 190) or Color3.fromRGB(80, 80, 85); AntiSpamBtn.Visible = not controlMode; BlockBtn.Visible = not controlMode; lastCount = -1 end)

DelBtn.MouseButton1Click:Connect(function()
    if not currentSelectionGUID then return end
    for p, d in pairs(ManualBannedPaths) do if d.guid == currentSelectionGUID then ManualBannedPaths[p] = nil; updateRedListUI(); feedback(DelBtn, "UNBANNED"); return end end
    local nM = {}; for _, m in ipairs(MainMemory) do if m.guid ~= currentSelectionGUID then table.insert(nM, m) end end; MainMemory = nM; lastCount = -1; currentSelectionGUID = nil; Details.Text = ""; feedback(DelBtn, "DELETED")
end)

BlockBtn.MouseButton1Click:Connect(function()
    if not currentSelectionGUID then return end
    for _, d in ipairs(MainMemory) do if d.guid == currentSelectionGUID and not d.isSelf then ManualBannedPaths[d.path] = {guid = d.guid, details = "MANUAL BAN\nPath: "..d.path}; local nM = {}; for _, m in ipairs(MainMemory) do if m.path ~= d.path or m.isSelf then table.insert(nM, m) end end; MainMemory = nM; lastCount = -1; updateRedListUI(); feedback(BlockBtn, "BLOCKED"); break end end
end)

MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin; local curX, curY = Main.AbsolutePosition.X + Main.AbsoluteSize.X, Main.AbsolutePosition.Y
    if isMin then ContentFrame.Visible = false; Main:TweenSizeAndPosition(UDim2.new(0, 250, 0, 35), UDim2.new(0, curX - 250, 0, curY), "Out", "Quad", 0.15, true); MinBtn.Text = "+"
    else Main:TweenSizeAndPosition(UDim2.new(0, 820, 0, 440), UDim2.new(0, curX - 820, 0, curY), "Out", "Quad", 0.15, true, function() ContentFrame.Visible = true; lastCount = -1 end); MinBtn.Text = "_" end
end)

task.spawn(function()
    while task.wait(0.5) do
        if not ContentFrame.Visible or #MainMemory == lastCount then continue end
        lastCount = #MainMemory; for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        for i, d in ipairs(MainMemory) do
            local b = Instance.new("TextButton", Scroll); b.Size = UDim2.new(1, -6, 0, 30); b.LayoutOrder = i; b.Text = string.format("[%s]%s %s", d.type, (d.isSelf and " [S]" or ""), d.name); b:SetAttribute("GUID", d.guid); b:SetAttribute("IsSelf", d.isSelf); b.BackgroundColor3 = (currentSelectionGUID == d.guid) and Color3.fromRGB(100, 50, 200) or (d.isSelf and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45)); b.TextColor3 = Color3.new(1,1,1); b.BorderSizePixel = 0; b.MouseButton1Click:Connect(function() currentSelectionGUID = d.guid; updateDetailsText(d); refreshColors() end)
        end
    end
end)

local function createBotBtn(text, pos, size, color)
    local b = Instance.new("TextButton", ContentFrame); b.Size = size or UDim2.new(0, 220, 0, 58); b.Position = pos; b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 14; b.BorderSizePixel = 0; return b
end

local CopyArgsBtn = createBotBtn("COPY ARGS", UDim2.new(0, 205, 0.68, 0), UDim2.new(0, 95, 0, 58), Color3.fromRGB(45, 90, 45))
CopyArgsBtn.MouseButton1Click:Connect(function() local a = Details.Text:match("Args: (.*)\n\nScript"); if a then setclipboard(a); feedback(CopyArgsBtn, "COPIED") end end)

local SortBtn = createBotBtn("SORT: OFF", UDim2.new(0, 305, 0.68, 0), UDim2.new(0, 120, 0, 58), Color3.fromRGB(130, 70, 220))
SortBtn.MouseButton1Click:Connect(function() sortEnabled = not sortEnabled; SortBtn.Text = "SORT: "..(sortEnabled and "ON" or "OFF"); SortBtn.BackgroundColor3 = sortEnabled and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(130, 70, 220); if currentSelectionGUID then for _, m in ipairs(MainMemory) do if m.guid == currentSelectionGUID then updateDetailsText(m) break end end end end)

local CopyScriptBtn = createBotBtn("COPY SCRIPT", UDim2.new(0, 205, 0.83, 0), nil, Color3.fromRGB(60, 60, 120))
CopyScriptBtn.MouseButton1Click:Connect(function() local s = Details.Text:match("Script:\n(.*)"); if s then setclipboard(s); feedback(CopyScriptBtn, "COPIED") end end)

local ClearLogBtn = createBotBtn("CLEAR LOG", UDim2.new(0, 432, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(80, 80, 85))
ClearLogBtn.MouseButton1Click:Connect(function() local nM = {}; for _, m in ipairs(MainMemory) do if m.isSelf then table.insert(nM, m) end end; MainMemory = nM; lastCount = -1; feedback(ClearLogBtn, "CLEARED") end)

local ClearSelfBtn = createBotBtn("CLEAR SELF", UDim2.new(0, 544, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(100, 80, 60))
ClearSelfBtn.MouseButton1Click:Connect(function() local nM = {}; for _, m in ipairs(MainMemory) do if not m.isSelf then table.insert(nM, m) end end; MainMemory = nM; lastCount = -1; feedback(ClearSelfBtn, "CLEARED") end)

local ExecuteBtn = createBotBtn("EXECUTE", UDim2.new(0, 432, 0.83, 0), nil, Color3.fromRGB(120, 60, 60))
ExecuteBtn.MouseButton1Click:Connect(function() local c = Details.Text:match("Script:\n(.*)") or Details.Text; if c then local f = loadstring(c); if f then task.spawn(f); feedback(ExecuteBtn, "OK") else feedback(ExecuteBtn, "ERR") end end end)

local function createTypeBtn(text, pos, state, color, typeKey)
    local b = Instance.new("TextButton", ContentFrame); b.Size = UDim2.new(0, 150, 0, 35); b.Position = pos; b.BackgroundColor3 = state and color or Color3.fromRGB(40, 40, 45); b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 12; b.BorderSizePixel = 0
    b.MouseButton1Click:Connect(function() if typeKey == "FS" then spyFS = not spyFS elseif typeKey == "FC" then spyFC = not spyFC else spyIS = not spyIS end; local ns = (typeKey == "FS" and spyFS or typeKey == "FC" and spyFC or spyIS); b.Text = typeKey.." SPY: "..(ns and "ON" or "OFF"); b.BackgroundColor3 = ns and color or Color3.fromRGB(40, 40, 45) end)
end
createTypeBtn("FS SPY: ON", UDim2.new(0, 662, 0, 8), spyFS, Color3.fromRGB(130, 70, 220), "FS")
createTypeBtn("FC SPY: OFF", UDim2.new(0, 662, 0, 48), spyFC, Color3.fromRGB(50, 150, 255), "FC")
createTypeBtn("IS SPY: OFF", UDim2.new(0, 662, 0, 88), spyIS, Color3.fromRGB(255, 150, 50), "IS")

SelfBtn.MouseButton1Click:Connect(function() selfMode = not selfMode; SelfBtn.Text = "SELF: "..(selfMode and "ON" or "OFF"); SelfBtn.BackgroundColor3 = selfMode and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(150, 50, 50); lastCount = -1 end)
AntiSpamBtn.MouseButton1Click:Connect(function() antiSpam = not antiSpam; AntiSpamBtn.Text = "ANTI-SPAM: "..(antiSpam and "ON" or "OFF"); AntiSpamBtn.BackgroundColor3 = antiSpam and Color3.fromRGB(180, 150, 40) or Color3.fromRGB(80, 80, 85) end)
