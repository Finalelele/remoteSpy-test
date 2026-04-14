-- [[ KRALLDEN SPY v9.5.1 - BUFFER REFRESH FIX ]] --

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("KralldenSpyUI") then playerGui.KralldenSpyUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui", playerGui)
ScreenGui.Name = "KralldenSpyUI"; ScreenGui.ResetOnSpawn = false; ScreenGui.DisplayOrder = 2147483647

ScreenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if ScreenGui.Enabled == false then ScreenGui.Enabled = true end
end)

local Main = Instance.new("Frame", ScreenGui)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); Main.Size = UDim2.new(0, 820, 0, 440)
Main.Position = UDim2.new(0.5, -410, 0.5, -220); Main.Active = true; Main.Draggable = true; Main.BorderSizePixel = 0

local MainMemory, PathFilter, ManualBannedPaths = {}, {}, {}
local AntiSpamCooldowns, AntiSpamCounts = {}, {}
local selfMode, controlMode, antiSpam, spyBuffer = true, true, true, true
local spyFS, spyFC, spyIS = true, false, false
local currentSelectionGUID, lastCount = nil, 0
local isMin = false

local function generateGUID() return tostring(tick()) .. "-" .. tostring(math.random(1, 100000)) end

local RedListScroll, Scroll, Details, ContentFrame
local activeFeedbacks = {}

local function feedback(button, tempText)
    if not button or type(button) ~= "userdata" then return end
    if activeFeedbacks[button] then return end
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
            v.BackgroundColor3 = isSelected and Color3.fromRGB(100, 50, 200) or (v:GetAttribute("IsSelf") and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45))
        end
    end
end

local function updateRedListUI()
    if not RedListScroll then return end
    for _, v in pairs(RedListScroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
    for path, data in pairs(ManualBannedPaths) do
        local b = Instance.new("TextButton", RedListScroll)
        b.Size = UDim2.new(1, -6, 0, 25); b.BorderSizePixel = 0
        b:SetAttribute("GUID", data.guid)
        b.BackgroundColor3 = (currentSelectionGUID == data.guid) and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(100, 35, 35)
        b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 10
        b.Text = " [X] " .. (path:match("[^%.%[%]]+$") or path)
        b.MouseButton1Click:Connect(function() 
            currentSelectionGUID = data.guid
            Details.Text = data.details 
            refreshSelectionColors()
        end)
    end
end

-- HEADER
local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 35); Header.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Header.ZIndex = 10; Header.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(0, 200, 1, 0); Title.BackgroundTransparency = 1; Title.Position = UDim2.new(0, 15, 0, 0)
Title.Text = "KRALLDEN SPY v9.5.1"; Title.TextColor3 = Color3.new(1, 1, 1); Title.Font = Enum.Font.SourceSansBold; Title.TextSize = 16; Title.TextXAlignment = 0

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
local AntiSpamBtn = createHeaderBtn("ANTI-SPAM: ON", -420, Color3.fromRGB(180, 150, 40))
AntiSpamBtn.Visible = false
local BlockBtn = createHeaderBtn("BLOCK EVENT", -530, Color3.fromRGB(150, 50, 50))
BlockBtn.Visible = false

ContentFrame = Instance.new("Frame", Main)
ContentFrame.Size = UDim2.new(1, 0, 1, -35); ContentFrame.Position = UDim2.new(0, 0, 0, 35); ContentFrame.BackgroundTransparency = 1; ContentFrame.ClipsDescendants = true

Scroll = Instance.new("ScrollingFrame", ContentFrame)
Scroll.Position = UDim2.new(0, 8, 0, 8); Scroll.Size = UDim2.new(0, 190, 1, -16); Scroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25); Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; Scroll.BorderSizePixel = 0
Instance.new("UIListLayout", Scroll).SortOrder = Enum.SortOrder.LayoutOrder

Details = Instance.new("TextBox", ContentFrame)
Details.Position = UDim2.new(0, 205, 0, 8); Details.Size = UDim2.new(0, 448, 0, 255); Details.BackgroundColor3 = Color3.fromRGB(10, 10, 12); Details.TextColor3 = Color3.new(1, 1, 1); Details.MultiLine = true; Details.TextWrapped = true; Details.TextEditable = true; Details.Font = Enum.Font.Code; Details.TextSize = 12; Details.TextXAlignment = 0; Details.TextYAlignment = 0; Details.ClearTextOnFocus = false

