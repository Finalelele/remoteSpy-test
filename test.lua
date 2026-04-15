-- [[ KRALLDEN SPY v9.5.0 - FULL SOURCE RESTORED ]] --

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Полная очистка интерфейсов
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
ScreenGui.Name = "KralldenSpyUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 10
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Цикл защиты от скрытия UI
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

-- Глобальные переменные и состояния
local MainMemory = {}
local ManualBannedPaths = {}
local AntiSpamCooldowns = {}
local AntiSpamCounts = {}
local selfMode = true
local controlMode = true
local antiSpam = true
local spyFS = true
local spyFC = false
local spyIS = false
local sortEnabled = false
local currentSelectionGUID = nil
local lastCount = 0
local isMin = false

local function generateGUID()
    return tostring(tick()) .. "-" .. tostring(math.random(1, 100000))
end

local RedListScroll, Scroll, Details, ContentFrame, DetailsScroll

-- [[ ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ФОРМАТИРОВАНИЯ ]] --

local function getSafePath(obj)
    local path = ""
    local success, err = pcall(function()
        local temp = obj
        while temp and temp ~= game do
            local name = tostring(temp.Name)
            local safeName = (name:match("^%d") or name:match("[%s%W]")) and '["'..name..'"]' or name
            if path == "" then
                path = safeName
            else
                if safeName:sub(1,1) == "[" then
                    path = safeName .. "." .. path
                else
                    path = safeName .. "." .. path
                end
            end
            temp = temp.Parent
        end
    end)
    local final = "game." .. path
    return final:gsub("%.%[", "[")
end

-- Функция для визуального отображения (SORT: ON)
local function formatTableVisual(val, indent)
    indent = indent or 0
    local tab = string.rep("    ", indent)
    local t = typeof(val)
    
    if t == "table" then
        local res = "{\n"
        for k, v in pairs(val) do
            local keyStr = type(k) == "string" and k or "[" .. tostring(k) .. "]"
            res = res .. tab .. "    " .. keyStr .. " = " .. formatTableVisual(v, indent + 1) .. ",\n"
        end
        return res .. tab .. "}"
    elseif t == "string" then
        return '"' .. val .. '"'
    elseif t == "Vector3" then
        return string.format("Vector3.new(%.3f, %.3f, %.3f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then
        return "CFrame.new(" .. tostring(val) .. ")"
    elseif t == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", val.R*255, val.G*255, val.B*255)
    elseif t == "Instance" then
        return getSafePath(val)
    else
        return tostring(val)
    end
end

-- Функция для генерации чистого кода (Script)
local function parseRaw(v, depth)
    depth = depth or 0
    if depth > 8 then return "..." end
    local t = typeof(v)
    if t == "string" then
        return '"' .. v .. '"'
    elseif t == "table" then
        local res = "{"
        local i = 0
        for k, val in pairs(v) do
            i = i + 1
            if i > 15 then res = res .. "... " break end
            local key = type(k) == "number" and "" or '["'..tostring(k)..'"] = '
            res = res .. key .. parseRaw(val, depth + 1) .. ", "
        end
        return res:gsub(", $", "") .. "}"
    elseif t == "Instance" then
        return getSafePath(v)
    elseif t == "CFrame" then
        return "CFrame.new(" .. tostring(v) .. ")"
    elseif t == "Vector3" then
        return "Vector3.new(" .. tostring(v) .. ")"
    elseif t == "Color3" then
        return "Color3.new(" .. tostring(v) .. ")"
    else
        return tostring(v)
    end
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

-- [[ ИНТЕРФЕЙС - ЗАГОЛОВОК ]] --

local Header = Instance.new("Frame", Main)
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
Header.BorderSizePixel = 0
Header.ZIndex = 10

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(0, 200, 1, 0)
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 15, 0, 0)
Title.Text = "KRALLDEN SPY v9.5.0"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.TextXAlignment = 0

local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.new(0, 45, 0, 35)
MinBtn.Position = UDim2.new(1, -45, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 180)
MinBtn.Text = "_"
MinBtn.TextColor3 = Color3.new(1, 1, 1)
MinBtn.TextSize = 22
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

-- [[ КОНТЕНТ ]] --

ContentFrame = Instance.new("Frame", Main)
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
Scroll.ScrollBarThickness = 4
local ScrollList = Instance.new("UIListLayout", Scroll)
ScrollList.SortOrder = Enum.SortOrder.LayoutOrder

