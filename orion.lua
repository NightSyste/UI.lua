local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer
local Mouse             = LocalPlayer:GetMouse()

-- ── Tween helpers ──────────────────────────────────────────
local function T(obj, dur, style, dir, props)
    style = style or Enum.EasingStyle.Quint
    dir   = dir   or Enum.EasingDirection.Out
    TweenService:Create(obj, TweenInfo.new(dur, style, dir), props):Play()
end

local Library = {
    Elements     = {},
    ThemeObjects = {},
    Connections  = {},
    Flags        = {},
    Themes = {
        Default = {
            BgDeep   = Color3.fromRGB(6,   7,  14),
            BgPanel  = Color3.fromRGB(10,  11,  22),
            BgCard   = Color3.fromRGB(16,  18,  34),
            BgInput  = Color3.fromRGB(9,   10,  22),
            BorderDim  = Color3.fromRGB(38,  44,  88),
            BorderGlow = Color3.fromRGB(70,  90, 200),
            BorderPop  = Color3.fromRGB(100, 130, 255),
            TextHi   = Color3.fromRGB(230, 235, 255),
            TextMid  = Color3.fromRGB(155, 168, 220),
            TextLow  = Color3.fromRGB(75,   88, 150),
            AccentA  = Color3.fromRGB(80,  115, 255),
            AccentB  = Color3.fromRGB(130,  75, 255),
            AccentC  = Color3.fromRGB(40,  190, 210),
            Main    = Color3.fromRGB(6,   7,  14),
            Second  = Color3.fromRGB(16,  18,  34),
            Stroke  = Color3.fromRGB(38,  44,  88),
            Divider = Color3.fromRGB(22,  25,  45),
            Text    = Color3.fromRGB(230, 235, 255),
            TextDark= Color3.fromRGB(75,   88, 150),
        }
    },
    SelectedTheme = "Default",
    Folder  = nil,
    SaveCfg = false,
    Font    = Enum.Font.Gotham,
}

function Library:CleanupInstance()
    for _, inst in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if inst:IsA("ScreenGui") and inst.Name:match("^[A-Z]%d%d%d$") then
            inst:Destroy()
        end
    end
end

Library:CleanupInstance()

local Container = Instance.new("ScreenGui")
Container.Name           = string.char(math.random(65,90))..tostring(math.random(100,999))
Container.DisplayOrder   = 2147483647
Container.Parent         = game:GetService("CoreGui")

function Library:IsRunning()
    return Container and Container.Parent == game:GetService("CoreGui")
end

local function AddConnection(signal, fn)
    if not Library:IsRunning() then return end
    local c = signal:Connect(fn)
    table.insert(Library.Connections, c)
    return c
end

task.spawn(function()
    while Library:IsRunning() do task.wait() end
    for _, c in ipairs(Library.Connections) do c:Disconnect() end
end)

local function MakeDraggable(DragPoint, Main)
    local resizing = false
    pcall(function()
        local dragging, dragInput, mousePos, framePos
        DragPoint.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                if resizing then return end
                dragging = true
                mousePos = inp.Position
                framePos = Main.Position
                inp.Changed:Connect(function()
                    if inp.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        DragPoint.InputChanged:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseMovement then dragInput = inp end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if inp == dragInput and dragging and not resizing then
                local d = inp.Position - mousePos
                T(Main, 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {
                    Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + d.X,
                                         framePos.Y.Scale, framePos.Y.Offset + d.Y)
                })
            end
        end)
    end)
    return function(r) resizing = r end
end

local function MakeResizable(ResizeBtn, Main, MinSz, MaxSz, Cb)
    pcall(function()
        local active, startSz, startPos = false
        ResizeBtn.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                active  = true
                startSz = Main.Size
                startPos = Vector2.new(Mouse.X, Mouse.Y)
                if Cb then Cb(true) end
            end
        end)
        ResizeBtn.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                active = false
                if Cb then Cb(false) end
            end
        end)
        UserInputService.InputChanged:Connect(function()
            if active then
                local d  = Vector2.new(Mouse.X, Mouse.Y) - startPos
                local nw = math.clamp(startSz.X.Offset + d.X, MinSz.X, MaxSz.X)
                local nh = math.clamp(startSz.Y.Offset + d.Y, MinSz.Y, MaxSz.Y)
                Main.Size = UDim2.new(0, nw, 0, nh)
            end
        end)
    end)
end

local function Create(name, props, children)
    local obj = Instance.new(name)
    for k,v in pairs(props or {}) do obj[k] = v end
    for _,c in pairs(children or {}) do c.Parent = obj end
    return obj
end

local function CreateElement(name, fn) Library.Elements[name] = fn end
local function MakeElement(name, ...) return Library.Elements[name](...) end

local function SetProps(el, props)
    for k,v in pairs(props) do el[k] = v end
    return el
end
local function SetChildren(el, children)
    for _,c in pairs(children) do c.Parent = el end
    return el
end

local function Round(n, f)
    local r = math.floor(n/f + math.sign(n)*0.5)*f
    if r < 0 then r = r + f end
    return r
end

local function ReturnProperty(obj)
    if obj:IsA("Frame") or obj:IsA("TextButton")  then return "BackgroundColor3" end
    if obj:IsA("ScrollingFrame")                   then return "ScrollBarImageColor3" end
    if obj:IsA("UIStroke")                         then return "Color" end
    if obj:IsA("TextLabel") or obj:IsA("TextBox")  then return "TextColor3" end
    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then return "ImageColor3" end
end

local function AddThemeObject(obj, t)
    Library.ThemeObjects[t] = Library.ThemeObjects[t] or {}
    table.insert(Library.ThemeObjects[t], obj)
    obj[ReturnProperty(obj)] = Library.Themes[Library.SelectedTheme][t]
    return obj
end

local function PackColor(c)   return {R=c.R*255, G=c.G*255, B=c.B*255} end
local function UnpackColor(c) return Color3.fromRGB(c.R, c.G, c.B)     end

local function LoadCfg(raw)
    -- FIX: pcall um JSONDecode damit korrupte Configs nicht crashen
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(raw)
    end)
    if not ok then return end
    for k,v in pairs(data) do
        if Library.Flags[k] then
            spawn(function()
                pcall(function()
                    if Library.Flags[k].Type == "Colorpicker" then
                        Library.Flags[k]:Set(UnpackColor(v))
                    else
                        Library.Flags[k]:Set(v)
                    end
                end)
            end)
        end
    end
end

local function SaveCfg() end

local WhitelistedMouse = {
    Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2,
    Enum.UserInputType.MouseButton3, Enum.UserInputType.Touch
}
local BlacklistedKeys  = {
    Enum.KeyCode.Unknown, Enum.KeyCode.W, Enum.KeyCode.A,
    Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up,
    Enum.KeyCode.Left, Enum.KeyCode.Down, Enum.KeyCode.Right,
    Enum.KeyCode.Slash, Enum.KeyCode.Tab, Enum.KeyCode.Backspace,
    Enum.KeyCode.Escape
}
local function CheckKey(tbl, key)
    for _,v in ipairs(tbl) do if v == key then return true end end
end

CreateElement("Corner", function(scale, offset)
    return Create("UICorner", {CornerRadius = UDim.new(scale or 0, offset or 8)})
end)

CreateElement("Stroke", function(color, thickness)
    return Create("UIStroke", {Color = color or Color3.fromRGB(38,44,88), Thickness = thickness or 1})
end)

CreateElement("List", function(scale, offset)
    return Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding   = UDim.new(scale or 0, offset or 0)
    })
end)

CreateElement("Padding", function(b, l, r, t)
    return Create("UIPadding", {
        PaddingBottom = UDim.new(0, b or 4),
        PaddingLeft   = UDim.new(0, l or 4),
        PaddingRight  = UDim.new(0, r or 4),
        PaddingTop    = UDim.new(0, t or 4),
    })
end)

CreateElement("TFrame", function()
    return Create("Frame", {BackgroundTransparency = 1})
end)

CreateElement("Frame", function(color)
    return Create("Frame", {
        BackgroundColor3 = color or Color3.fromRGB(255,255,255),
        BorderSizePixel  = 0
    })
end)

CreateElement("RoundFrame", function(color, scale, offset)
    return Create("Frame", {
        BackgroundColor3 = color or Color3.fromRGB(255,255,255),
        BorderSizePixel  = 0
    }, {Create("UICorner", {CornerRadius = UDim.new(scale or 0, offset or 8)})})
end)

CreateElement("Button", function()
    return Create("TextButton", {
        Text                   = "",
        AutoButtonColor        = false,
        BackgroundTransparency = 1,
        BorderSizePixel        = 0
    })
end)

CreateElement("ScrollFrame", function(color, width)
    return Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        MidImage               = "rbxassetid://7445543667",
        BottomImage            = "rbxassetid://7445543667",
        TopImage               = "rbxassetid://7445543667",
        ScrollBarImageColor3   = color or Color3.fromRGB(80,110,210),
        BorderSizePixel        = 0,
        ScrollBarThickness     = width or 3,
        CanvasSize             = UDim2.new(0,0,0,0)
    })
end)

CreateElement("Image", function(id)
    return Create("ImageLabel", {Image = id or "", BackgroundTransparency = 1})
end)

CreateElement("ImageButton", function(id)
    return Create("ImageButton", {Image = id or "", BackgroundTransparency = 1})
end)

-- FIX: Text wird immer zu String konvertiert → kein "string expected, got number" mehr
CreateElement("Label", function(text, size, transp)
    return Create("TextLabel", {
        Text                   = tostring(text or ""),
        TextColor3             = Color3.fromRGB(230,235,255),
        TextTransparency       = transp or 0,
        TextSize               = size or 14,
        Font                   = Enum.Font.GothamSemibold,
        RichText               = true,
        BackgroundTransparency = 1,
        TextXAlignment         = Enum.TextXAlignment.Left,
    })
end)