local BufferBtn = Instance.new("TextButton", ContentFrame)
BufferBtn.Size = UDim2.new(0, 90, 0, 20); BufferBtn.Position = UDim2.new(0, 558, 0, 12); BufferBtn.ZIndex = 15; BufferBtn.BorderSizePixel = 0
BufferBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 150); BufferBtn.Text = "BUFFER: ON"; BufferBtn.TextColor3 = Color3.new(1,1,1); BufferBtn.Font = Enum.Font.SourceSansBold; BufferBtn.TextSize = 10

local function getSafePath(obj)
    local p = ""
    pcall(function() 
        local t = obj 
        while t and t ~= game do 
            local n = tostring(t.Name)
            local sn = (n:match("^%d") or n:match("[%s%W]")) and '["'..n..'"]' or n
            p = (p == "" and sn or sn .. "." .. p)
            t = t.Parent 
        end 
    end)
    return "game." .. p:gsub("%.%[", "[")
end

local function addLog(rem, args, isSelf, typeLabel)
    if (typeLabel == "FS" and not spyFS) or (typeLabel == "FC" and not spyFC) or (typeLabel == "IS" and not spyIS) then return end
    local eventPath = getSafePath(rem)
    if not isSelf and ManualBannedPaths[eventPath] then return end

    local function parseValue(v, d)
        d = d or 0; if d > 4 then return "..." end
        local t = type(v)
        if t == "buffer" then
            if spyBuffer then
                local hex = ""
                for i = 0, math.min(buffer.len(v) - 1, 15) do hex = hex .. string.format("%02X ", buffer.readu8(v, i)) end
                return string.format("buffer(%d) [Hex: %s]", buffer.len(v), hex)
            end
            return "buffer(" .. buffer.len(v) .. ")"
        elseif t == "string" then return '"' .. v .. '"'
        elseif t == "table" then
            local res, i = "{", 0
            for k, val in pairs(v) do i = i + 1; if i > 10 then res = res .. "... " break end
                res = res .. (type(k) == "number" and "" or '["'..tostring(k)..'"] = ') .. parseValue(val, d+1) .. ", "
            end
            return res:gsub(", $", "") .. "}"
        elseif t == "userdata" then return typeof(v) == "Instance" and getSafePath(v) or tostring(v)
        else return tostring(v) end
    end

    local argList = {}
    for i, v in ipairs(args) do argList[#argList + 1] = parseValue(v) end
    local finalArgsStr = table.concat(argList, ", ")
    
    -- Блокировка дубликатов
    for _, m in ipairs(MainMemory) do
        if m.path == eventPath and m.isSelf == isSelf and (controlMode or m.argsStr == finalArgsStr) then return end
    end

    local methodName = (typeLabel == "IS" and "InvokeServer" or (typeLabel == "FC" and "FireClient" or "FireServer"))
    local logDetails = string.format("Type: %s\nPath: %s\nArgs: %s\n\nScript:\n%s:%s(%s)", typeLabel, eventPath, (finalArgsStr == "" and "None" or finalArgsStr), eventPath, methodName, finalArgsStr)

    table.insert(MainMemory, 1, { guid = generateGUID(), name = tostring(rem.Name), type = typeLabel, isSelf = isSelf, fullText = logDetails, path = eventPath, argsStr = finalArgsStr })
    if #MainMemory > 100 then table.remove(MainMemory, 101) end
end

-- HOOKS
local mt = getrawmetatable(game); local old = mt.__namecall; setreadonly(mt, false)
mt.__namecall = newcclosure(function(self, ...)
    local m = getnamecallmethod():lower(); local a = {...}; local s = checkcaller()
    if m == "fireserver" then task.spawn(addLog, self, a, s, "FS")
    elseif m == "fireclient" then task.spawn(addLog, self, a, s, "FC")
    elseif m == "invokeserver" then task.spawn(addLog, self, a, s, "IS") end
    return old(self, ...)
end); setreadonly(mt, true)

-- UI UPDATER
task.spawn(function()
    while task.wait(0.3) do
        if #MainMemory == lastCount then continue end
        lastCount = #MainMemory
        for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        for i, d in ipairs(MainMemory) do
            local b = Instance.new("TextButton", Scroll)
            b.Size = UDim2.new(1, -6, 0, 30); b.LayoutOrder = i; b.BorderSizePixel = 0
            b.Text = string.format("[%s]%s %s", d.type, (d.isSelf and " [S]" or ""), d.name)
            b:SetAttribute("GUID", d.guid); b:SetAttribute("IsSelf", d.isSelf)
            b.BackgroundColor3 = (currentSelectionGUID == d.guid) and Color3.fromRGB(100, 50, 200) or (d.isSelf and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45))
            b.TextColor3 = Color3.new(1,1,1)
            b.MouseButton1Click:Connect(function()
                currentSelectionGUID = d.guid
                Details.Text = d.fullText
                refreshSelectionColors()
            end)
        end
    end
end)

