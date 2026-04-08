-- QuantumSpy v2.5 (Script + AntiSpam)
local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("QuantumSpyUI") then 
    playerGui.QuantumSpyUI:Destroy() 
end

local ScreenGui = Instance.new("ScreenGui", playerGui)
ScreenGui.Name = "QuantumSpyUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999999 

local Main = Instance.new("Frame", ScreenGui)
Main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Main.Position = UDim2.new(0.5, -200, 0.5, -150)
Main.Size = UDim2.new(0, 400, 0, 300)
Main.Active = true
Main.Draggable = true 

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Text = "QUANTUM SPY v2.5"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)

local Scroll = Instance.new("ScrollingFrame", Main)
Scroll.Position = UDim2.new(0, 5, 0, 35)
Scroll.Size = UDim2.new(0, 150, 1, -40)
Scroll.CanvasSize = UDim2.new(0, 0, 50, 0)
Scroll.ScrollBarThickness = 3
Instance.new("UIListLayout", Scroll).SortOrder = Enum.SortOrder.LayoutOrder

local Details = Instance.new("TextBox", Main)
Details.Position = UDim2.new(0, 160, 0, 35)
Details.Size = UDim2.new(1, -165, 0.7, 0)
Details.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Details.TextColor3 = Color3.new(0.8, 0.8, 0.8)
Details.MultiLine = true
Details.TextXAlignment = 0
Details.TextYAlignment = 0
Details.Text = "Ожидание событий..."
Details.ClearTextOnFocus = false
Details.TextWrapped = true

local CopyArgs = Instance.new("TextButton", Main)
CopyArgs.Position = UDim2.new(0, 160, 0.75, 5)
CopyArgs.Size = UDim2.new(0.5, -5, 0.1, 0)
CopyArgs.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
CopyArgs.Text = "COPY ARGS"
CopyArgs.TextColor3 = Color3.new(1, 1, 1)

local CopyScript = Instance.new("TextButton", Main)
CopyScript.Position = UDim2.new(0.5, 0, 0.75, 5)
CopyScript.Size = UDim2.new(0.5, -5, 0.1, 0)
CopyScript.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
CopyScript.Text = "COPY SCRIPT"
CopyScript.TextColor3 = Color3.new(1, 1, 1)

-- хранение уникальных вызовов
local logged = {}

local function argsToString(args)
    local str = ""
    for i, v in pairs(args) do
        if typeof(v) == "string" then
            str = str .. '"'..v..'"'
        else
            str = str .. tostring(v)
        end
        if i < #args then
            str = str .. ", "
        end
    end
    return str
end

local currentScript = ""

local function addLog(rem, args)
    local key = rem:GetFullName() .. "|" .. argsToString(args)

    if logged[key] then return end
    logged[key] = true

    local b = Instance.new("TextButton", Scroll)
    b.Size = UDim2.new(1, 0, 0, 25)
    b.Text = rem.Name
    b.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    b.TextColor3 = Color3.new(1, 1, 1)

    b.MouseButton1Click:Connect(function()
        local path = rem:GetFullName()
        local argText = ""

        for i, v in pairs(args) do 
            argText = argText .. "\n["..i.."] ("..typeof(v).."): "..tostring(v) 
        end

        local scriptCall = path .. ":FireServer(" .. argsToString(args) .. ")"
        currentScript = scriptCall

        Details.Text = "Path: "..path.."\n\nArgs:"..argText.."\n\nScript:\n"..scriptCall
    end)
end

CopyArgs.MouseButton1Click:Connect(function() 
    setclipboard(Details.Text) 
    CopyArgs.Text = "COPIED!"
    task.wait(1)
    CopyArgs.Text = "COPY ARGS"
end)

CopyScript.MouseButton1Click:Connect(function()
    setclipboard(currentScript)
    CopyScript.Text = "COPIED!"
    task.wait(1)
    CopyScript.Text = "COPY SCRIPT"
end)

local mt = getrawmetatable(game)
local old = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local m = getnamecallmethod()
    if (m == "FireServer" or m == "fireServer") and not checkcaller() then
        addLog(self, {...})
    end
    return old(self, ...)
end)

setreadonly(mt, true)