local function GlassCard(size, parent, alpha)
    alpha = alpha or 0.55
    local f = Create("Frame", {
        Size                   = size,
        BackgroundColor3       = Color3.fromRGB(14, 16, 32),
        BackgroundTransparency = alpha,
        BorderSizePixel        = 0,
        Parent                 = parent,
    }, {
        Create("UICorner", {CornerRadius = UDim.new(0, 8)}),
        Create("UIStroke",  {
            Color        = Color3.fromRGB(60, 75, 170),
            Thickness    = 1,
            Transparency = 0.45,
        }),
    })
    return f
end

local NotifHolder = SetProps(SetChildren(MakeElement("TFrame"), {
    SetProps(MakeElement("List"), {
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder           = Enum.SortOrder.LayoutOrder,
        VerticalAlignment   = Enum.VerticalAlignment.Bottom,
        Padding             = UDim.new(0, 8),
    })
}), {
    Position    = UDim2.new(1, -20, 1, -20),
    Size        = UDim2.new(0, 310, 1, -20),
    AnchorPoint = Vector2.new(1, 1),
    Parent      = Container,
})

function Library:MakeNotification(cfg)
    spawn(function()
        cfg.Name    = tostring(cfg.Name    or "Notice")
        cfg.Content = tostring(cfg.Content or "")
        cfg.Image   = cfg.Image   or "rbxassetid://4384403532"
        cfg.Time    = cfg.Time    or 8

        local wrap = SetProps(MakeElement("TFrame"), {
            Size          = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent        = NotifHolder,
        })

        local accentBar = Create("Frame", {
            Size             = UDim2.new(0, 3, 1, -16),
            Position         = UDim2.new(0, 0, 0, 8),
            BackgroundColor3 = Color3.fromRGB(100, 130, 255),
            BorderSizePixel  = 0,
        }, {
            Create("UICorner",   {CornerRadius = UDim.new(1, 0)}),
            Create("UIGradient", {
                Color    = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 160, 255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(100,  60, 220)),
                }),
                Rotation = 90,
            }),
        })

        local card = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(10,11,22), 0, 10), {
            Parent                 = wrap,
            Size                   = UDim2.new(1, 0, 0, 0),
            Position               = UDim2.new(1, 10, 0, 0),
            BackgroundTransparency = 0.38,
            AutomaticSize          = Enum.AutomaticSize.Y,
        }), {
            Create("UIStroke", {
                Color        = Color3.fromRGB(65, 85, 195),
                Thickness    = 1,
                Transparency = 0.35,
                Name         = "Border",
            }),
            MakeElement("Padding", 12, 14, 14, 12),
            accentBar,
            SetProps(MakeElement("Image", cfg.Image), {
                Size        = UDim2.new(0, 18, 0, 18),
                Position    = UDim2.new(0, 18, 0, 0),
                ImageColor3 = Color3.fromRGB(130, 160, 255),
                Name        = "Icon",
            }),
            SetProps(MakeElement("Label", cfg.Name, 14), {
                Size      = UDim2.new(1, -38, 0, 18),
                Position  = UDim2.new(0, 38, 0, 0),
                Font      = Enum.Font.GothamBold,
                TextColor3= Color3.fromRGB(220, 228, 255),
                Name      = "Title",
            }),
            SetProps(MakeElement("Label", cfg.Content, 12), {
                Size          = UDim2.new(1, -4, 0, 0),
                Position      = UDim2.new(0, 0, 0, 24),
                Font          = Enum.Font.Gotham,
                TextColor3    = Color3.fromRGB(120, 140, 210),
                AutomaticSize = Enum.AutomaticSize.Y,
                TextWrapped   = true,
                Name          = "Body",
            }),
        })

        T(card, 0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {
            Position = UDim2.new(0, 0, 0, 0)
        })

        task.wait(cfg.Time - 0.9)

        T(card,        0.55, Enum.EasingStyle.Quint, nil, {BackgroundTransparency = 0.85})
        T(card.Border, 0.55, Enum.EasingStyle.Quint, nil, {Transparency = 0.9})
        T(card.Icon,   0.35, Enum.EasingStyle.Quint, nil, {ImageTransparency = 1})
        T(card.Title,  0.45, Enum.EasingStyle.Quint, nil, {TextTransparency  = 0.7})
        T(card.Body,   0.45, Enum.EasingStyle.Quint, nil, {TextTransparency  = 0.75})
        task.wait(0.3)
        card:TweenPosition(UDim2.new(1, 14, 0, 0), "In", "Quint", 0.55, true)
        task.wait(0.7)
        card:Destroy()
    end)
end

function Library:Init()
    if Library.SaveCfg then
        pcall(function()
            if isfile(Library.Folder.."/"..game.GameId..".txt") then
                LoadCfg(readfile(Library.Folder.."/"..game.GameId..".txt"))
                Library:MakeNotification({
                    Name    = "Config",
                    Content = "Loaded saved config for game "..tostring(game.GameId),
                    Time    = 5,
                })
            end
        end)
    end
end