-- Поле деталей с вертикальным скроллом
DetailsScroll = Instance.new("ScrollingFrame", ContentFrame)
DetailsScroll.Position = UDim2.new(0, 205, 0, 8)
DetailsScroll.Size = UDim2.new(0, 448, 0, 255)
DetailsScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
DetailsScroll.BorderSizePixel = 0
DetailsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
DetailsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
DetailsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
DetailsScroll.ScrollBarThickness = 4

Details = Instance.new("TextBox", DetailsScroll)
Details.Size = UDim2.new(1, -10, 1, 0)
Details.BackgroundTransparency = 1
Details.TextColor3 = Color3.new(1, 1, 1)
Details.MultiLine = true
Details.TextWrapped = true
Details.TextEditable = true
Details.Font = Enum.Font.Code
Details.TextSize = 12
Details.TextXAlignment = 0
Details.TextYAlignment = 0
Details.ClearTextOnFocus = false

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
RedListScroll.ScrollBarThickness = 2
Instance.new("UIListLayout", RedListScroll).SortOrder = Enum.SortOrder.LayoutOrder

-- [[ ЛОГИКА ОБНОВЛЕНИЯ UI ]] --

local function updateDetailsText(data)
    if not data then return end
    
    local displayArgs = ""
    if sortEnabled then
        displayArgs = formatTableVisual(data.rawArgs)
    else
        displayArgs = (data.argsStr == "" and "None" or data.argsStr)
    end
    
    -- Script всегда генерируется без unpack
    local scriptCode = string.format("%s:%s(%s)", data.path, data.method, data.argsStr)
    
    Details.Text = string.format("Type: %s\n\nPath: %s\n\nArgs: %s\n\nScript:\n%s", 
        data.type, data.path, displayArgs, scriptCode)
end

local function refreshSelectionColors()
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

local function updateRedListUI()
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
            Details.Text = data.details
            refreshSelectionColors()
        end)
    end
end

-- [[ ЯДРО ПЕРЕХВАТА ]] --

local function addLog(remote, args, isSelf, typeLabel)
    if (typeLabel == "FS" and not spyFS) or (typeLabel == "FC" and not spyFC) or (typeLabel == "IS" and not spyIS) then return end
    
    local eventPath = getSafePath(remote)
    if not isSelf and ManualBannedPaths[eventPath] then return end

    local argList = {}
    for _, v in ipairs(args) do
        table.insert(argList, parseRaw(v))
    end
    local argsStr = table.concat(argList, ", ")

    -- Дубликаты
    for _, m in ipairs(MainMemory) do
        if m.path == eventPath and m.isSelf == isSelf then
            if isSelf then
                if selfMode or m.argsStr == argsStr then return end
            else
                if controlMode or m.argsStr == argsStr then return end
            end
        end
    end

    local method = (typeLabel == "IS" and "InvokeServer" or (typeLabel == "FC" and "FireClient" or "FireServer"))
    
    -- Anti-Spam логика
    if not isSelf and not controlMode and antiSpam then
        local now = tick()
        if (now - (AntiSpamCooldowns[eventPath] or 0)) < 0.4 then
            AntiSpamCounts[eventPath] = (AntiSpamCounts[eventPath] or 0) + 1
            if AntiSpamCounts[eventPath] >= 4 then
                ManualBannedPaths[eventPath] = {
                    guid = generateGUID(), 
                    details = "AUTO-BANNED (SPAM DETECTED)\nPath: "..eventPath
                }
                local nM = {}
                for _, m in ipairs(MainMemory) do if m.path ~= eventPath or m.isSelf then table.insert(nM, m) end end
                MainMemory = nM; lastCount = -1; updateRedListUI(); return
            end
        else
            AntiSpamCounts[eventPath] = 0
        end
        AntiSpamCooldowns[eventPath] = now
    end

    local data = {
        guid = generateGUID(),
        name = tostring(remote.Name),
        type = typeLabel,
        isSelf = isSelf,
        path = eventPath,
        argsStr = argsStr,
        rawArgs = args,
        method = method
    }
    
    table.insert(MainMemory, 1, data)
    if #MainMemory > 250 then table.remove(MainMemory, #MainMemory) end
end

local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod():lower()
    local args = {...}
    local isSelf = checkcaller()
    
    if method == "fireserver" then
        task.spawn(addLog, self, args, isSelf, "FS")
    elseif method == "fireclient" then
        task.spawn(addLog, self, args, isSelf, "FC")
    elseif method == "invokeserver" then
        task.spawn(addLog, self, args, isSelf, "IS")
    end
    
    return oldNamecall(self, ...)
end)
setreadonly(mt, true)

-- [[ КНОПКИ УПРАВЛЕНИЯ ]] --