-- BUTTONS LOGIC
BufferBtn.MouseButton1Click:Connect(function()
    spyBuffer = not spyBuffer
    BufferBtn.Text = "BUFFER: " .. (spyBuffer and "ON" or "OFF")
    BufferBtn.BackgroundColor3 = spyBuffer and Color3.fromRGB(70, 70, 150) or Color3.fromRGB(80, 80, 85)
end)

ControlBtn.MouseButton1Click:Connect(function() 
    controlMode = not controlMode
    ControlBtn.Text = "CONTROL: "..(controlMode and "ON" or "OFF")
    ControlBtn.BackgroundColor3 = controlMode and Color3.fromRGB(0, 170, 190) or Color3.fromRGB(80, 80, 85)
    AntiSpamBtn.Visible = not controlMode; BlockBtn.Visible = not controlMode
end)

DelBtn.MouseButton1Click:Connect(function()
    if not currentSelectionGUID then return end
    local found = false
    for i, m in ipairs(MainMemory) do
        if m.guid == currentSelectionGUID then table.remove(MainMemory, i); found = true break end
    end
    if not found then
        for p, d in pairs(ManualBannedPaths) do
            if d.guid == currentSelectionGUID then ManualBannedPaths[p] = nil; updateRedListUI() break end
        end
    end
    currentSelectionGUID = nil; Details.Text = ""; lastCount = -1; feedback(DelBtn, "DELETED")
end)

local function createBotBtn(text, pos, size, color)
    local b = Instance.new("TextButton", ContentFrame); b.Size = size or UDim2.new(0, 220, 0, 58); b.Position = pos; b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 14; b.BorderSizePixel = 0; return b
end

createBotBtn("COPY ARGS", UDim2.new(0, 205, 0.68, 0), nil, Color3.fromRGB(45, 90, 45)).MouseButton1Click:Connect(function() 
    local a = Details.Text:match("Args: (.-)\n\nScript"); if a then setclipboard(a) end
end)

createBotBtn("COPY SCRIPT", UDim2.new(0, 205, 0.83, 0), nil, Color3.fromRGB(60, 60, 120)).MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)"); if s then setclipboard(s) end
end)

createBotBtn("CLEAR LOG", UDim2.new(0, 432, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(80, 80, 85)).MouseButton1Click:Connect(function()
    local nM = {}; for _, m in ipairs(MainMemory) do if m.isSelf then table.insert(nM, m) end end
    MainMemory = nM; lastCount = -1; Details.Text = ""
end)

createBotBtn("CLEAR SELF", UDim2.new(0, 544, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(100, 80, 60)).MouseButton1Click:Connect(function()
    local nM = {}; for _, m in ipairs(MainMemory) do if not m.isSelf then table.insert(nM, m) end end
    MainMemory = nM; lastCount = -1; Details.Text = ""
end)

createBotBtn("EXECUTE", UDim2.new(0, 432, 0.83, 0), nil, Color3.fromRGB(120, 60, 60)).MouseButton1Click:Connect(function() 
    local s = Details.Text:match("Script:\n(.*)"); if s then loadstring(s)() end 
end)

SelfBtn.MouseButton1Click:Connect(function() 
    selfMode = not selfMode; lastCount = -1
    SelfBtn.Text = "SELF: "..(selfMode and "ON" or "OFF")
    SelfBtn.BackgroundColor3 = selfMode and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(150, 50, 50) 
end)

local function createTypeBtn(text, pos, color, varName)
    local b = Instance.new("TextButton", ContentFrame); b.Size = UDim2.new(0, 150, 0, 35); b.Position = pos; b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 12; b.BorderSizePixel = 0
    b.MouseButton1Click:Connect(function()
        if varName == "FS" then spyFS = not spyFS elseif varName == "FC" then spyFC = not spyFC else spyIS = not spyIS end
        local st = (varName == "FS" and spyFS or varName == "FC" and spyFC or spyIS)
        b.Text = varName.." SPY: "..(st and "ON" or "OFF"); b.BackgroundColor3 = st and color or Color3.fromRGB(40, 40, 45)
    end)
end
createTypeBtn("FS SPY: ON", UDim2.new(0, 662, 0, 8), Color3.fromRGB(130, 70, 220), "FS")
createTypeBtn("FC SPY: OFF", UDim2.new(0, 662, 0, 48), Color3.fromRGB(50, 150, 255), "FC")
createTypeBtn("IS SPY: OFF", UDim2.new(0, 662, 0, 88), Color3.fromRGB(255, 150, 50), "IS")