function Library:MakeWindow(wc)
    local FirstTab  = true
    local Minimized = false
    local UIHidden  = false

    wc = wc or {}
    wc.Name             = tostring(wc.Name or "Froxy")
    wc.ConfigFolder     = wc.ConfigFolder     or wc.Name
    wc.SaveConfig       = wc.SaveConfig       or false
    wc.HidePremium      = wc.HidePremium      or false
    if wc.IntroEnabled  == nil then wc.IntroEnabled = true end
    wc.IntroText        = tostring(wc.IntroText or "Loading…")
    wc.IntroIcon        = wc.IntroIcon        or "rbxassetid://138394234566692"
    wc.CloseCallback    = wc.CloseCallback    or function() end
    wc.Icon             = wc.Icon             or "rbxassetid://8834748103"
    Library.Folder      = wc.ConfigFolder
    Library.SaveCfg     = wc.SaveConfig
    if wc.SaveConfig then
        pcall(function()
            if not isfolder(wc.ConfigFolder) then makefolder(wc.ConfigFolder) end
        end)
    end

    local TabHolder = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame",
        Color3.fromRGB(70, 100, 210), 2), {
        Size = UDim2.new(1, 0, 1, -54),
    }), {
        MakeElement("List", 0, 2),
        MakeElement("Padding", 5, 0, 0, 6),
    }), "Divider")

    AddConnection(TabHolder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        TabHolder.CanvasSize = UDim2.new(0, 0, 0, TabHolder.UIListLayout.AbsoluteContentSize.Y + 14)
    end)

    local function WinBtn(icon)
        return SetChildren(SetProps(MakeElement("Button"), {Size = UDim2.new(0, 32, 1, 0)}), {
            AddThemeObject(SetProps(MakeElement("Image", icon), {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position    = UDim2.new(0.5, 0, 0.5, 0),
                Size        = UDim2.new(0, 15, 0, 15),
            }), "Text"),
        })
    end

    local CloseBtn    = WinBtn("rbxassetid://7072725342")
    local MinimizeBtn = WinBtn("rbxassetid://7072719338")
    local ResizeBtn   = WinBtn("rbxassetid://117273761878755")
    MinimizeBtn:FindFirstChildWhichIsA("ImageLabel").Name = "Ico"

    local BtnContainer = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(10,12,24), 0, 6), {
        Size                   = UDim2.new(0, 104, 0, 26),
        Position               = UDim2.new(1, -116, 0.5, 0),
        AnchorPoint            = Vector2.new(0, 0.5),
        BackgroundTransparency = 0.45,
    }), {
        Create("UIStroke", {Color = Color3.fromRGB(48, 60, 130), Thickness = 1, Transparency = 0.3}),
        Create("Frame", {
            Size             = UDim2.new(0, 6, 1, 0),
            Position         = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(110, 140, 255),
            BackgroundTransparency = 0.78,
            BorderSizePixel  = 0,
            ZIndex           = 0,
        }, {
            Create("UICorner", {CornerRadius = UDim.new(0, 6)}),
            Create("UIGradient", {
                Color    = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 100, 220)),
                }),
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0,   0.0),
                    NumberSequenceKeypoint.new(0.5, 0.3),
                    NumberSequenceKeypoint.new(1,   1.0),
                }),
                Rotation = 90,
            }),
        }),
        Create("Frame", {
            Size             = UDim2.new(0, 1.5, 0.65, 0),
            Position         = UDim2.new(0, 1, 0.18, 0),
            BackgroundColor3 = Color3.fromRGB(200, 215, 255),
            BackgroundTransparency = 0.30,
            BorderSizePixel  = 0,
            ZIndex           = 2,
        }, {
            Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
            Create("UIGradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0,   0.1),
                    NumberSequenceKeypoint.new(0.5, 0.55),
                    NumberSequenceKeypoint.new(1,   1.0),
                }),
                Rotation = 90,
            }),
        }),
        Create("UIListLayout", {
            FillDirection       = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment   = Enum.VerticalAlignment.Center,
            SortOrder           = Enum.SortOrder.LayoutOrder,
        }),
        ResizeBtn, MinimizeBtn, CloseBtn,
    })

    local btnColors = {
        [ResizeBtn]   = Color3.fromRGB(60, 80, 200),
        [MinimizeBtn] = Color3.fromRGB(55, 75, 185),
        [CloseBtn]    = Color3.fromRGB(200, 55, 80),
    }
    for btn, col in pairs(btnColors) do
        AddConnection(btn.MouseEnter, function()
            T(btn:FindFirstChildWhichIsA("ImageLabel"), 0.15, nil, nil, {ImageColor3 = col})
        end)
        AddConnection(btn.MouseLeave, function()
            T(btn:FindFirstChildWhichIsA("ImageLabel"), 0.15, nil, nil,
              {ImageColor3 = Library.Themes[Library.SelectedTheme].Text})
        end)
    end

    local WindowName = AddThemeObject(SetProps(MakeElement("Label", wc.Name, 18), {
        Size       = UDim2.new(1, -130, 1, 0),
        Position   = UDim2.new(0, 22, 0, 0),
        Font       = Enum.Font.GothamBlack,
        TextColor3 = Color3.fromRGB(240, 243, 255),
    }), "Text")

    local TopLine = Create("Frame", {
        Size                   = UDim2.new(1, 0, 0, 1),
        Position               = UDim2.new(0, 0, 1, -1),
        BackgroundColor3       = Color3.fromRGB(50, 65, 155),
        BackgroundTransparency = 0.55,
        BorderSizePixel        = 0,
    })

    local SearchOpen = false

    local SearchBtn = SetChildren(SetProps(MakeElement("Button"), {
        Size                   = UDim2.new(0, 28, 0, 28),
        Position               = UDim2.new(1, -152, 0.5, 0),
        AnchorPoint            = Vector2.new(0, 0.5),
        BackgroundColor3       = Color3.fromRGB(10, 12, 26),
        BackgroundTransparency = 0.55,
    }), {
        Create("UICorner", {CornerRadius = UDim.new(0, 6)}),
        Create("UIStroke",  {Color = Color3.fromRGB(48, 62, 145), Thickness = 1, Transparency = 0.4}),
        Create("TextLabel", {
            Size                   = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text                   = "⌕",
            TextColor3             = Color3.fromRGB(130, 155, 240),
            TextSize               = 18,
            Font                   = Enum.Font.GothamBold,
            TextXAlignment         = Enum.TextXAlignment.Center,
            Name                   = "Icon",
        }),
    })

    local SearchBar = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(8, 10, 22), 0, 7), {
        Size                   = UDim2.new(0, 0, 0, 28),
        Position               = UDim2.new(1, -16, 0.5, 0),
        AnchorPoint            = Vector2.new(1, 0.5),
        BackgroundTransparency = 0.35,
        ClipsDescendants       = true,
        ZIndex                 = 10,
    }), {
        Create("UIStroke", {
            Color        = Color3.fromRGB(70, 95, 210),
            Thickness    = 1,
            Transparency = 0.25,
            Name         = "Border",
        }),
        Create("TextLabel", {
            Size                   = UDim2.new(0, 22, 1, 0),
            Position               = UDim2.new(0, 4, 0, 0),
            BackgroundTransparency = 1,
            Text                   = "⌕",
            TextColor3             = Color3.fromRGB(90, 120, 220),
            TextSize               = 16,
            Font                   = Enum.Font.GothamBold,
            TextXAlignment         = Enum.TextXAlignment.Center,
        }),
        Create("TextBox", {
            Size                   = UDim2.new(1, -52, 1, 0),
            Position               = UDim2.new(0, 26, 0, 0),
            BackgroundTransparency = 1,
            TextColor3             = Color3.fromRGB(220, 228, 255),
            PlaceholderColor3      = Color3.fromRGB(70, 90, 165),
            PlaceholderText        = "Suchen…",
            Font                   = Enum.Font.GothamSemibold,
            TextSize               = 13,
            ClearTextOnFocus       = false,
            TextXAlignment         = Enum.TextXAlignment.Left,
            Name                   = "Input",
            ZIndex                 = 11,
        }),
        Create("TextButton", {
            Size                   = UDim2.new(0, 20, 1, 0),
            Position               = UDim2.new(1, -22, 0, 0),
            BackgroundTransparency = 1,
            Text                   = "✕",
            TextColor3             = Color3.fromRGB(80, 100, 185),
            TextSize               = 11,
            Font                   = Enum.Font.GothamBold,
            Name                   = "CloseSearch",
            ZIndex                 = 12,
        }),
    })
    local MainWindow

    local function SetSearch(open)
        SearchOpen = open
        if open then
            T(SearchBar,  0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out,
              {Size = UDim2.new(0, 220, 0, 28)})
            T(SearchBtn,  0.20, nil, nil, {BackgroundTransparency = 0.25})
            T(SearchBtn.Icon, 0.15, nil, nil, {TextColor3 = Color3.fromRGB(160, 185, 255)})
            task.wait(0.15)
            SearchBar.Input:CaptureFocus()
        else
            SearchBar.Input:ReleaseFocus()
            SearchBar.Input.Text = ""
            T(SearchBar, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In,
              {Size = UDim2.new(0, 0, 0, 28)})
            T(SearchBtn, 0.20, nil, nil, {BackgroundTransparency = 0.55})
            T(SearchBtn.Icon, 0.15, nil, nil, {TextColor3 = Color3.fromRGB(130, 155, 240)})
            if MainWindow then
                for _, ic in ipairs(MainWindow:GetChildren()) do
                    if ic.Name == "ItemContainer" and ic.Visible then
                        for _, el in ipairs(ic:GetChildren()) do
                            if el:IsA("Frame") or el:IsA("ScrollingFrame") then
                                el.Visible = true
                            end
                        end
                    end
                end
            end
        end
    end

    AddConnection(SearchBtn.MouseButton1Click, function()
        SetSearch(not SearchOpen)
    end)
    AddConnection(SearchBar.CloseSearch.MouseButton1Click, function()
        SetSearch(false)
    end)

    AddConnection(SearchBar.Input:GetPropertyChangedSignal("Text"), function()
        if not MainWindow then return end
        local query = SearchBar.Input.Text:lower()
        for _, ic in ipairs(MainWindow:GetChildren()) do
            if ic.Name == "ItemContainer" and ic.Visible then
                for _, el in ipairs(ic:GetChildren()) do
                    if el:IsA("Frame") or el:IsA("ScrollingFrame") then
                        local nameLabel = el:FindFirstChild("Content")
                        local elName = nameLabel and tostring(nameLabel.Text):lower() or ""
                        if query == "" then
                            el.Visible = true
                        else
                            el.Visible = elName:find(query, 1, true) ~= nil
                        end
                    end
                end
            end
        end
    end)

    local DragPoint = SetProps(MakeElement("TFrame"), {Size = UDim2.new(1, 0, 0, 48)})

    local TopBar = SetChildren(SetProps(MakeElement("TFrame"), {
        Size             = UDim2.new(1, 0, 0, 48),
        Name             = "TopBar",
        ClipsDescendants = false,
    }), {
        WindowName, TopLine, SearchBtn, SearchBar, BtnContainer, DragPoint,
    })

    local avatarRing = SetChildren(SetProps(MakeElement("TFrame"), {
        AnchorPoint = Vector2.new(0, 0.5),
        Size        = UDim2.new(0, 32, 0, 32),
        Position    = UDim2.new(0, 10, 0.5, 0),
    }), {
        Create("UIStroke", {Color = Color3.fromRGB(90,120,255), Thickness = 1.5, Transparency = 0.2}),
        MakeElement("Corner", 1),
    })

    local sidebar = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(8,9,20), 0, 0), {
        Size                   = UDim2.new(0, 150, 1, -48),
        Position               = UDim2.new(0, 0, 0, 48),
        BackgroundTransparency = 0.42,
    }), {
        Create("UIGradient", {
            Color    = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 16, 34)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(8,  9,  20)),
            }),
            Rotation = 90,
        }),
        Create("Frame", {
            Size             = UDim2.new(0, 1, 1, 0),
            Position         = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(50, 65, 155),
            BackgroundTransparency = 0.5,
            BorderSizePixel  = 0,
        }),
        TabHolder,
        SetChildren(SetProps(MakeElement("TFrame"), {
            Size     = UDim2.new(1, 0, 0, 54),
            Position = UDim2.new(0, 0, 1, -54),
        }), {
            Create("Frame", {
                Size             = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Color3.fromRGB(38, 48, 110),
                BackgroundTransparency = 0.5,
                BorderSizePixel  = 0,
            }),
            avatarRing,
            AddThemeObject(SetChildren(SetProps(MakeElement("TFrame"), {
                AnchorPoint = Vector2.new(0, 0.5),
                Size        = UDim2.new(0, 30, 0, 30),
                Position    = UDim2.new(0, 11, 0.5, 0),
            }), {
                -- FIX: pcall für Thumbnail-URL damit es nicht crasht wenn UserId nil ist
                SetProps(MakeElement("Image",
                    "https://www.roblox.com/headshot-thumbnail/image?userId="..tostring(LocalPlayer.UserId).."&width=420&height=420&format=png"), {
                    Size = UDim2.new(1, 0, 1, 0),
                }),
                MakeElement("Corner", 1),
            }), "Divider"),
            AddThemeObject(SetProps(MakeElement("Label", tostring(LocalPlayer.DisplayName), 13), {
                Size     = UDim2.new(1, -52, 0, 13),
                Position = wc.HidePremium and UDim2.new(0, 50, 0.5, -6) or UDim2.new(0, 50, 0, 13),
                Font     = Enum.Font.GothamBold,
                ClipsDescendants = true,
            }), "Text"),
            AddThemeObject(SetProps(MakeElement("Label", "@"..tostring(LocalPlayer.Name), 11), {
                Size    = UDim2.new(1, -52, 0, 11),
                Position= UDim2.new(0, 50, 1, -22),
                Visible = not wc.HidePremium,
            }), "TextDark"),
        }),
    }), "Second")

    -- FIX: MainWindow wird jetzt hier erstellt (vorher referenziert in SetSearch)
    MainWindow = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(8,9,18), 0, 12), {
        Parent                 = Container,
        Position               = UDim2.new(0.5, -310, 0.5, -175),
        Size                   = UDim2.new(0, 620, 0, 350),
        ClipsDescendants       = true,
        BackgroundTransparency = 0.40,
    }), {
        Create("UIGradient", {
            Color    = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 20, 42)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(7,   8,  17)),
            }),
            Rotation = 140,
        }),
        Create("UIStroke", {
            Color        = Color3.fromRGB(60, 80, 200),
            Thickness    = 1.2,
            Transparency = 0.30,
        }),
        TopBar,
        sidebar,
    }), "Main")

    if wc.ShowIcon then
        WindowName.Position = UDim2.new(0, 58, 0, 0)
        SetProps(MakeElement("Image", wc.Icon), {
            Size     = UDim2.new(0, 28, 0, 28),
            Position = UDim2.new(0, 20, 0.5, -14),
            Parent   = TopBar,
        })
    end

    local SetResizingCb = MakeDraggable(DragPoint, MainWindow)
    MakeResizable(ResizeBtn, MainWindow, Vector2.new(420, 260), Vector2.new(1280, 860), SetResizingCb)

    local ReopenBtn = SetChildren(SetProps(MakeElement("Button"), {
        Parent                 = Container,
        Size                   = UDim2.new(0, 42, 0, 42),
        Position               = UDim2.new(0.5, -21, 0, 18),
        BackgroundColor3       = Color3.fromRGB(10, 12, 26),
        BackgroundTransparency = 0.25,
        Visible                = false,
    }), {
        Create("UIStroke", {Color = Color3.fromRGB(60, 80, 200), Thickness = 1.2, Transparency = 0.25}),
        SetProps(MakeElement("Image", wc.IntroIcon), {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position    = UDim2.new(0.5, 0, 0.5, 0),
            Size        = UDim2.new(0.65, 0, 0.65, 0),
            ImageColor3 = Color3.fromRGB(140, 168, 255),
        }),
        MakeElement("Corner", 1),
    })

    AddConnection(CloseBtn.MouseButton1Up, function()
        MainWindow.Visible = false
        if UserInputService.TouchEnabled then ReopenBtn.Visible = true end
        UIHidden = true
        Library:MakeNotification({
            Name    = "UI Hidden",
            Content = UserInputService.TouchEnabled
                and "Tap the icon or press Left Control to restore"
                or  "Press Left Control to restore",
            Time    = 5,
        })
        wc.CloseCallback()
    end)

    AddConnection(UserInputService.InputBegan, function(inp)
        if inp.KeyCode == Enum.KeyCode.LeftControl and UIHidden then
            MainWindow.Visible = true
            ReopenBtn.Visible  = false
            UIHidden           = false
        end
    end)

    AddConnection(ReopenBtn.Activated, function()
        MainWindow.Visible = true
        ReopenBtn.Visible  = false
        UIHidden           = false
    end)

    AddConnection(MinimizeBtn.MouseButton1Up, function()
        if Minimized then
            MainWindow.ClipsDescendants = false
            sidebar.Visible     = true
            TopLine.Visible     = true
            MinimizeBtn.Ico.Image = "rbxassetid://7072719338"
            T(MainWindow, 0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out,
              {Size = UDim2.new(0, 620, 0, 350)})
        else
            MainWindow.ClipsDescendants = true
            sidebar.Visible   = false
            TopLine.Visible   = false
            MinimizeBtn.Ico.Image = "rbxassetid://7072720870"
            T(MainWindow, 0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out,
              {Size = UDim2.new(0, WindowName.TextBounds.X + 145, 0, 48)})
        end
        Minimized = not Minimized
    end)

    local function RunIntro()
        MainWindow.Visible = false

        local glowRing = Create("Frame", {
            Parent                 = Container,
            AnchorPoint            = Vector2.new(0.5, 0.5),
            Position               = UDim2.new(0.5, 0, 0.38, 0),
            Size                   = UDim2.new(0, 58, 0, 58),
            BackgroundColor3       = Color3.fromRGB(70, 100, 240),
            BackgroundTransparency = 1,
            BorderSizePixel        = 0,
        }, {
            Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
            Create("UIGradient", {
                Color    = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 155, 255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(90,  50, 230)),
                }),
                Rotation = 135,
            }),
        })

        local badge = Create("Frame", {
            Parent                 = Container,
            AnchorPoint            = Vector2.new(0.5, 0.5),
            Position               = UDim2.new(0.5, 0, 0.38, 0),
            Size                   = UDim2.new(0, 46, 0, 46),
            BackgroundColor3       = Color3.fromRGB(8, 9, 20),
            BackgroundTransparency = 1,
            BorderSizePixel        = 0,
        }, {
            Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
            Create("TextLabel", {
                Size                   = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text                   = "N",
                TextColor3             = Color3.fromRGB(200, 218, 255),
                TextSize               = 26,
                Font                   = Enum.Font.GothamBlack,
                TextXAlignment         = Enum.TextXAlignment.Center,
                TextYAlignment         = Enum.TextYAlignment.Center,
                Name                   = "Letter",
            }),
        })

        local lbl = SetProps(MakeElement("Label", wc.IntroText, 14), {
            Parent           = Container,
            Size             = UDim2.new(1, 0, 1, 0),
            AnchorPoint      = Vector2.new(0.5, 0.5),
            Position         = UDim2.new(0.5, 30, 0.5, 0),
            TextXAlignment   = Enum.TextXAlignment.Center,
            Font             = Enum.Font.GothamBold,
            TextColor3       = Color3.fromRGB(200, 215, 255),
            TextTransparency = 1,
        })

        T(glowRing, 0.40, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {
            BackgroundTransparency = 0.20,
            Position               = UDim2.new(0.5, 0, 0.5, 0),
        })
        T(badge, 0.40, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {
            BackgroundTransparency = 0,
            Position               = UDim2.new(0.5, 0, 0.5, 0),
        })
        task.wait(0.85)

        local textW = lbl.TextBounds.X
        T(glowRing, 0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out,
          {Position = UDim2.new(0.5, -(textW / 2) - 2, 0.5, 0)})
        T(badge,    0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out,
          {Position = UDim2.new(0.5, -(textW / 2) - 2, 0.5, 0)})
        task.wait(0.25)
        T(lbl, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {TextTransparency = 0})

        task.wait(1.9)

        T(lbl,      0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In, {TextTransparency = 1})
        T(badge,    0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.In, {BackgroundTransparency = 1})
        T(glowRing, 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.In, {BackgroundTransparency = 1})
        task.wait(0.38)
        MainWindow.Visible = true
        glowRing:Destroy(); badge:Destroy(); lbl:Destroy()
    end

    if wc.IntroEnabled then RunIntro() end

    local TabFunction = {}

    function TabFunction:MakeTab(tc)
        tc            = tc or {}
        tc.Name       = tostring(tc.Name  or "Tab")
        tc.Icon       = tc.Icon  or ""
        tc.PremiumOnly= tc.PremiumOnly or false

        local tabBtn = SetChildren(SetProps(MakeElement("Button"), {
            Size                   = UDim2.new(1, 0, 0, 32),
            Parent                 = TabHolder,
            BackgroundTransparency = 1,
        }), {
            Create("Frame", {
                Size             = UDim2.new(0, 2, 0, 14),
                Position         = UDim2.new(0, 0, 0.5, 0),
                AnchorPoint      = Vector2.new(0, 0.5),
                BackgroundColor3 = Color3.fromRGB(90, 130, 255),
                BackgroundTransparency = 1,
                BorderSizePixel  = 0,
                Name             = "ActiveBar",
            }, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})}),
            AddThemeObject(SetProps(MakeElement("Image", tc.Icon), {
                AnchorPoint       = Vector2.new(0, 0.5),
                Size              = UDim2.new(0, 13, 0, 13),
                Position          = UDim2.new(0, 14, 0.5, 0),
                ImageTransparency = 0.6,
                Name              = "Ico",
            }), "Text"),
            SetProps(MakeElement("Label", tc.Name, 13), {
                Size             = UDim2.new(1, -34, 1, 0),
                Position         = UDim2.new(0, 30, 0, 0),
                Font             = Enum.Font.GothamSemibold,
                TextTransparency = 0.50,
                TextColor3       = Color3.fromRGB(140, 158, 225),
                Name             = "Title",
            }),
        })

        local hoverPill = SetProps(MakeElement("RoundFrame", Color3.fromRGB(35, 50, 120), 0, 5), {
            Size                   = UDim2.new(1, -8, 1, -4),
            Position               = UDim2.new(0, 4, 0, 2),
            BackgroundTransparency = 1,
            ZIndex                 = 0,
            Name                   = "HoverPill",
        })
        hoverPill.Parent = tabBtn

        AddConnection(tabBtn.MouseEnter, function()
            T(hoverPill, 0.18, nil, nil, {BackgroundTransparency = 0.80})
        end)
        AddConnection(tabBtn.MouseLeave, function()
            T(hoverPill, 0.18, nil, nil, {BackgroundTransparency = 1})
        end)

        local ItemContainer = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame",
            Color3.fromRGB(70, 100, 210), 4), {
            Size     = UDim2.new(1, -150, 1, -48),
            Position = UDim2.new(0, 150, 0, 48),
            Parent   = MainWindow,
            Visible  = false,
            Name     = "ItemContainer",
        }), {
            MakeElement("List", 0, 6),
            MakeElement("Padding", 14, 10, 10, 14),
        }), "Divider")

        AddConnection(ItemContainer.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
            ItemContainer.CanvasSize = UDim2.new(0, 0, 0,
                ItemContainer.UIListLayout.AbsoluteContentSize.Y + 30)
        end)

        local snd = Create("Sound", {
            SoundId = "rbxassetid://6895079853",
            Volume  = 0.5,
            Parent  = tabBtn,
        })

        local function activateTab()
            for _, child in ipairs(TabHolder:GetChildren()) do
                if child:IsA("TextButton") then
                    child.Title.Font = Enum.Font.GothamSemibold
                    T(child.Ico,       0.2, nil, nil, {ImageTransparency = 0.60,
                      ImageColor3 = Color3.fromRGB(110, 128, 195)})
                    T(child.Title,     0.2, nil, nil, {TextTransparency  = 0.50,
                      TextColor3  = Color3.fromRGB(120, 140, 200)})
                    if child:FindFirstChild("ActiveBar") then
                        T(child.ActiveBar, 0.2, nil, nil, {BackgroundTransparency = 1})
                    end
                end
            end
            for _, ic in ipairs(MainWindow:GetChildren()) do
                if ic.Name == "ItemContainer" then ic.Visible = false end
            end
            tabBtn.Title.Font = Enum.Font.GothamBold
            T(tabBtn.Ico,       0.2, nil, nil, {ImageTransparency = 0,
              ImageColor3 = Color3.fromRGB(150, 180, 255)})
            T(tabBtn.Title,     0.2, nil, nil, {TextTransparency  = 0,
              TextColor3  = Color3.fromRGB(215, 228, 255)})
            T(tabBtn.ActiveBar, 0.2, nil, nil, {BackgroundTransparency = 0})
            ItemContainer.Visible = true
        end

        if FirstTab then FirstTab = false; activateTab() end

        AddConnection(tabBtn.MouseButton1Click, function()
            pcall(function() snd:Play() end)
            activateTab()
        end)

        local function GetElements(itemParent)
            local ef = {}

            function ef:AddLabel(text)
                local card = GlassCard(UDim2.new(1, 0, 0, 32), itemParent, 0.50)
                AddThemeObject(SetProps(MakeElement("Label", tostring(text or ""), 14), {
                    Size     = UDim2.new(1, -14, 1, 0),
                    Position = UDim2.new(0, 14, 0, 0),
                    Font     = Enum.Font.GothamSemibold,
                    Name     = "Content",
                    Parent   = card,
                }), "Text")
                local fn = {}
                function fn:Set(t) card.Content.Text = tostring(t or "") end
                return fn
            end

            function ef:AddParagraph(title, body)
                title = tostring(title or "Title")
                body  = tostring(body  or "")

                local card = GlassCard(UDim2.new(1, 0, 0, 32), itemParent, 0.50)

                local lbl = AddThemeObject(SetProps(MakeElement("Label", title, 14), {
                    Size     = UDim2.new(1, -14, 0, 14),
                    Position = UDim2.new(0, 14, 0, 10),
                    Font     = Enum.Font.GothamBold,
                    Name     = "Title",
                    Parent   = card,
                }), "Text")

                local bdy = AddThemeObject(SetProps(MakeElement("Label", "", 12), {
                    Size          = UDim2.new(1, -26, 0, 0),
                    Position      = UDim2.new(0, 14, 0, 28),
                    TextWrapped   = true,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Name          = "Body",
                    Parent        = card,
                }), "TextDark")

                AddConnection(bdy:GetPropertyChangedSignal("Text"), function()
                    bdy.Size = UDim2.new(1, -26, 0, bdy.TextBounds.Y)
                    card.Size = UDim2.new(1, 0, 0, bdy.TextBounds.Y + 40)
                end)
                bdy.Text = body

                local fn = {}
                function fn:Set(t) bdy.Text = tostring(t or "") end
                return fn
            end

            function ef:AddButton(cfg)
                cfg          = cfg or {}
                cfg.Name     = tostring(cfg.Name     or "Button")
                cfg.Callback = cfg.Callback or function() end

                local btn = {}
                local click = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})

                local bar = Create("Frame", {
                    Size             = UDim2.new(0, 2, 0, 13),
                    Position         = UDim2.new(0, 0, 0.5, 0),
                    AnchorPoint      = Vector2.new(0, 0.5),
                    BackgroundColor3 = Color3.fromRGB(80, 120, 255),
                    BackgroundTransparency = 0.30,
                    BorderSizePixel  = 0,
                    Name             = "Bar",
                }, {
                    Create("UICorner", {CornerRadius = UDim.new(0, 2)}),
                    Create("UIGradient", {
                        Color    = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 170, 255)),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(90,  60, 220)),
                        }),
                        Rotation = 90,
                    }),
                })

                local chevron = Create("TextLabel", {
                    Size                   = UDim2.new(0, 16, 1, 0),
                    Position               = UDim2.new(1, -26, 0, 0),
                    BackgroundTransparency = 1,
                    Text                   = "›",
                    TextColor3             = Color3.fromRGB(60, 80, 150),
                    TextSize               = 17,
                    Font                   = Enum.Font.GothamBold,
                    TextXAlignment         = Enum.TextXAlignment.Center,
                    Name                   = "Chevron",
                })

                local card = AddThemeObject(SetChildren(SetProps(
                    MakeElement("RoundFrame", Color3.fromRGB(14, 16, 32), 0, 7), {
                    Size                   = UDim2.new(1, 0, 0, 36),
                    Parent                 = itemParent,
                    BackgroundTransparency = 0.50,
                }), {
                    Create("UIStroke", {
                        Color = Color3.fromRGB(48, 62, 145), Thickness = 1,
                        Transparency = 0.45, Name = "Border",
                    }),
                    bar,
                    AddThemeObject(SetProps(MakeElement("Label", cfg.Name, 14), {
                        Size     = UDim2.new(1, -42, 1, 0),
                        Position = UDim2.new(0, 13, 0, 0),
                        Font     = Enum.Font.GothamSemibold,
                        Name     = "Content",
                    }), "Text"),
                    chevron,
                    click,
                }), "Second")

                AddConnection(click.MouseEnter, function()
                    T(card.Border, 0.2, nil, nil, {Color = Color3.fromRGB(80,115,225), Transparency = 0.15})
                    T(card,        0.2, nil, nil, {BackgroundTransparency = 0.38})
                    T(chevron,     0.2, nil, nil, {TextColor3 = Color3.fromRGB(110,155,255),
                                                    Position = UDim2.new(1, -22, 0, 0)})
                end)
                AddConnection(click.MouseLeave, function()
                    T(card.Border, 0.2, nil, nil, {Color = Color3.fromRGB(48,62,145), Transparency = 0.45})
                    T(card,        0.2, nil, nil, {BackgroundTransparency = 0.50})
                    T(chevron,     0.2, nil, nil, {TextColor3 = Color3.fromRGB(60,80,150),
                                                    Position = UDim2.new(1, -26, 0, 0)})
                end)
                AddConnection(click.MouseButton1Down, function()
                    T(card, 0.08, Enum.EasingStyle.Quad, nil, {BackgroundTransparency = 0.25})
                    T(bar,  0.08, Enum.EasingStyle.Quad, nil, {Size = UDim2.new(0, 2, 0, 20)})
                end)
                AddConnection(click.MouseButton1Up, function()
                    T(card, 0.18, nil, nil, {BackgroundTransparency = 0.38})
                    T(bar,  0.18, nil, nil, {Size = UDim2.new(0, 2, 0, 13)})
                    -- FIX: pcall damit ein Fehler im Callback die UI nicht killt
                    spawn(function() pcall(cfg.Callback) end)
                end)

                function btn:Set(t) card.Content.Text = tostring(t or "") end
                return btn
            end

            function ef:AddToggle(cfg)
                cfg          = cfg or {}
                cfg.Name     = tostring(cfg.Name     or "Toggle")
                cfg.Default  = cfg.Default  or false
                cfg.Callback = cfg.Callback or function() end
                cfg.Color    = cfg.Color    or Color3.fromRGB(80, 120, 255)
                cfg.Flag     = cfg.Flag     or nil
                cfg.Save     = cfg.Save     or false

                local tog = {Value = cfg.Default, Save = cfg.Save, Type = "Toggle"}
                local click = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})

                local track = Create("Frame", {
                    Size             = UDim2.new(0, 40, 0, 22),
                    Position         = UDim2.new(1, -50, 0.5, 0),
                    AnchorPoint      = Vector2.new(0, 0.5),
                    BackgroundColor3 = Color3.fromRGB(10, 12, 26),
                    BorderSizePixel  = 0,
                    Name             = "Track",
                }, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})})

                local trackBorder = Create("UIStroke", {
                    Color = Color3.fromRGB(45, 58, 128), Thickness = 1,
                    Transparency = 0.25, Name = "Stroke",
                })
                trackBorder.Parent = track

                local fill = Create("Frame", {
                    Size             = UDim2.new(1, 0, 1, 0),
                    BackgroundColor3 = cfg.Color,
                    BackgroundTransparency = 1,
                    BorderSizePixel  = 0,
                    Name             = "Fill",
                }, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
                fill.Parent = track

                local thumb = Create("Frame", {
                    Size             = UDim2.new(0, 16, 0, 16),
                    Position         = UDim2.new(0, 3, 0.5, 0),
                    AnchorPoint      = Vector2.new(0, 0.5),
                    BackgroundColor3 = Color3.fromRGB(90, 105, 165),
                    BorderSizePixel  = 0,
                    Name             = "Thumb",
                }, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
                thumb.Parent = track

                local card = AddThemeObject(SetChildren(SetProps(
                    MakeElement("RoundFrame", Color3.fromRGB(14, 16, 32), 0, 7), {
                    Size                   = UDim2.new(1, 0, 0, 38),
                    Parent                 = itemParent,
                    BackgroundTransparency = 0.50,
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(48, 62, 145), Thickness = 1,
                                        Transparency = 0.45, Name = "Border"}),
                    AddThemeObject(SetProps(MakeElement("Label", cfg.Name, 14), {
                        Size     = UDim2.new(1, -64, 1, 0),
                        Position = UDim2.new(0, 12, 0, 0),
                        Font     = Enum.Font.GothamSemibold,
                        Name     = "Content",
                    }), "Text"),
                    track, click,
                }), "Second")

                function tog:Set(v)
                    tog.Value = v
                    if v then
                        T(track,       0.25, nil, nil, {BackgroundColor3 = cfg.Color})
                        T(trackBorder, 0.25, nil, nil, {Color = cfg.Color, Transparency = 0.55})
                        T(fill,        0.25, nil, nil, {BackgroundTransparency = 0.50})
                        T(thumb,       0.25, nil, nil, {
                            Position         = UDim2.new(0, 21, 0.5, 0),
                            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        })
                        T(card.Border, 0.25, nil, nil, {Color = cfg.Color, Transparency = 0.50})
                    else
                        T(track,       0.25, nil, nil, {BackgroundColor3 = Color3.fromRGB(10, 12, 26)})
                        T(trackBorder, 0.25, nil, nil, {Color = Color3.fromRGB(45, 58, 128), Transparency = 0.25})
                        T(fill,        0.25, nil, nil, {BackgroundTransparency = 1})
                        T(thumb,       0.25, nil, nil, {
                            Position         = UDim2.new(0, 3, 0.5, 0),
                            BackgroundColor3 = Color3.fromRGB(70, 85, 148),
                        })
                        T(card.Border, 0.25, nil, nil, {Color = Color3.fromRGB(48, 62, 145), Transparency = 0.45})
                    end
                    -- FIX: pcall damit Callback-Fehler die UI nicht killen
                    pcall(cfg.Callback, tog.Value)
                end

                tog:Set(tog.Value)

                AddConnection(click.MouseEnter, function()
                    T(card, 0.15, nil, nil, {BackgroundTransparency = 0.38})
                end)
                AddConnection(click.MouseLeave, function()
                    T(card, 0.15, nil, nil, {BackgroundTransparency = 0.50})
                end)
                AddConnection(click.MouseButton1Down, function()
                    T(thumb, 0.08, Enum.EasingStyle.Quad, nil, {Size = UDim2.new(0, 20, 0, 16)})
                end)
                AddConnection(click.MouseButton1Up, function()
                    T(thumb, 0.14, nil, nil, {Size = UDim2.new(0, 16, 0, 16)})
                    SaveCfg()
                    tog:Set(not tog.Value)
                end)

                if cfg.Flag then Library.Flags[cfg.Flag] = tog end
                return tog
            end

            function ef:AddSlider(cfg)
                cfg           = cfg or {}
                cfg.Name      = tostring(cfg.Name      or "Slider")
                cfg.Min       = tonumber(cfg.Min)       or 0
                cfg.Max       = tonumber(cfg.Max)       or 100
                cfg.Increment = tonumber(cfg.Increment) or 1
                cfg.Default   = tonumber(cfg.Default)   or 50
                cfg.Callback  = cfg.Callback  or function() end
                cfg.ValueName = tostring(cfg.ValueName or "")
                cfg.Color     = cfg.Color     or Color3.fromRGB(80, 120, 255)
                cfg.Flag      = cfg.Flag      or nil
                cfg.Save      = cfg.Save      or false

                local sl = {Value = cfg.Default, Save = cfg.Save, Type = "Slider"}
                local dragging = false

                local knob = Create("Frame", {
                    Size             = UDim2.new(0, 13, 0, 13),
                    AnchorPoint      = Vector2.new(0.5, 0.5),
                    Position         = UDim2.new(0, 0, 0.5, 0),
                    BackgroundColor3 = Color3.fromRGB(240, 244, 255),
                    BorderSizePixel  = 0,
                    ZIndex           = 5,
                    Name             = "Knob",
                }, {
                    Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
                    Create("UIStroke", {Color = cfg.Color, Thickness = 1.5, Transparency = 0.20}),
                })

                local fill = SetChildren(SetProps(MakeElement("RoundFrame", cfg.Color, 0, 4), {
                    Size             = UDim2.new(0, 0, 1, 0),
                    BackgroundTransparency = 0,
                    ZIndex           = 3,
                    ClipsDescendants = false,
                }), {
                    knob,
                    Create("UIGradient", {
                        Color    = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 95, 215)),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(145, 80, 255)),
                        }),
                    }),
                })

                local track = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(8, 10, 22), 0, 4), {
                    Size             = UDim2.new(1, -22, 0, 12),
                    Position         = UDim2.new(0, 11, 0, 42),
                    BackgroundTransparency = 0.20,
                    ClipsDescendants = false,
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(42, 55, 130), Thickness = 1, Transparency = 0.40}),
                    fill,
                })

                local valLbl = AddThemeObject(SetProps(MakeElement("Label", "", 12), {
                    Size             = UDim2.new(1, -22, 0, 14),
                    Position         = UDim2.new(0, 11, 0, 24),
                    Font             = Enum.Font.Gotham,
                    Name             = "Val",
                    TextXAlignment   = Enum.TextXAlignment.Right,
                    TextTransparency = 0.35,
                }), "TextDark")

                local card = AddThemeObject(SetChildren(SetProps(
                    MakeElement("RoundFrame", Color3.fromRGB(14, 16, 32), 0, 7), {
                    Size                   = UDim2.new(1, 0, 0, 64),
                    Parent                 = itemParent,
                    BackgroundTransparency = 0.50,
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(48, 62, 145), Thickness = 1, Transparency = 0.45}),
                    AddThemeObject(SetProps(MakeElement("Label", cfg.Name, 14), {
                        Size     = UDim2.new(1, -95, 0, 14),
                        Position = UDim2.new(0, 12, 0, 8),
                        Font     = Enum.Font.GothamSemibold,
                        Name     = "Content",
                    }), "Text"),
                    valLbl, track,
                }), "Second")

                track.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
                end)
                track.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
                end)
                UserInputService.InputChanged:Connect(function()
                    if dragging then
                        local pct = math.clamp(
                            (Mouse.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                        sl:Set(cfg.Min + (cfg.Max - cfg.Min) * pct)
                        SaveCfg()
                    end
                end)

                function sl:Set(v)
                    
                    v = tonumber(v) or cfg.Min
                    self.Value = math.clamp(Round(v, cfg.Increment), cfg.Min, cfg.Max)
                    local pct  = (self.Value - cfg.Min) / (cfg.Max - cfg.Min)
                    T(fill, 0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,
                      {Size = UDim2.fromScale(pct, 1)})
                    knob.Position = UDim2.new(1, 0, 0.5, 0)
                    valLbl.Text   = tostring(self.Value)
                        ..(cfg.ValueName ~= "" and " "..cfg.ValueName or "")
                    pcall(cfg.Callback, self.Value)
                end

                sl:Set(sl.Value)
                if cfg.Flag then Library.Flags[cfg.Flag] = sl end
                return sl
            end

            function ef:AddDropdown(cfg)
                cfg          = cfg or {}
                cfg.Name     = tostring(cfg.Name     or "Dropdown")
                cfg.Options  = cfg.Options  or {}
                cfg.Default  = tostring(cfg.Default  or "")
                cfg.Callback = cfg.Callback or function() end
                cfg.Flag     = cfg.Flag     or nil
                cfg.Save     = cfg.Save     or false

                local function NormalizeOptions(opts)
                    local result = {}
                    for _, v in ipairs(opts) do
                        table.insert(result, tostring(v))
                    end
                    return result
                end

                local dd = {
                    Value   = cfg.Default,
                    Options = NormalizeOptions(cfg.Options),
                    Buttons = {},
                    Toggled = false,
                    Type    = "Dropdown",
                    Save    = cfg.Save,
                }

                if not table.find(dd.Options, dd.Value) then dd.Value = "—" end

                local MAX = 5
                local listLayout = MakeElement("List")

                local ddContainer = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame",
                    Color3.fromRGB(70,100,210), 2), {listLayout}), {
                    Parent           = itemParent,
                    Position         = UDim2.new(0, 0, 0, 38),
                    Size             = UDim2.new(1, 0, 1, -38),
                    ClipsDescendants = true,
                }), "Divider")

                AddConnection(listLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
                    ddContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
                end)

                local click = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})

                local card = AddThemeObject(SetChildren(SetProps(
                    MakeElement("RoundFrame", Color3.fromRGB(14, 16, 32), 0, 7), {
                    Size                   = UDim2.new(1, 0, 0, 38),
                    Parent                 = itemParent,
                    ClipsDescendants       = true,
                    BackgroundTransparency = 0.50,
                }), {
                    ddContainer,
                    SetChildren(SetProps(MakeElement("TFrame"), {
                        Size             = UDim2.new(1, 0, 0, 38),
                        ClipsDescendants = true,
                        Name             = "F",
                    }), {
                        AddThemeObject(SetProps(MakeElement("Label", cfg.Name, 14), {
                            Size     = UDim2.new(1, -14, 1, 0),
                            Position = UDim2.new(0, 14, 0, 0),
                            Font     = Enum.Font.GothamSemibold,
                            Name     = "Content",
                        }), "Text"),
                        AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072706796"), {
                            Size        = UDim2.new(0, 16, 0, 16),
                            AnchorPoint = Vector2.new(0, 0.5),
                            Position    = UDim2.new(1, -26, 0.5, 0),
                            ImageColor3 = Color3.fromRGB(75, 100, 195),
                            Name        = "Arrow",
                        }), "TextDark"),
                        -- FIX 3: Selected.Text immer als String setzen
                        AddThemeObject(SetProps(MakeElement("Label", tostring(dd.Value), 12), {
                            Size           = UDim2.new(1, -38, 1, 0),
                            Font           = Enum.Font.Gotham,
                            Name           = "Selected",
                            TextXAlignment = Enum.TextXAlignment.Right,
                        }), "TextDark"),
                        AddThemeObject(SetProps(MakeElement("Frame"), {
                            Size    = UDim2.new(1, 0, 0, 1),
                            Position= UDim2.new(0, 0, 1, -1),
                            Name    = "Line",
                            Visible = false,
                        }), "Stroke"),
                        click,
                    }),
                    Create("UIStroke", {Color = Color3.fromRGB(48, 62, 145), Thickness = 1, Transparency = 0.45}),
                    MakeElement("Corner"),
                }), "Second")

                local function RefreshOptions(opts)
                    for _, opt in pairs(opts) do
                        -- FIX 4: opt IMMER als String für das Label verwenden
                        local optStr = tostring(opt)
                        local row = AddThemeObject(SetProps(SetChildren(MakeElement("Button", Color3.fromRGB(18, 20, 40)), {
                            MakeElement("Corner", 0, 5),
                            AddThemeObject(SetProps(MakeElement("Label", optStr, 12, 0.45), {
                                Position = UDim2.new(0, 10, 0, 0),
                                Size     = UDim2.new(1, -10, 1, 0),
                                Font     = Enum.Font.GothamSemibold,
                                Name     = "Title",
                            }), "Text"),
                        }), {
                            Parent                 = ddContainer,
                            Size                   = UDim2.new(1, 0, 0, 28),
                            BackgroundTransparency = 1,
                            ClipsDescendants       = true,
                        }), "Divider")

                        AddConnection(row.MouseEnter, function()
                            T(row, 0.12, nil, nil, {BackgroundTransparency = 0.75})
                        end)
                        AddConnection(row.MouseLeave, function()
                            if dd.Value ~= optStr then
                                T(row, 0.12, nil, nil, {BackgroundTransparency = 1})
                            end
                        end)
                        AddConnection(row.MouseButton1Click, function()
                            dd:Set(optStr); SaveCfg()
                        end)
                        -- FIX 5: Key als String speichern
                        dd.Buttons[optStr] = row
                    end
                end

                function dd:Refresh(opts, clear)
                    if clear then
                        for _, v in pairs(dd.Buttons) do v:Destroy() end
                        table.clear(dd.Options); table.clear(dd.Buttons)
                    end
                    -- FIX 6: Auch bei Refresh normalisieren
                    dd.Options = NormalizeOptions(opts)
                    RefreshOptions(dd.Options)
                end

                function dd:Set(val)
                    -- FIX 7: val immer zu String konvertieren
                    val = tostring(val or "")
                    if not table.find(dd.Options, val) then
                        dd.Value = "—"
                        card.F.Selected.Text = dd.Value
                        for _, b in pairs(dd.Buttons) do
                            T(b, 0.12, nil, nil, {BackgroundTransparency = 1})
                            T(b.Title, 0.12, nil, nil, {TextTransparency = 0.45})
                        end
                        return
                    end
                    dd.Value = val
                    -- FIX 8: Text-Zuweisung als String sicherstellen
                    card.F.Selected.Text = tostring(dd.Value)
                    for k, b in pairs(dd.Buttons) do
                        local isSelected = k == val
                        T(b, 0.12, nil, nil, {BackgroundTransparency = isSelected and 0.72 or 1})
                        T(b.Title, 0.12, nil, nil, {TextTransparency = isSelected and 0 or 0.45})
                    end
                    -- FIX 9: Callback mit pcall schützen
                    pcall(cfg.Callback, dd.Value)
                end

                AddConnection(click.MouseButton1Click, function()
                    dd.Toggled = not dd.Toggled
                    card.F.Line.Visible = dd.Toggled
                    T(card.F.Arrow, 0.15, Enum.EasingStyle.Quad, nil,
                      {Rotation = dd.Toggled and 180 or 0})
                    local targetH = dd.Toggled
                        and (#dd.Options > MAX
                            and (38 + MAX * 28)
                            or  (listLayout.AbsoluteContentSize.Y + 38))
                        or 38
                    T(card, 0.15, Enum.EasingStyle.Quad, nil,
                      {Size = UDim2.new(1, 0, 0, targetH)})
                end)

                dd:Refresh(dd.Options, false)
                dd:Set(dd.Value)
                if cfg.Flag then Library.Flags[cfg.Flag] = dd end
                return dd
            end

            function ef:AddBind(cfg)
                cfg          = cfg or {}
                cfg.Name     = tostring(cfg.Name     or "Bind")
                cfg.Default  = cfg.Default  or Enum.KeyCode.Unknown
                cfg.Hold     = cfg.Hold     or false
                cfg.Callback = cfg.Callback or function() end
                cfg.Flag     = cfg.Flag     or nil
                cfg.Save     = cfg.Save     or false

                local bind = {Binding = false, Type = "Bind", Save = cfg.Save}
                local holding = false
                local click   = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})

                local keyBox = AddThemeObject(SetChildren(SetProps(
                    MakeElement("RoundFrame", Color3.fromRGB(10, 12, 26), 0, 5), {
                    Size                   = UDim2.new(0, 28, 0, 22),
                    Position               = UDim2.new(1, -12, 0.5, 0),
                    AnchorPoint            = Vector2.new(1, 0.5),
                    BackgroundTransparency = 0.35,
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(60, 80, 175), Thickness = 1, Transparency = 0.35}),
                    AddThemeObject(SetProps(MakeElement("Label", "—", 11), {
                        Size           = UDim2.new(1, 0, 1, 0),
                        Font           = Enum.Font.GothamBold,
                        TextXAlignment = Enum.TextXAlignment.Center,
                        Name           = "Value",
                    }), "Text"),
                }), "Main")

                local card = AddThemeObject(SetChildren(SetProps(
                    MakeElement("RoundFrame", Color3.fromRGB(14, 16, 32), 0, 7), {
                    Size                   = UDim2.new(1, 0, 0, 38),
                    Parent                 = itemParent,
                    BackgroundTransparency = 0.50,
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(48, 62, 145), Thickness = 1, Transparency = 0.45}),
                    AddThemeObject(SetProps(MakeElement("Label", cfg.Name, 14), {
                        Size     = UDim2.new(1, -14, 1, 0),
                        Position = UDim2.new(0, 12, 0, 0),
                        Font     = Enum.Font.GothamSemibold,
                        Name     = "Content",
                    }), "Text"),
                    keyBox, click,
                }), "Second")

                AddConnection(keyBox.Value:GetPropertyChangedSignal("Text"), function()
                    T(keyBox, 0.2, nil, nil,
                      {Size = UDim2.new(0, keyBox.Value.TextBounds.X + 14, 0, 22)})
                end)

                AddConnection(click.InputEnded, function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        if bind.Binding then return end
                        bind.Binding    = true
                        keyBox.Value.Text = "…"
                    end
                end)

                AddConnection(UserInputService.InputBegan, function(inp)
                    if UserInputService:GetFocusedTextBox() then return end
                    if (inp.KeyCode.Name == bind.Value or inp.UserInputType.Name == bind.Value)
                       and not bind.Binding then
                        if cfg.Hold then
                            holding = true; pcall(cfg.Callback, true)
                        else
                            pcall(cfg.Callback)
                        end
                    elseif bind.Binding then
                        local key
                        pcall(function() if not CheckKey(BlacklistedKeys, inp.KeyCode) then key = inp.KeyCode end end)
                        pcall(function() if CheckKey(WhitelistedMouse, inp.UserInputType) and not key then key = inp.UserInputType end end)
                        bind:Set(key or bind.Value)
                        SaveCfg()
                    end
                end)

                AddConnection(UserInputService.InputEnded, function(inp)
                    if (inp.KeyCode.Name == bind.Value or inp.UserInputType.Name == bind.Value) then
                        if cfg.Hold and holding then
                            holding = false; pcall(cfg.Callback, false)
                        end
                    end
                end)

                AddConnection(click.MouseEnter, function()
                    T(card, 0.15, nil, nil, {BackgroundTransparency = 0.38})
                end)
                AddConnection(click.MouseLeave, function()
                    T(card, 0.15, nil, nil, {BackgroundTransparency = 0.50})
                end)

                function bind:Set(key)
                    bind.Binding      = false
                    bind.Value        = key and (key.Name or key) or bind.Value
                    bind.Value        = type(bind.Value) == "string" and bind.Value or bind.Value.Name
                    keyBox.Value.Text = tostring(bind.Value)
                end

                bind:Set(cfg.Default)
                if cfg.Flag then Library.Flags[cfg.Flag] = bind end
                return bind
            end

            function ef:AddTextbox(cfg)
                cfg               = cfg or {}
                cfg.Name          = tostring(cfg.Name          or "Textbox")
                cfg.Default       = tostring(cfg.Default       or "")
                cfg.TextDisappear = cfg.TextDisappear or false
                cfg.Callback      = cfg.Callback      or function() end

                local click = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})

                local tbActual = AddThemeObject(Create("TextBox", {
                    Size                   = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    TextColor3             = Color3.fromRGB(210, 222, 255),
                    PlaceholderColor3      = Color3.fromRGB(65, 85, 155),
                    PlaceholderText        = "Input…",
                    Font                   = Enum.Font.GothamSemibold,
                    TextXAlignment         = Enum.TextXAlignment.Center,
                    TextSize               = 12,
                    ClearTextOnFocus       = false,
                }), "Text")

                local inputBox = AddThemeObject(SetChildren(SetProps(
                    MakeElement("RoundFrame", Color3.fromRGB(8, 10, 22), 0, 5), {
                    Size                   = UDim2.new(0, 30, 0, 22),
                    Position               = UDim2.new(1, -12, 0.5, 0),
                    AnchorPoint            = Vector2.new(1, 0.5),
                    BackgroundTransparency = 0.30,
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(60, 80, 175), Thickness = 1, Transparency = 0.35}),
                    tbActual,
                }), "Main")

                local card = AddThemeObject(SetChildren(SetProps(
                    MakeElement("RoundFrame", Color3.fromRGB(14, 16, 32), 0, 7), {
                    Size                   = UDim2.new(1, 0, 0, 38),
                    Parent                 = itemParent,
                    BackgroundTransparency = 0.50,
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(48, 62, 145), Thickness = 1, Transparency = 0.45}),
                    AddThemeObject(SetProps(MakeElement("Label", cfg.Name, 14), {
                        Size     = UDim2.new(1, -14, 1, 0),
                        Position = UDim2.new(0, 12, 0, 0),
                        Font     = Enum.Font.GothamSemibold,
                        Name     = "Content",
                    }), "Text"),
                    inputBox, click,
                }), "Second")

                AddConnection(tbActual:GetPropertyChangedSignal("Text"), function()
                    T(inputBox, 0.28, nil, nil,
                      {Size = UDim2.new(0, tbActual.TextBounds.X + 16, 0, 22)})
                end)
                AddConnection(tbActual.FocusLost, function()
                    pcall(cfg.Callback, tbActual.Text)
                    if cfg.TextDisappear then tbActual.Text = "" end
                end)
                tbActual.Text = cfg.Default

                AddConnection(click.MouseEnter, function()
                    T(card, 0.15, nil, nil, {BackgroundTransparency = 0.38})
                end)
                AddConnection(click.MouseLeave, function()
                    T(card, 0.15, nil, nil, {BackgroundTransparency = 0.50})
                end)
                AddConnection(click.MouseButton1Up, function()
                    tbActual:CaptureFocus()
                end)
            end

            function ef:AddColorpicker(cfg)
                cfg          = cfg or {}
                cfg.Name     = tostring(cfg.Name     or "Color")
                cfg.Default  = cfg.Default  or Color3.fromRGB(80, 120, 255)
                cfg.Callback = cfg.Callback or function() end
                cfg.Flag     = cfg.Flag     or nil
                cfg.Save     = cfg.Save     or false

                local ch, cs, cv = Color3.toHSV(cfg.Default)
                local cp = {Value = cfg.Default, Toggled = false, Type = "Colorpicker", Save = cfg.Save}
                local ColorInput, HueInput

                local colorSel = Create("ImageLabel", {
                    Size                   = UDim2.new(0, 14, 0, 14),
                    AnchorPoint            = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    Image                  = "http://www.roblox.com/asset/?id=4805639000",
                })
                local hueSel = Create("ImageLabel", {
                    Size                   = UDim2.new(0, 14, 0, 14),
                    Position               = UDim2.new(0.5, 0, 1-ch, 0),
                    AnchorPoint            = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    Image                  = "http://www.roblox.com/asset/?id=4805639000",
                })

                local colorMap = Create("ImageLabel", {
                    Size    = UDim2.new(1, -22, 1, 0),
                    Image   = "rbxassetid://4155801252",
                    Visible = false,
                }, {Create("UICorner", {CornerRadius = UDim.new(0, 4)}), colorSel})

                local hueBar = Create("Frame", {
                    Size     = UDim2.new(0, 16, 1, 0),
                    Position = UDim2.new(1, -16, 0, 0),
                    Visible  = false,
                }, {
                    Create("UIGradient", {Rotation = 270, Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,0,4)),
                        ColorSequenceKeypoint.new(0.20, Color3.fromRGB(234,255,0)),
                        ColorSequenceKeypoint.new(0.40, Color3.fromRGB(21,255,0)),
                        ColorSequenceKeypoint.new(0.60, Color3.fromRGB(0,255,255)),
                        ColorSequenceKeypoint.new(0.80, Color3.fromRGB(0,17,255)),
                        ColorSequenceKeypoint.new(0.90, Color3.fromRGB(255,0,251)),
                        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255,0,4)),
                    }}),
                    Create("UICorner", {CornerRadius = UDim.new(0, 4)}),
                    hueSel,
                })

                local cpInner = Create("Frame", {
                    Position         = UDim2.new(0, 0, 0, 32),
                    Size             = UDim2.new(1, 0, 1, -32),
                    BackgroundTransparency = 1,
                    ClipsDescendants = true,
                }, {
                    hueBar, colorMap,
                    Create("UIPadding", {
                        PaddingLeft   = UDim.new(0, 28),
                        PaddingRight  = UDim.new(0, 28),
                        PaddingTop    = UDim.new(0, 12),
                        PaddingBottom = UDim.new(0, 10),
                    }),
                })

                local click = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})

                local swatch = AddThemeObject(SetChildren(SetProps(
                    MakeElement("RoundFrame", cfg.Default, 0, 5), {
                    Size                   = UDim2.new(0, 22, 0, 22),
                    Position               = UDim2.new(1, -12, 0.5, 0),
                    AnchorPoint            = Vector2.new(1, 0.5),
                    BackgroundTransparency = 0,
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(60, 80, 175), Thickness = 1.5, Transparency = 0.25}),
                }), "Main")

                local card = AddThemeObject(SetChildren(SetProps(
                    MakeElement("RoundFrame", Color3.fromRGB(14, 16, 32), 0, 7), {
                    Size                   = UDim2.new(1, 0, 0, 38),
                    Parent                 = itemParent,
                    BackgroundTransparency = 0.50,
                }), {
                    SetChildren(SetProps(MakeElement("TFrame"), {
                        Size             = UDim2.new(1, 0, 0, 38),
                        ClipsDescendants = true,
                        Name             = "F",
                    }), {
                        AddThemeObject(SetProps(MakeElement("Label", cfg.Name, 14), {
                            Size     = UDim2.new(1, -14, 1, 0),
                            Position = UDim2.new(0, 14, 0, 0),
                            Font     = Enum.Font.GothamSemibold,
                            Name     = "Content",
                        }), "Text"),
                        swatch, click,
                        AddThemeObject(SetProps(MakeElement("Frame"), {
                            Size    = UDim2.new(1, 0, 0, 1),
                            Position= UDim2.new(0, 0, 1, -1),
                            Name    = "Line",
                            Visible = false,
                        }), "Stroke"),
                    }),
                    cpInner,
                    Create("UIStroke", {Color = Color3.fromRGB(48, 62, 145), Thickness = 1, Transparency = 0.45}),
                }), "Second")

                local function UpdateCP()
                    local col = Color3.fromHSV(ch, cs, cv)
                    swatch.BackgroundColor3 = col
                    colorMap.BackgroundColor3 = Color3.fromHSV(ch, 1, 1)
                    cp.Value = col
                    pcall(cfg.Callback, col)
                    SaveCfg()
                end

                AddConnection(click.MouseButton1Click, function()
                    cp.Toggled = not cp.Toggled
                    T(card, 0.15, Enum.EasingStyle.Quad, nil,
                      {Size = UDim2.new(1, 0, 0, cp.Toggled and 148 or 38)})
                    colorMap.Visible = cp.Toggled
                    hueBar.Visible   = cp.Toggled
                    card.F.Line.Visible = cp.Toggled
                end)

                AddConnection(colorMap.InputBegan, function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        if ColorInput then ColorInput:Disconnect() end
                        ColorInput = AddConnection(RunService.RenderStepped, function()
                            cs = math.clamp((Mouse.X - colorMap.AbsolutePosition.X) / colorMap.AbsoluteSize.X, 0, 1)
                            cv = 1 - math.clamp((Mouse.Y - colorMap.AbsolutePosition.Y) / colorMap.AbsoluteSize.Y, 0, 1)
                            colorSel.Position = UDim2.new(cs, 0, 1-cv, 0)
                            UpdateCP()
                        end)
                    end
                end)
                AddConnection(colorMap.InputEnded, function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 and ColorInput then
                        ColorInput:Disconnect()
                    end
                end)
                AddConnection(hueBar.InputBegan, function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        if HueInput then HueInput:Disconnect() end
                        HueInput = AddConnection(RunService.RenderStepped, function()
                            local hy = math.clamp((Mouse.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
                            hueSel.Position = UDim2.new(0.5, 0, hy, 0)
                            ch = 1 - hy
                            UpdateCP()
                        end)
                    end
                end)
                AddConnection(hueBar.InputEnded, function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 and HueInput then
                        HueInput:Disconnect()
                    end
                end)

                function cp:Set(col)
                    cp.Value = col
                    swatch.BackgroundColor3 = col
                    ch, cs, cv = Color3.toHSV(col)
                    pcall(cfg.Callback, col)
                end

                cp:Set(cp.Value)
                if cfg.Flag then Library.Flags[cfg.Flag] = cp end
                return cp
            end

            return ef
        end

        local ElementFunction = {}

        function ElementFunction:AddSection(sc)
            sc = sc or {}
            sc.Name = tostring(sc.Name or "Section")

            local headerRow = SetProps(MakeElement("TFrame"), {
                Size = UDim2.new(1, 0, 0, 18),
            })

            Create("Frame", {
                Size             = UDim2.new(0, 2, 0, 12),
                Position         = UDim2.new(0, 0, 0.5, 0),
                AnchorPoint      = Vector2.new(0, 0.5),
                BackgroundColor3 = Color3.fromRGB(80, 120, 255),
                BorderSizePixel  = 0,
                Parent           = headerRow,
            }, {
                Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
                Create("UIGradient", {
                    Color    = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 180, 255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(90,  55, 215)),
                    }),
                    Rotation = 90,
                }),
            })

            AddThemeObject(SetProps(MakeElement("Label", sc.Name, 12), {
                Size     = UDim2.new(1, -10, 1, 0),
                Position = UDim2.new(0, 8,  0, 0),
                Font     = Enum.Font.GothamBold,
                Parent   = headerRow,
            }), "TextDark")

            local holder = SetChildren(SetProps(MakeElement("TFrame"), {
                AnchorPoint = Vector2.new(0, 0),
                Size        = UDim2.new(1, 0, 1, -24),
                Position    = UDim2.new(0, 0, 0, 24),
                Name        = "Holder",
            }), {MakeElement("List", 0, 6)})

            local sFrame = SetChildren(SetProps(MakeElement("TFrame"), {
                Size   = UDim2.new(1, 0, 0, 28),
                Parent = ItemContainer,
            }), {headerRow, holder})

            AddConnection(holder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
                sFrame.Size  = UDim2.new(1, 0, 0, holder.UIListLayout.AbsoluteContentSize.Y + 32)
                holder.Size  = UDim2.new(1, 0, 0, holder.UIListLayout.AbsoluteContentSize.Y)
            end)

            local sf = {}
            for k,v in pairs(GetElements(holder)) do sf[k] = v end
            return sf
        end

        for k,v in pairs(GetElements(ItemContainer)) do ElementFunction[k] = v end

        if tc.PremiumOnly then
            for k in pairs(ElementFunction) do ElementFunction[k] = function() end end
            pcall(function() ItemContainer:FindFirstChildWhichIsA("UIListLayout"):Destroy() end)
            pcall(function() ItemContainer:FindFirstChildWhichIsA("UIPadding"):Destroy() end)
            SetChildren(SetProps(MakeElement("TFrame"), {
                Size = UDim2.new(1, 0, 1, 0), Parent = ItemContainer,
            }), {
                AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://3610239960"), {
                    Size             = UDim2.new(0, 16, 0, 16),
                    Position         = UDim2.new(0, 14, 0, 14),
                    ImageTransparency = 0.45,
                }), "Text"),
                AddThemeObject(SetProps(MakeElement("Label", "Premium Only", 14), {
                    Size             = UDim2.new(1, -36, 0, 14),
                    Position         = UDim2.new(0, 36, 0, 16),
                    TextTransparency = 0.45,
                }), "Text"),
            })
        end

        return ElementFunction
    end

    return TabFunction
end

function Library:Destroy()
    pcall(function() Container:Destroy() end)
end

return Library