ControlBtn.MouseButton1Click:Connect(function() 
    controlMode = not controlMode
    ControlBtn.Text = "CONTROL: "..(controlMode and "ON" or "OFF")
    ControlBtn.BackgroundColor3 = controlMode and Color3.fromRGB(0, 170, 190) or Color3.fromRGB(80, 80, 85)
    AntiSpamBtn.Visible = not controlMode
    BlockBtn.Visible = not controlMode
    lastCount = -1 
end)

DelBtn.MouseButton1Click:Connect(function()
    if not currentSelectionGUID then return end
    -- Проверка в бан-листе
    for p, d in pairs(ManualBannedPaths) do
        if d.guid == currentSelectionGUID then
            ManualBannedPaths[p] = nil
            updateRedListUI()
            feedback(DelBtn, "UNBANNED")
            return
        end
    end
    -- Удаление из лога
    local nM = {}
    for _, m in ipairs(MainMemory) do
        if m.guid ~= currentSelectionGUID then table.insert(nM, m) end
    end
    MainMemory = nM
    lastCount = -1
    currentSelectionGUID = nil
    Details.Text = ""
    feedback(DelBtn, "DELETED")
end)

BlockBtn.MouseButton1Click:Connect(function()
    if not currentSelectionGUID then return end
    for _, d in ipairs(MainMemory) do
        if d.guid == currentSelectionGUID and not d.isSelf then
            ManualBannedPaths[d.path] = {
                guid = d.guid,
                details = "MANUALLY BANNED\nPath: " .. d.path
            }
            local nM = {}
            for _, m in ipairs(MainMemory) do if m.path ~= d.path or m.isSelf then table.insert(nM, m) end end
            MainMemory = nM; lastCount = -1; updateRedListUI(); feedback(BlockBtn, "BLOCKED")
            break
        end
    end
end)

MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    local curX, curY = Main.AbsolutePosition.X + Main.AbsoluteSize.X, Main.AbsolutePosition.Y
    if isMin then
        ContentFrame.Visible = false
        Main:TweenSizeAndPosition(UDim2.new(0, 250, 0, 35), UDim2.new(0, curX - 250, 0, curY), "Out", "Quad", 0.15, true)
        MinBtn.Text = "+"
    else
        Main:TweenSizeAndPosition(UDim2.new(0, 820, 0, 440), UDim2.new(0, curX - 820, 0, curY), "Out", "Quad", 0.15, true, function()
            ContentFrame.Visible = true
            lastCount = -1
        end)
        MinBtn.Text = "_"
    end
end)

-- Рендер лога
task.spawn(function()
    while task.wait(0.5) do
        if not ContentFrame.Visible or #MainMemory == lastCount then continue end
        lastCount = #MainMemory
        for _, v in pairs(Scroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        
        for i, d in ipairs(MainMemory) do
            local b = Instance.new("TextButton", Scroll)
            b.Size = UDim2.new(1, -6, 0, 30)
            b.LayoutOrder = i
            b.Text = string.format("[%s]%s %s", d.type, (d.isSelf and " [S]" or ""), d.name)
            b:SetAttribute("GUID", d.guid)
            b:SetAttribute("IsSelf", d.isSelf)
            b.BackgroundColor3 = (currentSelectionGUID == d.guid) and Color3.fromRGB(100, 50, 200) or (d.isSelf and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(40, 40, 45))
            b.TextColor3 = Color3.new(1,1,1); b.BorderSizePixel = 0
            b.MouseButton1Click:Connect(function()
                currentSelectionGUID = d.guid
                updateDetailsText(d)
                refreshSelectionColors()
            end)
        end
    end
end)

-- Нижние кнопки
local function createBotBtn(text, pos, size, color)
    local b = Instance.new("TextButton", ContentFrame)
    b.Size = size or UDim2.new(0, 220, 0, 58)
    b.Position = pos
    b.BackgroundColor3 = color
    b.Text = text; b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.SourceSansBold; b.TextSize = 14; b.BorderSizePixel = 0
    return b
end

local CopyArgsBtn = createBotBtn("COPY ARGS", UDim2.new(0, 205, 0.68, 0), UDim2.new(0, 95, 0, 58), Color3.fromRGB(45, 90, 45))
CopyArgsBtn.MouseButton1Click:Connect(function()
    local argText = Details.Text:match("Args: (.*)\n\nScript")
    if argText then setclipboard(argText); feedback(CopyArgsBtn, "COPIED") end
end)

local SortBtn = createBotBtn("SORT: OFF", UDim2.new(0, 305, 0.68, 0), UDim2.new(0, 120, 0, 58), Color3.fromRGB(130, 70, 220))
SortBtn.MouseButton1Click:Connect(function()
    sortEnabled = not sortEnabled
    SortBtn.Text = "SORT: " .. (sortEnabled and "ON" or "OFF")
    SortBtn.BackgroundColor3 = sortEnabled and Color3.fromRGB(100, 50, 200) or Color3.fromRGB(130, 70, 220)
    if currentSelectionGUID then
        for _, m in ipairs(MainMemory) do if m.guid == currentSelectionGUID then updateDetailsText(m) break end end
    end
end)

local CopyScriptBtn = createBotBtn("COPY SCRIPT", UDim2.new(0, 205, 0.83, 0), nil, Color3.fromRGB(60, 60, 120))
CopyScriptBtn.MouseButton1Click:Connect(function()
    local scriptText = Details.Text:match("Script:\n(.*)")
    if scriptText then setclipboard(scriptText); feedback(CopyScriptBtn, "COPIED") end
end)

local ClearLogBtn = createBotBtn("CLEAR LOG", UDim2.new(0, 432, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(80, 80, 85))
ClearLogBtn.MouseButton1Click:Connect(function()
    local nM = {}
    for _, m in ipairs(MainMemory) do if m.isSelf then table.insert(nM, m) end end
    MainMemory = nM; lastCount = -1; feedback(ClearLogBtn, "CLEARED")
end)

local ClearSelfBtn = createBotBtn("CLEAR SELF", UDim2.new(0, 544, 0.68, 0), UDim2.new(0, 108, 0, 58), Color3.fromRGB(100, 80, 60))
ClearSelfBtn.MouseButton1Click:Connect(function()
    local nM = {}
    for _, m in ipairs(MainMemory) do if not m.isSelf then table.insert(nM, m) end end
    MainMemory = nM; lastCount = -1; feedback(ClearSelfBtn, "CLEARED")
end)

local ExecuteBtn = createBotBtn("EXECUTE", UDim2.new(0, 432, 0.83, 0), nil, Color3.fromRGB(120, 60, 60))
ExecuteBtn.MouseButton1Click:Connect(function()
    local code = Details.Text:match("Script:\n(.*)") or Details.Text
    if code and code ~= "" then
        local func, err = loadstring(code)
        if func then task.spawn(func); feedback(ExecuteBtn, "SUCCESS") else feedback(ExecuteBtn, "ERROR") end
    end
end)

-- Сайд-бар кнопки типов
local function createTypeBtn(text, pos, state, color, typeKey)
    local b = Instance.new("TextButton", ContentFrame)
    b.Size = UDim2.new(0, 150, 0, 35)
    b.Position = pos
    b.BackgroundColor3 = state and color or Color3.fromRGB(40, 40, 45)
    b.Text = text; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.SourceSansBold; b.TextSize = 12; b.BorderSizePixel = 0
    b.MouseButton1Click:Connect(function()
        if typeKey == "FS" then spyFS = not spyFS elseif typeKey == "FC" then spyFC = not spyFC else spyIS = not spyIS end
        local newState = (typeKey == "FS" and spyFS or typeKey == "FC" and spyFC or spyIS)
        b.Text = typeKey.." SPY: "..(newState and "ON" or "OFF")
        b.BackgroundColor3 = newState and color or Color3.fromRGB(40, 40, 45)
    end)
end

createTypeBtn("FS SPY: ON", UDim2.new(0, 662, 0, 8), spyFS, Color3.fromRGB(130, 70, 220), "FS")
createTypeBtn("FC SPY: OFF", UDim2.new(0, 662, 0, 48), spyFC, Color3.fromRGB(50, 150, 255), "FC")
createTypeBtn("IS SPY: OFF", UDim2.new(0, 662, 0, 88), spyIS, Color3.fromRGB(255, 150, 50), "IS")

SelfBtn.MouseButton1Click:Connect(function()
    selfMode = not selfMode
    SelfBtn.Text = "SELF: "..(selfMode and "ON" or "OFF")
    SelfBtn.BackgroundColor3 = selfMode and Color3.fromRGB(45, 90, 45) or Color3.fromRGB(150, 50, 50)
    lastCount = -1
end)

AntiSpamBtn.MouseButton1Click:Connect(function()
    antiSpam = not antiSpam
    AntiSpamBtn.Text = "ANTI-SPAM: "..(antiSpam and "ON" or "OFF")
    AntiSpamBtn.BackgroundColor3 = antiSpam and Color3.fromRGB(180, 150, 40) or Color3.fromRGB(80, 80, 85)
end)
