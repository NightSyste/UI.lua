local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Library = {
    Elements = {},
    ThemeObjects = {},
    Connections = {},
    Flags = {},
    Themes = {
        Default = {
            -- Glassmorphism: tief-dunkel mit leichter Transparenz-Illusion
            Main    = Color3.fromRGB(10, 11, 18),       -- fast schwarz, blau-getönt
            Second  = Color3.fromRGB(16, 18, 28),       -- Karten-Hintergrund
            Stroke  = Color3.fromRGB(55, 65, 110),      -- blau-lila Glasrand
            Divider = Color3.fromRGB(22, 25, 40),       -- dezente Trennlinie
            Text    = Color3.fromRGB(220, 225, 255),    -- leicht bläuliches Weiß
            TextDark= Color3.fromRGB(110, 120, 170),    -- gedämpftes Blau-Grau
            -- Akzentfarben (für Glow-Effekte)
            Accent  = Color3.fromRGB(90, 120, 255),     -- Indigo-Glow
            AccentB = Color3.fromRGB(140, 80, 255),     -- Violett-Glow
        }
    },
    SelectedTheme = "Default",
    Folder = nil,
    SaveCfg = false,
    Font = Enum.Font.Gotham
}

local function GetIcon(IconName)
    return nil
end

function Library:CleanupInstance()
    for _, instance in pairs(game:GetService("CoreGui"):GetChildren()) do
        if instance:IsA("ScreenGui") and
           instance.Name:match("^[A-Z]%d%d%d$") then
            instance:Destroy()
        end
    end
end

Library:CleanupInstance()
local Container = Instance.new("ScreenGui")
Container.Name = string.char(math.random(65, 90))..tostring(math.random(100, 999))
Container.DisplayOrder = 2147483647
Container.Parent = game:GetService("CoreGui")

function Library:IsRunning()
    return Container and Container.Parent == game:GetService("CoreGui")
end

local function AddConnection(Signal, Function)
    if (not Library:IsRunning()) then return end
    local SignalConnect = Signal:Connect(Function)
    table.insert(Library.Connections, SignalConnect)
    return SignalConnect
end

task.spawn(function()
    while (Library:IsRunning()) do wait() end
    for _, Connection in next, Library.Connections do
        Connection:Disconnect()
    end
end)

local function MakeDraggable(DragPoint, Main)
    local IsResizing = false
    pcall(function()
        local Dragging, DragInput, MousePos, FramePos = false
        DragPoint.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                if not IsResizing then
                    Dragging = true
                    MousePos = Input.Position
                    FramePos = Main.Position
                end
                Input.Changed:Connect(function()
                    if Input.UserInputState == Enum.UserInputState.End then
                        Dragging = false
                    end
                end)
            end
        end)
        DragPoint.InputChanged:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
                DragInput = Input
            end
        end)
        UserInputService.InputChanged:Connect(function(Input)
            if Input == DragInput and Dragging and not IsResizing then
                local Delta = Input.Position - MousePos
                TweenService:Create(Main, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    Position = UDim2.new(FramePos.X.Scale, FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)
                }):Play()
            end
        end)
    end)
    return function(resizing)
        IsResizing = resizing
        if resizing then Dragging = false end
    end
end

local function MakeResizable(ResizeButton, Main, MinSize, MaxSize, SetResizingCallback)
    pcall(function()
        local Resizing = false
        local StartSize, StartPos
        ResizeButton.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                Resizing = true
                if SetResizingCallback then SetResizingCallback(true) end
                StartSize = Main.Size
                StartPos = Vector2.new(Mouse.X, Mouse.Y)
            end
        end)
        ResizeButton.InputEnded:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                Resizing = false
                if SetResizingCallback then SetResizingCallback(false) end
            end
        end)
        UserInputService.InputChanged:Connect(function()
            if Resizing then
                local CurrentPos = Vector2.new(Mouse.X, Mouse.Y)
                local Delta = CurrentPos - StartPos
                local NewWidth  = math.clamp(StartSize.X.Offset + Delta.X, MinSize.X, MaxSize.X)
                local NewHeight = math.clamp(StartSize.Y.Offset + Delta.Y, MinSize.Y, MaxSize.Y)
                Main.Size = UDim2.new(0, NewWidth, 0, NewHeight)
            end
        end)
    end)
end

local function Create(Name, Properties, Children)
    local Object = Instance.new(Name)
    for i, v in next, Properties or {} do Object[i] = v end
    for i, v in next, Children or {} do v.Parent = Object end
    return Object
end

local function CreateElement(ElementName, ElementFunction)
    Library.Elements[ElementName] = function(...)
        return ElementFunction(...)
    end
end

local function MakeElement(ElementName, ...)
    return Library.Elements[ElementName](...)
end

local function SetProps(Element, Props)
    table.foreach(Props, function(Property, Value)
        Element[Property] = Value
    end)
    return Element
end

local function SetChildren(Element, Children)
    table.foreach(Children, function(_, Child)
        Child.Parent = Element
    end)
    return Element
end

local function Round(Number, Factor)
    local Result = math.floor(Number/Factor + (math.sign(Number) * 0.5)) * Factor
    if Result < 0 then Result = Result + Factor end
    return Result
end

local function ReturnProperty(Object)
    if Object:IsA("Frame") or Object:IsA("TextButton") then return "BackgroundColor3" end
    if Object:IsA("ScrollingFrame") then return "ScrollBarImageColor3" end
    if Object:IsA("UIStroke") then return "Color" end
    if Object:IsA("TextLabel") or Object:IsA("TextBox") then return "TextColor3" end
    if Object:IsA("ImageLabel") or Object:IsA("ImageButton") then return "ImageColor3" end
end

local function AddThemeObject(Object, Type)
    if not Library.ThemeObjects[Type] then Library.ThemeObjects[Type] = {} end
    table.insert(Library.ThemeObjects[Type], Object)
    Object[ReturnProperty(Object)] = Library.Themes[Library.SelectedTheme][Type]
    return Object
end

local function SetTheme()
    for Name, Type in pairs(Library.ThemeObjects) do
        for _, Object in pairs(Type) do
            Object[ReturnProperty(Object)] = Library.Themes[Library.SelectedTheme][Name]
        end
    end
end

local function PackColor(Color)
    return {R = Color.R * 255, G = Color.G * 255, B = Color.B * 255}
end

local function UnpackColor(Color)
    return Color3.fromRGB(Color.R, Color.G, Color.B)
end

local function LoadCfg(Config)
    local Data = HttpService:JSONDecode(Config)
    table.foreach(Data, function(a, b)
        if Library.Flags[a] then
            spawn(function()
                if Library.Flags[a].Type == "Colorpicker" then
                    Library.Flags[a]:Set(UnpackColor(b))
                else
                    Library.Flags[a]:Set(b)
                end
            end)
        end
    end)
end

local function SaveCfg(Name)
    local Data = {}
    for i, v in pairs(Library.Flags) do
        if v.Save then
            if v.Type == "Colorpicker" then
                Data[i] = PackColor(v.Value)
            else
                Data[i] = v.Value
            end
        end
    end
end

local WhitelistedMouse  = {Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3, Enum.UserInputType.Touch}
local BlacklistedKeys   = {Enum.KeyCode.Unknown, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Left, Enum.KeyCode.Down, Enum.KeyCode.Right, Enum.KeyCode.Slash, Enum.KeyCode.Tab, Enum.KeyCode.Backspace, Enum.KeyCode.Escape}

local function CheckKey(Table, Key)
    for _, v in next, Table do
        if v == Key then return true end
    end
end

-- ============================================================
-- ELEMENT FACTORY
-- ============================================================

CreateElement("Corner", function(Scale, Offset)
    return Create("UICorner", {CornerRadius = UDim.new(Scale or 0, Offset or 8)})
end)

CreateElement("Stroke", function(Color, Thickness)
    return Create("UIStroke", {
        Color = Color or Color3.fromRGB(55, 65, 110),
        Thickness = Thickness or 1
    })
end)

CreateElement("List", function(Scale, Offset)
    return Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(Scale or 0, Offset or 0)
    })
end)

CreateElement("Padding", function(Bottom, Left, Right, Top)
    return Create("UIPadding", {
        PaddingBottom = UDim.new(0, Bottom or 4),
        PaddingLeft   = UDim.new(0, Left   or 4),
        PaddingRight  = UDim.new(0, Right  or 4),
        PaddingTop    = UDim.new(0, Top    or 4)
    })
end)

CreateElement("TFrame", function()
    return Create("Frame", {BackgroundTransparency = 1})
end)

CreateElement("Frame", function(Color)
    return Create("Frame", {
        BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255),
        BorderSizePixel  = 0
    })
end)

CreateElement("RoundFrame", function(Color, Scale, Offset)
    return Create("Frame", {
        BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255),
        BorderSizePixel  = 0
    }, {
        Create("UICorner", {CornerRadius = UDim.new(Scale, Offset)})
    })
end)

CreateElement("Button", function()
    return Create("TextButton", {
        Text                = "",
        AutoButtonColor     = false,
        BackgroundTransparency = 1,
        BorderSizePixel     = 0
    })
end)

CreateElement("ScrollFrame", function(Color, Width)
    return Create("ScrollingFrame", {
        BackgroundTransparency  = 1,
        MidImage                = "rbxassetid://7445543667",
        BottomImage             = "rbxassetid://7445543667",
        TopImage                = "rbxassetid://7445543667",
        ScrollBarImageColor3    = Color,
        BorderSizePixel         = 0,
        ScrollBarThickness      = Width,
        CanvasSize              = UDim2.new(0, 0, 0, 0)
    })
end)

CreateElement("Image", function(ImageID)
    local ImageNew = Create("ImageLabel", {
        Image               = ImageID,
        BackgroundTransparency = 1
    })
    if GetIcon(ImageID) ~= nil then ImageNew.Image = GetIcon(ImageID) end
    return ImageNew
end)

CreateElement("ImageButton", function(ImageID)
    return Create("ImageButton", {
        Image               = ImageID,
        BackgroundTransparency = 1
    })
end)

CreateElement("Label", function(Text, TextSize, Transparency)
    return Create("TextLabel", {
        Text               = Text or "",
        TextColor3         = Color3.fromRGB(220, 225, 255),
        TextTransparency   = Transparency or 0,
        TextSize           = TextSize or 15,
        Font               = Enum.Font.GothamSemibold,
        RichText           = true,
        BackgroundTransparency = 1,
        TextXAlignment     = Enum.TextXAlignment.Left
    })
end)

-- ============================================================
-- NOTIFICATION SYSTEM
-- ============================================================

local NotificationHolder = SetProps(SetChildren(MakeElement("TFrame"), {
    SetProps(MakeElement("List"), {
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder           = Enum.SortOrder.LayoutOrder,
        VerticalAlignment   = Enum.VerticalAlignment.Bottom,
        Padding             = UDim.new(0, 6)
    })
}), {
    Position    = UDim2.new(1, -25, 1, -25),
    Size        = UDim2.new(0, 300, 1, -25),
    AnchorPoint = Vector2.new(1, 1),
    Parent      = Container
})

function Library:MakeNotification(NotificationConfig)
    spawn(function()
        NotificationConfig.Name    = NotificationConfig.Name    or "Notification"
        NotificationConfig.Content = NotificationConfig.Content or "Test"
        NotificationConfig.Image   = NotificationConfig.Image   or "rbxassetid://4384403532"
        NotificationConfig.Time    = NotificationConfig.Time    or 15

        local NotificationParent = SetProps(MakeElement("TFrame"), {
            Size          = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent        = NotificationHolder
        })

        -- Glass card
        local NotificationFrame = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(16, 18, 28), 0, 12), {
            Parent            = NotificationParent,
            Size              = UDim2.new(1, 0, 0, 0),
            Position          = UDim2.new(1, -55, 0, 0),
            BackgroundTransparency = 0.15,
            AutomaticSize     = Enum.AutomaticSize.Y
        }), {
            -- Glass border glow
            Create("UIStroke", {Color = Color3.fromRGB(70, 90, 200), Thickness = 1, Transparency = 0.4}),
            MakeElement("Padding", 12, 12, 12, 12),
            SetProps(MakeElement("Image", NotificationConfig.Image), {
                Size         = UDim2.new(0, 20, 0, 20),
                ImageColor3  = Color3.fromRGB(160, 180, 255),
                Name         = "Icon"
            }),
            SetProps(MakeElement("Label", NotificationConfig.Name, 15), {
                Size         = UDim2.new(1, -30, 0, 20),
                Position     = UDim2.new(0, 30, 0, 0),
                Font         = Enum.Font.GothamBold,
                TextColor3   = Color3.fromRGB(220, 225, 255),
                Name         = "Title"
            }),
            SetProps(MakeElement("Label", NotificationConfig.Content, 13), {
                Size         = UDim2.new(1, 0, 0, 0),
                Position     = UDim2.new(0, 0, 0, 25),
                Font         = Enum.Font.Gotham,
                TextColor3   = Color3.fromRGB(130, 145, 210),
                Name         = "Content",
                AutomaticSize = Enum.AutomaticSize.Y,
                TextWrapped  = true
            })
        })

        TweenService:Create(NotificationFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 0, 0, 0)}):Play()
        wait(NotificationConfig.Time - 0.88)
        TweenService:Create(NotificationFrame.Icon,    TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
        TweenService:Create(NotificationFrame,         TweenInfo.new(0.8, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.7}):Play()
        wait(0.3)
        TweenService:Create(NotificationFrame.UIStroke,TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0.9}):Play()
        TweenService:Create(NotificationFrame.Title,   TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.5}):Play()
        TweenService:Create(NotificationFrame.Content, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.6}):Play()
        wait(0.05)
        NotificationFrame:TweenPosition(UDim2.new(1, 20, 0, 0), 'In', 'Quint', 0.8, true)
        wait(1.35)
        NotificationFrame:Destroy()
    end)
end

function Library:Init()
    if Library.SaveCfg then
        pcall(function()
            if isfile(Library.Folder .. "/" .. game.GameId .. ".txt") then
                LoadCfg(readfile(Library.Folder .. "/" .. game.GameId .. ".txt"))
                Library:MakeNotification({
                    Name    = "Configuration",
                    Content = "Auto-loaded configuration for the game " .. game.GameId .. ".",
                    Time    = 5
                })
            end
        end)
    end
end

-- ============================================================
-- WINDOW
-- ============================================================

function Library:MakeWindow(WindowConfig)
    local FirstTab  = true
    local Minimized = false
    local Loaded    = false
    local UIHidden  = false

    WindowConfig = WindowConfig or {}
    WindowConfig.Name             = WindowConfig.Name             or "Loading Froxy"
    WindowConfig.ConfigFolder     = WindowConfig.ConfigFolder     or WindowConfig.Name
    WindowConfig.SaveConfig       = WindowConfig.SaveConfig       or false
    WindowConfig.HidePremium      = WindowConfig.HidePremium      or false
    if WindowConfig.IntroEnabled == nil then WindowConfig.IntroEnabled = true end
    WindowConfig.IntroToggleIcon  = WindowConfig.IntroToggleIcon  or "rbxassetid://138394234566692"
    WindowConfig.IntroText        = WindowConfig.IntroText        or "Botting Night"
    WindowConfig.CloseCallback    = WindowConfig.CloseCallback    or function() end
    WindowConfig.ShowIcon         = WindowConfig.ShowIcon         or false
    WindowConfig.Icon             = WindowConfig.Icon             or "rbxassetid://8834748103"
    WindowConfig.IntroIcon        = WindowConfig.IntroIcon        or "rbxassetid://138394234566692"
    Library.Folder                = WindowConfig.ConfigFolder
    Library.SaveCfg               = WindowConfig.SaveConfig

    if WindowConfig.SaveConfig then
        if not isfolder(WindowConfig.ConfigFolder) then makefolder(WindowConfig.ConfigFolder) end
    end

    -- ── Sidebar ScrollFrame ──────────────────────────────────────────
    local TabHolder = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(90, 110, 200), 3), {
        Size = UDim2.new(1, 0, 1, -50)
    }), {
        MakeElement("List"),
        MakeElement("Padding", 6, 0, 0, 6)
    }), "Divider")

    AddConnection(TabHolder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        TabHolder.CanvasSize = UDim2.new(0, 0, 0, TabHolder.UIListLayout.AbsoluteContentSize.Y + 16)
    end)

    -- ── Window Buttons ───────────────────────────────────────────────
    local CloseBtn = SetChildren(SetProps(MakeElement("Button"), {
        Size = UDim2.new(0.33, 0, 1, 0),
        Position = UDim2.new(0.66, 0, 0, 0)
    }), {
        AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072725342"), {
            Position = UDim2.new(0, 9, 0, 6),
            Size     = UDim2.new(0, 18, 0, 18)
        }), "Text")
    })

    local MinimizeBtn = SetChildren(SetProps(MakeElement("Button"), {
        Size     = UDim2.new(0.33, 0, 1, 0),
        Position = UDim2.new(0.33, 0, 0, 0)
    }), {
        AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072719338"), {
            Position = UDim2.new(0, 9, 0, 6),
            Size     = UDim2.new(0, 18, 0, 18),
            Name     = "Ico"
        }), "Text")
    })

    local ResizeBtn = SetChildren(SetProps(MakeElement("Button"), {
        Size     = UDim2.new(0.33, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0)
    }), {
        AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://117273761878755"), {
            Position = UDim2.new(0, 9, 0, 6),
            Size     = UDim2.new(0, 18, 0, 18)
        }), "Text")
    })

    local DragPoint = SetProps(MakeElement("TFrame"), {
        Size = UDim2.new(1, 0, 0, 50)
    })

    -- ── Sidebar ──────────────────────────────────────────────────────
    -- Subtiler Indigo-Gradient auf der Sidebar via UIGradient
    local SidebarGradient = Create("UIGradient", {
        Color    = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 20, 38)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 13, 24))
        }),
        Rotation = 90
    })

    local WindowStuff = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(16, 18, 30), 0, 12), {
        Size                 = UDim2.new(0, 148, 1, -50),
        Position             = UDim2.new(0, 0, 0, 50),
        BackgroundTransparency = 0,
    }), {
        SidebarGradient,
        -- Subtiler rechter Trennstrich (Glas-Kante)
        SetProps(MakeElement("Frame"), {
            Size             = UDim2.new(0, 1, 1, 0),
            Position         = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(55, 65, 130),
            BackgroundTransparency = 0.5,
            BorderSizePixel  = 0
        }),
        TabHolder,
        -- User-Info unten
        SetChildren(SetProps(MakeElement("TFrame"), {
            Size     = UDim2.new(1, 0, 0, 50),
            Position = UDim2.new(0, 0, 1, -50)
        }), {
            AddThemeObject(SetProps(MakeElement("Frame"), {
                Size = UDim2.new(1, 0, 0, 1)
            }), "Stroke"),
            AddThemeObject(SetChildren(SetProps(MakeElement("Frame"), {
                AnchorPoint          = Vector2.new(0, 0.5),
                Size                 = UDim2.new(0, 30, 0, 30),
                Position             = UDim2.new(0, 10, 0.5, 0),
                BackgroundTransparency = 1
            }), {
                SetProps(MakeElement("Image", "https://www.roblox.com/headshot-thumbnail/image?userId="..LocalPlayer.UserId.."&width=420&height=420&format=png"), {
                    Size = UDim2.new(1, 0, 1, 0)
                }),
                MakeElement("Corner", 1)
            }), "Divider"),
            -- Glow-Ring um Avatar
            SetChildren(SetProps(MakeElement("TFrame"), {
                AnchorPoint = Vector2.new(0, 0.5),
                Size        = UDim2.new(0, 32, 0, 32),
                Position    = UDim2.new(0, 9, 0.5, 0)
            }), {
                Create("UIStroke", {Color = Color3.fromRGB(90, 120, 255), Thickness = 1.5, Transparency = 0.3}),
                MakeElement("Corner", 1)
            }),
            AddThemeObject(SetProps(MakeElement("Label", "Night", WindowConfig.HidePremium and 14 or 13), {
                Size     = UDim2.new(1, -55, 0, 13),
                Position = WindowConfig.HidePremium and UDim2.new(0, 50, 0, 19) or UDim2.new(0, 50, 0, 12),
                Font     = Enum.Font.GothamBold,
                ClipsDescendants = true
            }), "Text"),
            AddThemeObject(SetProps(MakeElement("Label", "Best", 11), {
                Size     = UDim2.new(1, -55, 0, 12),
                Position = UDim2.new(0, 50, 1, -24),
                Visible  = not WindowConfig.HidePremium
            }), "TextDark")
        }),
    }), "Second")

    -- ── Topbar ───────────────────────────────────────────────────────
    local WindowName = AddThemeObject(SetProps(MakeElement("Label", WindowConfig.Name, 14), {
        Size     = UDim2.new(1, -30, 2, 0),
        Position = UDim2.new(0, 25, 0, -24),
        Font     = Enum.Font.GothamBlack,
        TextSize = 20
    }), "Text")

    -- Schmale Glow-Linie unter dem Topbar (Glasmorphismus-Trennlinie)
    local WindowTopBarLine = SetProps(MakeElement("Frame"), {
        Size             = UDim2.new(1, 0, 0, 1),
        Position         = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Color3.fromRGB(70, 90, 200),
        BackgroundTransparency = 0.5,
        BorderSizePixel  = 0
    })

    -- Buttons-Container (Resize | Minimize | Close) — Glasstyle
    local BtnContainer = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(18, 20, 35), 0, 8), {
        Size     = UDim2.new(0, 105, 0, 28),
        Position = UDim2.new(1, -125, 0, 11),
        BackgroundTransparency = 0.3
    }), {
        Create("UIStroke", {Color = Color3.fromRGB(55, 65, 130), Thickness = 1, Transparency = 0.4}),
        -- Trennstriche zwischen Buttons
        SetProps(MakeElement("Frame"), {
            Size             = UDim2.new(0, 1, 0.7, 0),
            Position         = UDim2.new(0.33, 0, 0.15, 0),
            BackgroundColor3 = Color3.fromRGB(55, 65, 130),
            BorderSizePixel  = 0,
            BackgroundTransparency = 0.4
        }),
        SetProps(MakeElement("Frame"), {
            Size             = UDim2.new(0, 1, 0.7, 0),
            Position         = UDim2.new(0.66, 0, 0.15, 0),
            BackgroundColor3 = Color3.fromRGB(55, 65, 130),
            BorderSizePixel  = 0,
            BackgroundTransparency = 0.4
        }),
        ResizeBtn,
        MinimizeBtn,
        CloseBtn
    }), "Second")

    local TopBar = SetProps(MakeElement("TFrame"), {
        Size             = UDim2.new(1, 0, 0, 50),
        Name             = "TopBar",
        ClipsDescendants = false
    })

    -- ── Main Window — Glassmorphism ──────────────────────────────────
    -- Haupt-Hintergrund: tief dunkel-blau mit leichter Transparenz
    local MainWindowGradient = Create("UIGradient", {
        Color    = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 15, 26)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(9, 10, 20))
        }),
        Rotation = 130
    })

    local MainWindow = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(10, 11, 20), 0, 12), {
        Parent              = Container,
        Position            = UDim2.new(0.5, -307, 0.5, -172),
        Size                = UDim2.new(0, 615, 0, 344),
        ClipsDescendants    = true,
        BackgroundTransparency = 0.05
    }), {
        MainWindowGradient,
        -- Äußerer Glow-Stroke (Glasrand)
        Create("UIStroke", {Color = Color3.fromRGB(70, 90, 200), Thickness = 1.2, Transparency = 0.35}),
        SetChildren(TopBar, {
            WindowName,
            WindowTopBarLine,
            BtnContainer
        }),
        DragPoint,
        WindowStuff
    }), "Main")

    if WindowConfig.ShowIcon then
        WindowName.Position = UDim2.new(0, 60, 0, -24)
        local WindowIcon = SetProps(MakeElement("Image", WindowConfig.Icon), {
            Size     = UDim2.new(0, 30, 0, 30),
            Position = UDim2.new(0, 20, 0, 10)
        })
        WindowIcon.Parent = TopBar
    end

    local SetResizingCallback = MakeDraggable(DragPoint, MainWindow)
    MakeResizable(ResizeBtn, MainWindow, Vector2.new(400, 250), Vector2.new(1200, 800), SetResizingCallback)

    -- ── Mobile Reopen Button ──────────────────────────────────────────
    local MobileReopenButton = SetChildren(SetProps(MakeElement("Button"), {
        Parent              = Container,
        Size                = UDim2.new(0, 40, 0, 40),
        Position            = UDim2.new(0.5, -20, 0, 20),
        BackgroundColor3    = Color3.fromRGB(16, 18, 30),
        BackgroundTransparency = 0.1,
        Visible             = false
    }), {
        Create("UIStroke", {Color = Color3.fromRGB(70, 90, 200), Thickness = 1.2, Transparency = 0.3}),
        SetProps(MakeElement("Image", WindowConfig.IntroToggleIcon or "http://www.roblox.com/asset/?id=8834748103"), {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position    = UDim2.new(0.5, 0, 0.5, 0),
            Size        = UDim2.new(0.7, 0, 0.7, 0),
            ImageColor3 = Color3.fromRGB(160, 180, 255)
        }),
        MakeElement("Corner", 1)
    })

    AddConnection(CloseBtn.MouseButton1Up, function()
        MainWindow.Visible = false
        if UserInputService.TouchEnabled then MobileReopenButton.Visible = true end
        UIHidden = true
        Library:MakeNotification({
            Name    = "Interface Hidden",
            Content = UserInputService.TouchEnabled and "Tap the button or Left Control to reopen the interface" or "Press Left Control to reopen the interface",
            Time    = 5
        })
        WindowConfig.CloseCallback()
    end)

    AddConnection(UserInputService.InputBegan, function(Input)
        if Input.KeyCode == Enum.KeyCode.LeftControl and UIHidden == true then
            MainWindow.Visible      = true
            MobileReopenButton.Visible = false
        end
    end)

    AddConnection(MobileReopenButton.Activated, function()
        MainWindow.Visible         = true
        MobileReopenButton.Visible = false
    end)

    AddConnection(MinimizeBtn.MouseButton1Up, function()
        if Minimized then
            TweenService:Create(MainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, 615, 0, 344)}):Play()
            MinimizeBtn.Ico.Image = "rbxassetid://7072719338"
            wait(.02)
            MainWindow.ClipsDescendants = false
            WindowStuff.Visible    = true
            WindowTopBarLine.Visible = true
        else
            MainWindow.ClipsDescendants = true
            WindowTopBarLine.Visible = false
            MinimizeBtn.Ico.Image = "rbxassetid://7072720870"
            TweenService:Create(MainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, WindowName.TextBounds.X + 140, 0, 50)}):Play()
            wait(0.1)
            WindowStuff.Visible = false
        end
        Minimized = not Minimized
    end)

    -- ── Intro Sequence ───────────────────────────────────────────────
    local function LoadSequence()
        MainWindow.Visible = false
        local LoadSequenceLogo = SetProps(MakeElement("Image", WindowConfig.IntroIcon), {
            Parent           = Container,
            AnchorPoint      = Vector2.new(0.5, 0.5),
            Position         = UDim2.new(0.5, 0, 0.4, 0),
            Size             = UDim2.new(0, 28, 0, 28),
            ImageColor3      = Color3.fromRGB(160, 180, 255),
            ImageTransparency = 1
        })
        local LoadSequenceText = SetProps(MakeElement("Label", WindowConfig.IntroText, 14), {
            Parent           = Container,
            Size             = UDim2.new(1, 0, 1, 0),
            AnchorPoint      = Vector2.new(0.5, 0.5),
            Position         = UDim2.new(0.5, 19, 0.5, 0),
            TextXAlignment   = Enum.TextXAlignment.Center,
            Font             = Enum.Font.GothamBold,
            TextColor3       = Color3.fromRGB(180, 200, 255),
            TextTransparency = 1
        })
        TweenService:Create(LoadSequenceLogo, TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
        wait(0.8)
        TweenService:Create(LoadSequenceLogo, TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, -(LoadSequenceText.TextBounds.X/2), 0.5, 0)}):Play()
        wait(0.3)
        TweenService:Create(LoadSequenceText, TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
        wait(2)
        TweenService:Create(LoadSequenceText, TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1}):Play()
        MainWindow.Visible = true
        LoadSequenceLogo:Destroy()
        LoadSequenceText:Destroy()
    end

    if WindowConfig.IntroEnabled then LoadSequence() end

    -- ============================================================
    -- TAB SYSTEM
    -- ============================================================

    local TabFunction = {}
    function TabFunction:MakeTab(TabConfig)
        TabConfig = TabConfig or {}
        TabConfig.Name        = TabConfig.Name        or "Tab"
        TabConfig.Icon        = TabConfig.Icon        or ""
        TabConfig.PremiumOnly = TabConfig.PremiumOnly or false

        -- ── Tab Button ──────────────────────────────────────────────
        local TabFrame = SetChildren(SetProps(MakeElement("Button"), {
            Size     = UDim2.new(1, 0, 0, 30),
            Parent   = TabHolder,
            BackgroundTransparency = 1
        }), {
            -- Aktiver Indikator-Strich (links, standardmäßig unsichtbar)
            SetProps(MakeElement("Frame"), {
                Size             = UDim2.new(0, 2, 0, 16),
                Position         = UDim2.new(0, 0, 0.5, 0),
                AnchorPoint      = Vector2.new(0, 0.5),
                BackgroundColor3 = Color3.fromRGB(90, 120, 255),
                BackgroundTransparency = 1,
                BorderSizePixel  = 0,
                Name             = "ActiveBar"
            }),
            AddThemeObject(SetProps(MakeElement("Image", TabConfig.Icon), {
                AnchorPoint      = Vector2.new(0, 0.5),
                Size             = UDim2.new(0, 14, 0, 14),
                Position         = UDim2.new(0, 14, 0.5, 0),
                ImageTransparency = 0.55,
                Name             = "Ico"
            }), "Text"),
            SetProps(MakeElement("Label", TabConfig.Name, 13), {
                Size             = UDim2.new(1, -35, 1, 0),
                Position         = UDim2.new(0, 32, 0, 0),
                Font             = Enum.Font.GothamSemibold,
                TextTransparency = 0.45,
                TextColor3       = Color3.fromRGB(160, 175, 230),
                Name             = "Title"
            })
        })

        -- Glow-Pill beim Hover (semi-transparent blau)
        local HoverBg = SetProps(MakeElement("RoundFrame", Color3.fromRGB(40, 55, 120), 0, 6), {
            Size                 = UDim2.new(1, -8, 1, -4),
            Position             = UDim2.new(0, 4, 0, 2),
            BackgroundTransparency = 1,
            ZIndex               = 0,
            Name                 = "HoverBg"
        })
        HoverBg.Parent = TabFrame

        AddConnection(TabFrame.MouseEnter, function()
            TweenService:Create(HoverBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.82}):Play()
        end)
        AddConnection(TabFrame.MouseLeave, function()
            TweenService:Create(HoverBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
        end)

        -- ── Tab Content ─────────────────────────────────────────────
        local Container = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(90, 110, 200), 4), {
            Size     = UDim2.new(1, -148, 1, -50),
            Position = UDim2.new(0, 148, 0, 50),
            Parent   = MainWindow,
            Visible  = false,
            Name     = "ItemContainer"
        }), {
            MakeElement("List", 0, 6),
            MakeElement("Padding", 14, 10, 10, 14)
        }), "Divider")

        AddConnection(Container.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
            Container.CanvasSize = UDim2.new(0, 0, 0, Container.UIListLayout.AbsoluteContentSize.Y + 30)
        end)

        local ClickSound = Instance.new("Sound")
        ClickSound.SoundId = "rbxassetid://6895079853"
        ClickSound.Volume  = 0.6
        ClickSound.Parent  = TabFrame

        if FirstTab then
            FirstTab = false
            TabFrame.Ico.ImageTransparency     = 0
            TabFrame.Ico.ImageColor3           = Color3.fromRGB(140, 170, 255)
            TabFrame.Title.TextTransparency    = 0
            TabFrame.Title.TextColor3          = Color3.fromRGB(200, 215, 255)
            TabFrame.Title.Font                = Enum.Font.GothamBold
            TabFrame.ActiveBar.BackgroundTransparency = 0
            Container.Visible = true
        end

        AddConnection(TabFrame.MouseButton1Click, function()
            ClickSound:Play()
            -- Alle Tabs deaktivieren
            for _, Tab in next, TabHolder:GetChildren() do
                if Tab:IsA("TextButton") then
                    Tab.Title.Font = Enum.Font.GothamSemibold
                    TweenService:Create(Tab.Ico,   TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 0.55, ImageColor3 = Color3.fromRGB(120, 135, 190)}):Play()
                    TweenService:Create(Tab.Title, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {TextTransparency  = 0.45, TextColor3  = Color3.fromRGB(130, 145, 200)}):Play()
                    if Tab:FindFirstChild("ActiveBar") then
                        TweenService:Create(Tab.ActiveBar, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
                    end
                end
            end
            for _, ItemContainer in next, MainWindow:GetChildren() do
                if ItemContainer.Name == "ItemContainer" then
                    ItemContainer.Visible = false
                end
            end
            -- Aktiven Tab highlighten
            TweenService:Create(TabFrame.Ico,   TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 0, ImageColor3 = Color3.fromRGB(140, 170, 255)}):Play()
            TweenService:Create(TabFrame.Title, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {TextTransparency  = 0, TextColor3  = Color3.fromRGB(200, 215, 255)}):Play()
            TweenService:Create(TabFrame.ActiveBar, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
            TabFrame.Title.Font = Enum.Font.GothamBold
            Container.Visible   = true
        end)

        -- ============================================================
        -- ELEMENTS
        -- ============================================================

        local function GetElements(ItemParent)
            local ElementFunction = {}

            -- ── Label ───────────────────────────────────────────────
            function ElementFunction:AddLabel(Text)
                local LabelFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(16, 18, 30), 0, 7), {
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundTransparency = 0.1,
                    Parent = ItemParent
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(55, 65, 130), Thickness = 1, Transparency = 0.5}),
                    AddThemeObject(SetProps(MakeElement("Label", Text, 14), {
                        Size     = UDim2.new(1, -12, 1, 0),
                        Position = UDim2.new(0, 12, 0, 0),
                        Font     = Enum.Font.GothamSemibold,
                        Name     = "Content"
                    }), "Text")
                }), "Second")

                local LabelFunction = {}
                function LabelFunction:Set(ToChange)
                    LabelFrame.Content.Text = ToChange
                end
                return LabelFunction
            end

            -- ── Paragraph ───────────────────────────────────────────
            function ElementFunction:AddParagraph(Text, Content)
                Text    = Text    or "Text"
                Content = Content or "Content"

                local ParagraphFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(16, 18, 30), 0, 7), {
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundTransparency = 0.1,
                    Parent = ItemParent
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(55, 65, 130), Thickness = 1, Transparency = 0.5}),
                    AddThemeObject(SetProps(MakeElement("Label", Text, 14), {
                        Size     = UDim2.new(1, -12, 0, 14),
                        Position = UDim2.new(0, 12, 0, 10),
                        Font     = Enum.Font.GothamBold,
                        Name     = "Title"
                    }), "Text"),
                    AddThemeObject(SetProps(MakeElement("Label", "", 13), {
                        Size     = UDim2.new(1, -24, 0, 0),
                        Position = UDim2.new(0, 12, 0, 26),
                        Font     = Enum.Font.Gotham,
                        Name     = "Content",
                        TextWrapped = true
                    }), "TextDark")
                }), "Second")

                AddConnection(ParagraphFrame.Content:GetPropertyChangedSignal("Text"), function()
                    ParagraphFrame.Content.Size = UDim2.new(1, -24, 0, ParagraphFrame.Content.TextBounds.Y)
                    ParagraphFrame.Size = UDim2.new(1, 0, 0, ParagraphFrame.Content.TextBounds.Y + 35)
                end)
                ParagraphFrame.Content.Text = Content

                local ParagraphFunction = {}
                function ParagraphFunction:Set(ToChange)
                    ParagraphFrame.Content.Text = ToChange
                end
                return ParagraphFunction
            end

            -- ── Button — Glassmorphism ───────────────────────────────
            function ElementFunction:AddButton(ButtonConfig)
                ButtonConfig          = ButtonConfig          or {}
                ButtonConfig.Name     = ButtonConfig.Name     or "Button"
                ButtonConfig.Callback = ButtonConfig.Callback or function() end

                local Button = {}

                local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})

                -- Linke Akzentlinie (Indigo-Glow)
                local AccentBar = SetChildren(SetProps(MakeElement("Frame"), {
                    Size             = UDim2.new(0, 2, 0, 14),
                    Position         = UDim2.new(0, 0, 0.5, 0),
                    AnchorPoint      = Vector2.new(0, 0.5),
                    BackgroundColor3 = Color3.fromRGB(90, 120, 255),
                    BackgroundTransparency = 0.35,
                    BorderSizePixel  = 0
                }), {
                    Create("UICorner", {CornerRadius = UDim.new(0, 2)})
                })

                -- Pfeil rechts
                local Arrow = Create("TextLabel", {
                    Size             = UDim2.new(0, 20, 1, 0),
                    Position         = UDim2.new(1, -28, 0, 0),
                    BackgroundTransparency = 1,
                    Text             = "›",
                    TextColor3       = Color3.fromRGB(70, 90, 160),
                    TextSize         = 18,
                    Font             = Enum.Font.GothamBold,
                    TextXAlignment   = Enum.TextXAlignment.Center,
                    Name             = "Arrow"
                })

                -- Hover Glow-Schimmer (oben im Frame)
                local ButtonGlow = SetProps(MakeElement("RoundFrame", Color3.fromRGB(60, 90, 200), 0, 7), {
                    Size             = UDim2.new(1, 0, 0, 1),
                    Position         = UDim2.new(0, 0, 0, 0),
                    BackgroundTransparency = 1
                })

                local ButtonFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(16, 18, 30), 0, 7), {
                    Size             = UDim2.new(1, 0, 0, 36),
                    Parent           = ItemParent,
                    BackgroundTransparency = 0.1
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(55, 65, 130), Thickness = 1, Transparency = 0.5, Name = "GlassStroke"}),
                    ButtonGlow,
                    AccentBar,
                    AddThemeObject(SetProps(MakeElement("Label", ButtonConfig.Name, 14), {
                        Size     = UDim2.new(1, -45, 1, 0),
                        Position = UDim2.new(0, 14, 0, 0),
                        Font     = Enum.Font.GothamSemibold,
                        Name     = "Content"
                    }), "Text"),
                    Arrow,
                    Click
                }), "Second")

                -- Hover: Glasrand leuchtet auf, Pfeil bewegt sich
                AddConnection(Click.MouseEnter, function()
                    TweenService:Create(ButtonFrame.GlassStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Color = Color3.fromRGB(80, 110, 220), Transparency = 0.1}):Play()
                    TweenService:Create(ButtonFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.04}):Play()
                    TweenService:Create(Arrow, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {TextColor3 = Color3.fromRGB(120, 160, 255), Position = UDim2.new(1, -24, 0, 0)}):Play()
                    TweenService:Create(ButtonGlow, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.7}):Play()
                end)

                AddConnection(Click.MouseLeave, function()
                    TweenService:Create(ButtonFrame.GlassStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Color = Color3.fromRGB(55, 65, 130), Transparency = 0.5}):Play()
                    TweenService:Create(ButtonFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.1}):Play()
                    TweenService:Create(Arrow, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {TextColor3 = Color3.fromRGB(70, 90, 160), Position = UDim2.new(1, -28, 0, 0)}):Play()
                    TweenService:Create(ButtonGlow, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
                end)

                AddConnection(Click.MouseButton1Down, function()
                    TweenService:Create(ButtonFrame, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {BackgroundTransparency = 0}):Play()
                    TweenService:Create(AccentBar, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 2, 0, 22)}):Play()
                end)

                AddConnection(Click.MouseButton1Up, function()
                    TweenService:Create(ButtonFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.04}):Play()
                    TweenService:Create(AccentBar, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 2, 0, 14)}):Play()
                    spawn(function() ButtonConfig.Callback() end)
                end)

                function Button:Set(ButtonText)
                    ButtonFrame.Content.Text = ButtonText
                end
                return Button
            end

            -- ── Toggle — iOS-Pill Glassmorphism ──────────────────────
            function ElementFunction:AddToggle(ToggleConfig)
                ToggleConfig          = ToggleConfig          or {}
                ToggleConfig.Name     = ToggleConfig.Name     or "Toggle"
                ToggleConfig.Default  = ToggleConfig.Default  or false
                ToggleConfig.Callback = ToggleConfig.Callback or function() end
                ToggleConfig.Color    = ToggleConfig.Color    or Color3.fromRGB(90, 120, 255)
                ToggleConfig.Flag     = ToggleConfig.Flag     or nil
                ToggleConfig.Save     = ToggleConfig.Save     or false

                local Toggle = {Value = ToggleConfig.Default, Save = ToggleConfig.Save}

                local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})

                -- Track (Pill)
                local Track = Create("Frame", {
                    Size             = UDim2.new(0, 38, 0, 21),
                    Position         = UDim2.new(1, -48, 0.5, 0),
                    AnchorPoint      = Vector2.new(0, 0.5),
                    BackgroundColor3 = Color3.fromRGB(14, 16, 28),
                    BorderSizePixel  = 0,
                    Name             = "Track"
                })
                local _tc1 = Create("UICorner", {CornerRadius = UDim.new(1, 0)})
                _tc1.Parent = Track
                local TrackStroke = Create("UIStroke", {
                    Color      = Color3.fromRGB(55, 65, 130),
                    Thickness  = 1,
                    Transparency = 0.3,
                    Name       = "Stroke"
                })
                TrackStroke.Parent = Track

                -- Inneres Glow-Overlay (nur wenn aktiv)
                local TrackGlow = Create("Frame", {
                    Size             = UDim2.new(1, 0, 1, 0),
                    BackgroundColor3 = ToggleConfig.Color,
                    BackgroundTransparency = 1,
                    BorderSizePixel  = 0,
                    Name             = "Glow"
                })
                local _tc2 = Create("UICorner", {CornerRadius = UDim.new(1, 0)})
                _tc2.Parent = TrackGlow
                TrackGlow.Parent = Track

                -- Thumb (runder Knopf)
                local Thumb = Create("Frame", {
                    Size             = UDim2.new(0, 15, 0, 15),
                    Position         = UDim2.new(0, 3, 0.5, 0),
                    AnchorPoint      = Vector2.new(0, 0.5),
                    BackgroundColor3 = Color3.fromRGB(100, 115, 170),
                    BorderSizePixel  = 0,
                    Name             = "Thumb"
                })
                local _tc3 = Create("UICorner", {CornerRadius = UDim.new(1, 0)})
                _tc3.Parent = Thumb
                Thumb.Parent = Track

                local ToggleFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(16, 18, 30), 0, 7), {
                    Size             = UDim2.new(1, 0, 0, 38),
                    Parent           = ItemParent,
                    BackgroundTransparency = 0.1
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(55, 65, 130), Thickness = 1, Transparency = 0.5, Name = "GlassStroke"}),
                    AddThemeObject(SetProps(MakeElement("Label", ToggleConfig.Name, 14), {
                        Size     = UDim2.new(1, -65, 1, 0),
                        Position = UDim2.new(0, 12, 0, 0),
                        Font     = Enum.Font.GothamSemibold,
                        Name     = "Content"
                    }), "Text"),
                    Track,
                    Click
                }), "Second")

                function Toggle:Set(Value)
                    Toggle.Value = Value
                    if Toggle.Value then
                        -- Aktiv: farbiger Track + Glow + weißer Thumb rechts
                        TweenService:Create(Track,      TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundColor3 = ToggleConfig.Color}):Play()
                        TweenService:Create(TrackStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Color = ToggleConfig.Color, Transparency = 0.6}):Play()
                        TweenService:Create(TrackGlow,  TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.55}):Play()
                        TweenService:Create(Thumb,      TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 20, 0.5, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
                        TweenService:Create(ToggleFrame.GlassStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Color = ToggleConfig.Color, Transparency = 0.55}):Play()
                    else
                        TweenService:Create(Track,      TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(14, 16, 28)}):Play()
                        TweenService:Create(TrackStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Color = Color3.fromRGB(55, 65, 130), Transparency = 0.3}):Play()
                        TweenService:Create(TrackGlow,  TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
                        TweenService:Create(Thumb,      TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = Color3.fromRGB(80, 95, 150)}):Play()
                        TweenService:Create(ToggleFrame.GlassStroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Color = Color3.fromRGB(55, 65, 130), Transparency = 0.5}):Play()
                    end
                    ToggleConfig.Callback(Toggle.Value)
                end

                Toggle:Set(Toggle.Value)

                AddConnection(Click.MouseEnter, function()
                    TweenService:Create(ToggleFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.04}):Play()
                end)
                AddConnection(Click.MouseLeave, function()
                    TweenService:Create(ToggleFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.1}):Play()
                end)
                AddConnection(Click.MouseButton1Down, function()
                    -- Thumb-Stretch beim Drücken
                    TweenService:Create(Thumb, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 18, 0, 15)}):Play()
                end)
                AddConnection(Click.MouseButton1Up, function()
                    TweenService:Create(Thumb, TweenInfo.new(0.15, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 15, 0, 15)}):Play()
                    SaveCfg(game.GameId)
                    Toggle:Set(not Toggle.Value)
                end)

                if ToggleConfig.Flag then Library.Flags[ToggleConfig.Flag] = Toggle end
                return Toggle
            end

            -- ── Slider — Glassmorphism mit Glow-Fill ─────────────────
            function ElementFunction:AddSlider(SliderConfig)
                SliderConfig             = SliderConfig             or {}
                SliderConfig.Name        = SliderConfig.Name        or "Slider"
                SliderConfig.Min         = SliderConfig.Min         or 0
                SliderConfig.Max         = SliderConfig.Max         or 100
                SliderConfig.Increment   = SliderConfig.Increment   or 1
                SliderConfig.Default     = SliderConfig.Default     or 50
                SliderConfig.Callback    = SliderConfig.Callback    or function() end
                SliderConfig.ValueName   = SliderConfig.ValueName   or ""
                SliderConfig.Color       = SliderConfig.Color       or Color3.fromRGB(90, 120, 255)
                SliderConfig.Flag        = SliderConfig.Flag        or nil
                SliderConfig.Save        = SliderConfig.Save        or false

                local Slider = {Value = SliderConfig.Default, Save = SliderConfig.Save}
                local Dragging = false

                -- Glow-Knopf am Ende des Fills
                local SliderKnob = SetChildren(SetProps(MakeElement("Frame"), {
                    Size             = UDim2.new(0, 12, 0, 12),
                    AnchorPoint      = Vector2.new(0.5, 0.5),
                    Position         = UDim2.new(0, 0, 0.5, 0),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BorderSizePixel  = 0,
                    ZIndex           = 4,
                    Name             = "Knob"
                }), {
                    Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
                    Create("UIStroke", {Color = SliderConfig.Color, Thickness = 1.5, Transparency = 0.3})
                })

                -- Fill (farbig, Gradient für Glaseffekt)
                local SliderFill = SetChildren(SetProps(MakeElement("RoundFrame", SliderConfig.Color, 0, 5), {
                    Size             = UDim2.new(0, 0, 1, 0),
                    BackgroundTransparency = 0,
                    ZIndex           = 2,
                    ClipsDescendants = false
                }), {
                    SliderKnob,
                    Create("UIGradient", {
                        Color    = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 90, 200)),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 100, 255))
                        }),
                        Rotation = 0
                    })
                })

                -- Track (dunkler Glastrack)
                local SliderBar = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(12, 14, 24), 0, 5), {
                    Size             = UDim2.new(1, -24, 0, 14),
                    Position         = UDim2.new(0, 12, 0, 40),
                    BackgroundTransparency = 0,
                    ClipsDescendants = false
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(55, 65, 130), Thickness = 1, Transparency = 0.45}),
                    SliderFill
                })

                -- Value-Label (rechts oben)
                local SliderValueLabel = AddThemeObject(SetProps(MakeElement("Label", "value", 12), {
                    Size             = UDim2.new(1, -24, 0, 14),
                    Position         = UDim2.new(0, 12, 0, 22),
                    Font             = Enum.Font.Gotham,
                    Name             = "Value",
                    TextTransparency = 0.3,
                    TextXAlignment   = Enum.TextXAlignment.Right
                }), "TextDark")

                local SliderFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(16, 18, 30), 0, 7), {
                    Size             = UDim2.new(1, 0, 0, 64),
                    Parent           = ItemParent,
                    BackgroundTransparency = 0.1
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(55, 65, 130), Thickness = 1, Transparency = 0.5}),
                    AddThemeObject(SetProps(MakeElement("Label", SliderConfig.Name, 14), {
                        Size     = UDim2.new(1, -100, 0, 14),
                        Position = UDim2.new(0, 12, 0, 10),
                        Font     = Enum.Font.GothamSemibold,
                        Name     = "Content"
                    }), "Text"),
                    SliderValueLabel,
                    SliderBar
                }), "Second")

                SliderBar.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        Dragging = true
                    end
                end)
                SliderBar.InputEnded:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        Dragging = false
                    end
                end)

                UserInputService.InputChanged:Connect(function(Input)
                    if Dragging then
                        local SizeScale = math.clamp((Mouse.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
                        Slider:Set(SliderConfig.Min + ((SliderConfig.Max - SliderConfig.Min) * SizeScale))
                        SaveCfg(game.GameId)
                    end
                end)

                function Slider:Set(Value)
                    self.Value = math.clamp(Round(Value, SliderConfig.Increment), SliderConfig.Min, SliderConfig.Max)
                    local scale = (self.Value - SliderConfig.Min) / (SliderConfig.Max - SliderConfig.Min)
                    TweenService:Create(SliderFill, TweenInfo.new(.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromScale(scale, 1)}):Play()
                    -- Knob mitbewegen
                    SliderKnob.Position = UDim2.new(1, 0, 0.5, 0)
                    SliderValueLabel.Text = tostring(self.Value) .. " " .. SliderConfig.ValueName
                    SliderConfig.Callback(self.Value)
                end

                Slider:Set(Slider.Value)
                if SliderConfig.Flag then Library.Flags[SliderConfig.Flag] = Slider end
                return Slider
            end

            -- ── Dropdown ─────────────────────────────────────────────
            function ElementFunction:AddDropdown(DropdownConfig)
                DropdownConfig          = DropdownConfig          or {}
                DropdownConfig.Name     = DropdownConfig.Name     or "Dropdown"
                DropdownConfig.Options  = DropdownConfig.Options  or {}
                DropdownConfig.Default  = DropdownConfig.Default  or ""
                DropdownConfig.Callback = DropdownConfig.Callback or function() end
                DropdownConfig.Flag     = DropdownConfig.Flag     or nil
                DropdownConfig.Save     = DropdownConfig.Save     or false

                local Dropdown = {Value = DropdownConfig.Default, Options = DropdownConfig.Options, Buttons = {}, Toggled = false, Type = "Dropdown", Save = DropdownConfig.Save}
                local MaxElements = 5

                if not table.find(Dropdown.Options, Dropdown.Value) then
                    Dropdown.Value = "..."
                end

                local DropdownList = MakeElement("List")

                local DropdownContainer = AddThemeObject(SetProps(SetChildren(MakeElement("ScrollFrame", Color3.fromRGB(70, 90, 200), 3), {
                    DropdownList
                }), {
                    Parent           = ItemParent,
                    Position         = UDim2.new(0, 0, 0, 38),
                    Size             = UDim2.new(1, 0, 1, -38),
                    ClipsDescendants = true
                }), "Divider")

                local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})

                local DropdownFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(16, 18, 30), 0, 7), {
                    Size             = UDim2.new(1, 0, 0, 38),
                    Parent           = ItemParent,
                    ClipsDescendants = true,
                    BackgroundTransparency = 0.1
                }), {
                    DropdownContainer,
                    SetProps(SetChildren(MakeElement("TFrame"), {
                        AddThemeObject(SetProps(MakeElement("Label", DropdownConfig.Name, 14), {
                            Size     = UDim2.new(1, -12, 1, 0),
                            Position = UDim2.new(0, 12, 0, 0),
                            Font     = Enum.Font.GothamSemibold,
                            Name     = "Content"
                        }), "Text"),
                        AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072706796"), {
                            Size         = UDim2.new(0, 18, 0, 18),
                            AnchorPoint  = Vector2.new(0, 0.5),
                            Position     = UDim2.new(1, -28, 0.5, 0),
                            ImageColor3  = Color3.fromRGB(90, 110, 200),
                            Name         = "Ico"
                        }), "TextDark"),
                        AddThemeObject(SetProps(MakeElement("Label", "Selected", 12), {
                            Size             = UDim2.new(1, -40, 1, 0),
                            Font             = Enum.Font.Gotham,
                            Name             = "Selected",
                            TextXAlignment   = Enum.TextXAlignment.Right
                        }), "TextDark"),
                        AddThemeObject(SetProps(MakeElement("Frame"), {
                            Size     = UDim2.new(1, 0, 0, 1),
                            Position = UDim2.new(0, 0, 1, -1),
                            Name     = "Line",
                            Visible  = false
                        }), "Stroke"),
                        Click
                    }), {
                        Size             = UDim2.new(1, 0, 0, 38),
                        ClipsDescendants = true,
                        Name             = "F"
                    }),
                    Create("UIStroke", {Color = Color3.fromRGB(55, 65, 130), Thickness = 1, Transparency = 0.5}),
                    MakeElement("Corner")
                }), "Second")

                AddConnection(DropdownList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
                    DropdownContainer.CanvasSize = UDim2.new(0, 0, 0, DropdownList.AbsoluteContentSize.Y)
                end)

                local function AddOptions(Options)
                    for _, Option in pairs(Options) do
                        local OptionBtn = AddThemeObject(SetProps(SetChildren(MakeElement("Button", Color3.fromRGB(20, 22, 36)), {
                            MakeElement("Corner", 0, 5),
                            AddThemeObject(SetProps(MakeElement("Label", Option, 12, 0.4), {
                                Position = UDim2.new(0, 10, 0, 0),
                                Size     = UDim2.new(1, -10, 1, 0),
                                Font     = Enum.Font.GothamSemibold,
                                Name     = "Title"
                            }), "Text")
                        }), {
                            Parent           = DropdownContainer,
                            Size             = UDim2.new(1, 0, 0, 28),
                            BackgroundTransparency = 1,
                            ClipsDescendants = true
                        }), "Divider")

                        AddConnection(OptionBtn.MouseButton1Click, function()
                            Dropdown:Set(Option)
                            SaveCfg(game.GameId)
                        end)
                        Dropdown.Buttons[Option] = OptionBtn
                    end
                end

                function Dropdown:Refresh(Options, Delete)
                    if Delete then
                        for _, v in pairs(Dropdown.Buttons) do v:Destroy() end
                        table.clear(Dropdown.Options)
                        table.clear(Dropdown.Buttons)
                    end
                    Dropdown.Options = Options
                    AddOptions(Dropdown.Options)
                end

                function Dropdown:Set(Value)
                    if not table.find(Dropdown.Options, Value) then
                        Dropdown.Value = "..."
                        DropdownFrame.F.Selected.Text = Dropdown.Value
                        for _, v in pairs(Dropdown.Buttons) do
                            TweenService:Create(v, TweenInfo.new(.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
                            TweenService:Create(v.Title, TweenInfo.new(.15, Enum.EasingStyle.Quad), {TextTransparency = 0.4}):Play()
                        end
                        return
                    end
                    Dropdown.Value = Value
                    DropdownFrame.F.Selected.Text = Dropdown.Value
                    for _, v in pairs(Dropdown.Buttons) do
                        TweenService:Create(v, TweenInfo.new(.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
                        TweenService:Create(v.Title, TweenInfo.new(.15, Enum.EasingStyle.Quad), {TextTransparency = 0.4}):Play()
                    end
                    TweenService:Create(Dropdown.Buttons[Value], TweenInfo.new(.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.7}):Play()
                    TweenService:Create(Dropdown.Buttons[Value].Title, TweenInfo.new(.15, Enum.EasingStyle.Quad), {TextTransparency = 0}):Play()
                    return DropdownConfig.Callback(Dropdown.Value)
                end

                AddConnection(Click.MouseButton1Click, function()
                    Dropdown.Toggled = not Dropdown.Toggled
                    DropdownFrame.F.Line.Visible = Dropdown.Toggled
                    TweenService:Create(DropdownFrame.F.Ico, TweenInfo.new(.15, Enum.EasingStyle.Quad), {Rotation = Dropdown.Toggled and 180 or 0}):Play()
                    if #Dropdown.Options > MaxElements then
                        TweenService:Create(DropdownFrame, TweenInfo.new(.15, Enum.EasingStyle.Quad), {Size = Dropdown.Toggled and UDim2.new(1, 0, 0, 38 + (MaxElements * 28)) or UDim2.new(1, 0, 0, 38)}):Play()
                    else
                        TweenService:Create(DropdownFrame, TweenInfo.new(.15, Enum.EasingStyle.Quad), {Size = Dropdown.Toggled and UDim2.new(1, 0, 0, DropdownList.AbsoluteContentSize.Y + 38) or UDim2.new(1, 0, 0, 38)}):Play()
                    end
                end)

                Dropdown:Refresh(Dropdown.Options, false)
                Dropdown:Set(Dropdown.Value)
                if DropdownConfig.Flag then Library.Flags[DropdownConfig.Flag] = Dropdown end
                return Dropdown
            end

            -- ── Bind ─────────────────────────────────────────────────
            function ElementFunction:AddBind(BindConfig)
                BindConfig.Name     = BindConfig.Name     or "Bind"
                BindConfig.Default  = BindConfig.Default  or Enum.KeyCode.Unknown
                BindConfig.Hold     = BindConfig.Hold     or false
                BindConfig.Callback = BindConfig.Callback or function() end
                BindConfig.Flag     = BindConfig.Flag     or nil
                BindConfig.Save     = BindConfig.Save     or false

                local Bind = {Value, Binding = false, Type = "Bind", Save = BindConfig.Save}
                local Holding = false
                local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})

                local BindBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(14, 16, 26), 0, 5), {
                    Size        = UDim2.new(0, 28, 0, 24),
                    Position    = UDim2.new(1, -12, 0.5, 0),
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundTransparency = 0.1
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(70, 90, 180), Thickness = 1, Transparency = 0.4}),
                    AddThemeObject(SetProps(MakeElement("Label", BindConfig.Name, 12), {
                        Size             = UDim2.new(1, 0, 1, 0),
                        Font             = Enum.Font.GothamBold,
                        TextXAlignment   = Enum.TextXAlignment.Center,
                        Name             = "Value"
                    }), "Text")
                }), "Main")

                local BindFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(16, 18, 30), 0, 7), {
                    Size             = UDim2.new(1, 0, 0, 38),
                    Parent           = ItemParent,
                    BackgroundTransparency = 0.1
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(55, 65, 130), Thickness = 1, Transparency = 0.5}),
                    AddThemeObject(SetProps(MakeElement("Label", BindConfig.Name, 14), {
                        Size     = UDim2.new(1, -12, 1, 0),
                        Position = UDim2.new(0, 12, 0, 0),
                        Font     = Enum.Font.GothamSemibold,
                        Name     = "Content"
                    }), "Text"),
                    BindBox,
                    Click
                }), "Second")

                AddConnection(BindBox.Value:GetPropertyChangedSignal("Text"), function()
                    TweenService:Create(BindBox, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Size = UDim2.new(0, BindBox.Value.TextBounds.X + 16, 0, 24)}):Play()
                end)

                AddConnection(Click.InputEnded, function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                        if Bind.Binding then return end
                        Bind.Binding = true
                        BindBox.Value.Text = "..."
                    end
                end)

                AddConnection(UserInputService.InputBegan, function(Input)
                    if UserInputService:GetFocusedTextBox() then return end
                    if (Input.KeyCode.Name == Bind.Value or Input.UserInputType.Name == Bind.Value) and not Bind.Binding then
                        if BindConfig.Hold then
                            Holding = true
                            BindConfig.Callback(Holding)
                        else
                            BindConfig.Callback()
                        end
                    elseif Bind.Binding then
                        local Key
                        pcall(function() if not CheckKey(BlacklistedKeys, Input.KeyCode) then Key = Input.KeyCode end end)
                        pcall(function() if CheckKey(WhitelistedMouse, Input.UserInputType) and not Key then Key = Input.UserInputType end end)
                        Key = Key or Bind.Value
                        Bind:Set(Key)
                        SaveCfg(game.GameId)
                    end
                end)

                AddConnection(UserInputService.InputEnded, function(Input)
                    if Input.KeyCode.Name == Bind.Value or Input.UserInputType.Name == Bind.Value then
                        if BindConfig.Hold and Holding then
                            Holding = false
                            BindConfig.Callback(Holding)
                        end
                    end
                end)

                AddConnection(Click.MouseEnter, function()
                    TweenService:Create(BindFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.04}):Play()
                end)
                AddConnection(Click.MouseLeave, function()
                    TweenService:Create(BindFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.1}):Play()
                end)

                function Bind:Set(Key)
                    Bind.Binding   = false
                    Bind.Value     = Key or Bind.Value
                    Bind.Value     = Bind.Value.Name or Bind.Value
                    BindBox.Value.Text = Bind.Value
                end

                Bind:Set(BindConfig.Default)
                if BindConfig.Flag then Library.Flags[BindConfig.Flag] = Bind end
                return Bind
            end

            -- ── Textbox ──────────────────────────────────────────────
            function ElementFunction:AddTextbox(TextboxConfig)
                TextboxConfig               = TextboxConfig               or {}
                TextboxConfig.Name          = TextboxConfig.Name          or "Textbox"
                TextboxConfig.Default       = TextboxConfig.Default       or ""
                TextboxConfig.TextDisappear = TextboxConfig.TextDisappear or false
                TextboxConfig.Callback      = TextboxConfig.Callback      or function() end

                local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})

                local TextboxActual = AddThemeObject(Create("TextBox", {
                    Size                 = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    TextColor3           = Color3.fromRGB(200, 215, 255),
                    PlaceholderColor3    = Color3.fromRGB(80, 100, 170),
                    PlaceholderText      = "Input",
                    Font                 = Enum.Font.GothamSemibold,
                    TextXAlignment       = Enum.TextXAlignment.Center,
                    TextSize             = 13,
                    ClearTextOnFocus     = false
                }), "Text")

                local TextContainer = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(12, 14, 24), 0, 5), {
                    Size        = UDim2.new(0, 28, 0, 24),
                    Position    = UDim2.new(1, -12, 0.5, 0),
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundTransparency = 0.1
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(70, 90, 180), Thickness = 1, Transparency = 0.4}),
                    TextboxActual
                }), "Main")

                local TextboxFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(16, 18, 30), 0, 7), {
                    Size             = UDim2.new(1, 0, 0, 38),
                    Parent           = ItemParent,
                    BackgroundTransparency = 0.1
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(55, 65, 130), Thickness = 1, Transparency = 0.5}),
                    AddThemeObject(SetProps(MakeElement("Label", TextboxConfig.Name, 14), {
                        Size     = UDim2.new(1, -12, 1, 0),
                        Position = UDim2.new(0, 12, 0, 0),
                        Font     = Enum.Font.GothamSemibold,
                        Name     = "Content"
                    }), "Text"),
                    TextContainer,
                    Click
                }), "Second")

                AddConnection(TextboxActual:GetPropertyChangedSignal("Text"), function()
                    TweenService:Create(TextContainer, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {Size = UDim2.new(0, TextboxActual.TextBounds.X + 18, 0, 24)}):Play()
                end)
                AddConnection(TextboxActual.FocusLost, function()
                    TextboxConfig.Callback(TextboxActual.Text)
                    if TextboxConfig.TextDisappear then TextboxActual.Text = "" end
                end)
                TextboxActual.Text = TextboxConfig.Default

                AddConnection(Click.MouseEnter, function()
                    TweenService:Create(TextboxFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.04}):Play()
                end)
                AddConnection(Click.MouseLeave, function()
                    TweenService:Create(TextboxFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.1}):Play()
                end)
                AddConnection(Click.MouseButton1Up, function()
                    TextboxActual:CaptureFocus()
                end)
            end

            -- ── Colorpicker (unverändert, nur Farbanpassung) ──────────
            function ElementFunction:AddColorpicker(ColorpickerConfig)
                ColorpickerConfig          = ColorpickerConfig          or {}
                ColorpickerConfig.Name     = ColorpickerConfig.Name     or "Colorpicker"
                ColorpickerConfig.Default  = ColorpickerConfig.Default  or Color3.fromRGB(90, 120, 255)
                ColorpickerConfig.Callback = ColorpickerConfig.Callback or function() end
                ColorpickerConfig.Flag     = ColorpickerConfig.Flag     or nil
                ColorpickerConfig.Save     = ColorpickerConfig.Save     or false

                local ColorH, ColorS, ColorV = 1, 1, 1
                local Colorpicker = {Value = ColorpickerConfig.Default, Toggled = false, Type = "Colorpicker", Save = ColorpickerConfig.Save}

                local ColorSelection = Create("ImageLabel", {
                    Size             = UDim2.new(0, 16, 0, 16),
                    Position         = UDim2.new(select(3, Color3.toHSV(Colorpicker.Value))),
                    ScaleType        = Enum.ScaleType.Fit,
                    AnchorPoint      = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    Image            = "http://www.roblox.com/asset/?id=4805639000"
                })

                local HueSelection = Create("ImageLabel", {
                    Size             = UDim2.new(0, 16, 0, 16),
                    Position         = UDim2.new(0.5, 0, 1 - select(1, Color3.toHSV(Colorpicker.Value))),
                    ScaleType        = Enum.ScaleType.Fit,
                    AnchorPoint      = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    Image            = "http://www.roblox.com/asset/?id=4805639000"
                })

                local Color = Create("ImageLabel", {
                    Size    = UDim2.new(1, -25, 1, 0),
                    Visible = false,
                    Image   = "rbxassetid://4155801252"
                }, {
                    Create("UICorner", {CornerRadius = UDim.new(0, 5)}),
                    ColorSelection
                })

                local Hue = Create("Frame", {
                    Size     = UDim2.new(0, 18, 1, 0),
                    Position = UDim2.new(1, -18, 0, 0),
                    Visible  = false
                }, {
                    Create("UIGradient", {Rotation = 270, Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,0,4)),
                        ColorSequenceKeypoint.new(0.20, Color3.fromRGB(234,255,0)),
                        ColorSequenceKeypoint.new(0.40, Color3.fromRGB(21,255,0)),
                        ColorSequenceKeypoint.new(0.60, Color3.fromRGB(0,255,255)),
                        ColorSequenceKeypoint.new(0.80, Color3.fromRGB(0,17,255)),
                        ColorSequenceKeypoint.new(0.90, Color3.fromRGB(255,0,251)),
                        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255,0,4))
                    }}),
                    Create("UICorner", {CornerRadius = UDim.new(0, 5)}),
                    HueSelection
                })

                local ColorpickerContainer = Create("Frame", {
                    Position         = UDim2.new(0, 0, 0, 32),
                    Size             = UDim2.new(1, 0, 1, -32),
                    BackgroundTransparency = 1,
                    ClipsDescendants = true
                }, {
                    Hue, Color,
                    Create("UIPadding", {
                        PaddingLeft   = UDim.new(0, 30),
                        PaddingRight  = UDim.new(0, 30),
                        PaddingBottom = UDim.new(0, 10),
                        PaddingTop    = UDim.new(0, 15)
                    })
                })

                local Click = SetProps(MakeElement("Button"), {Size = UDim2.new(1, 0, 1, 0)})

                local ColorpickerBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", ColorpickerConfig.Default, 0, 5), {
                    Size        = UDim2.new(0, 24, 0, 24),
                    Position    = UDim2.new(1, -12, 0.5, 0),
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundTransparency = 0
                }), {
                    Create("UIStroke", {Color = Color3.fromRGB(70, 90, 180), Thickness = 1.5, Transparency = 0.3})
                }), "Main")

                local ColorpickerFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(16, 18, 30), 0, 7), {
                    Size             = UDim2.new(1, 0, 0, 38),
                    Parent           = ItemParent,
                    BackgroundTransparency = 0.1
                }), {
                    SetProps(SetChildren(MakeElement("TFrame"), {
                        AddThemeObject(SetProps(MakeElement("Label", ColorpickerConfig.Name, 14), {
                            Size     = UDim2.new(1, -12, 1, 0),
                            Position = UDim2.new(0, 12, 0, 0),
                            Font     = Enum.Font.GothamSemibold,
                            Name     = "Content"
                        }), "Text"),
                        ColorpickerBox,
                        Click,
                        AddThemeObject(SetProps(MakeElement("Frame"), {
                            Size     = UDim2.new(1, 0, 0, 1),
                            Position = UDim2.new(0, 0, 1, -1),
                            Name     = "Line",
                            Visible  = false
                        }), "Stroke")
                    }), {Size = UDim2.new(1, 0, 0, 38), ClipsDescendants = true, Name = "F"}),
                    ColorpickerContainer,
                    Create("UIStroke", {Color = Color3.fromRGB(55, 65, 130), Thickness = 1, Transparency = 0.5})
                }), "Second")

                AddConnection(Click.MouseButton1Click, function()
                    Colorpicker.Toggled = not Colorpicker.Toggled
                    TweenService:Create(ColorpickerFrame, TweenInfo.new(.15, Enum.EasingStyle.Quad), {Size = Colorpicker.Toggled and UDim2.new(1, 0, 0, 148) or UDim2.new(1, 0, 0, 38)}):Play()
                    Color.Visible = Colorpicker.Toggled
                    Hue.Visible   = Colorpicker.Toggled
                    ColorpickerFrame.F.Line.Visible = Colorpicker.Toggled
                end)

                local function UpdateColorPicker()
                    ColorpickerBox.BackgroundColor3 = Color3.fromHSV(ColorH, ColorS, ColorV)
                    Color.BackgroundColor3          = Color3.fromHSV(ColorH, 1, 1)
                    Colorpicker:Set(ColorpickerBox.BackgroundColor3)
                    ColorpickerConfig.Callback(ColorpickerBox.BackgroundColor3)
                    SaveCfg(game.GameId)
                end

                ColorH = 1 - (math.clamp(HueSelection.AbsolutePosition.Y - Hue.AbsolutePosition.Y, 0, Hue.AbsoluteSize.Y) / Hue.AbsoluteSize.Y)
                ColorS = (math.clamp(ColorSelection.AbsolutePosition.X - Color.AbsolutePosition.X, 0, Color.AbsoluteSize.X) / Color.AbsoluteSize.X)
                ColorV = 1 - (math.clamp(ColorSelection.AbsolutePosition.Y - Color.AbsolutePosition.Y, 0, Color.AbsoluteSize.Y) / Color.AbsoluteSize.Y)

                AddConnection(Color.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        if ColorInput then ColorInput:Disconnect() end
                        ColorInput = AddConnection(RunService.RenderStepped, function()
                            local ColorX = (math.clamp(Mouse.X - Color.AbsolutePosition.X, 0, Color.AbsoluteSize.X) / Color.AbsoluteSize.X)
                            local ColorY = (math.clamp(Mouse.Y - Color.AbsolutePosition.Y, 0, Color.AbsoluteSize.Y) / Color.AbsoluteSize.Y)
                            ColorSelection.Position = UDim2.new(ColorX, 0, ColorY, 0)
                            ColorS = ColorX
                            ColorV = 1 - ColorY
                            UpdateColorPicker()
                        end)
                    end
                end)
                AddConnection(Color.InputEnded, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        if ColorInput then ColorInput:Disconnect() end
                    end
                end)
                AddConnection(Hue.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        if HueInput then HueInput:Disconnect() end
                        HueInput = AddConnection(RunService.RenderStepped, function()
                            local HueY = (math.clamp(Mouse.Y - Hue.AbsolutePosition.Y, 0, Hue.AbsoluteSize.Y) / Hue.AbsoluteSize.Y)
                            HueSelection.Position = UDim2.new(0.5, 0, HueY, 0)
                            ColorH = 1 - HueY
                            UpdateColorPicker()
                        end)
                    end
                end)
                AddConnection(Hue.InputEnded, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        if HueInput then HueInput:Disconnect() end
                    end
                end)

                function Colorpicker:Set(Value)
                    Colorpicker.Value = Value
                    ColorpickerBox.BackgroundColor3 = Colorpicker.Value
                    ColorpickerConfig.Callback(Colorpicker.Value)
                end

                Colorpicker:Set(Colorpicker.Value)
                if ColorpickerConfig.Flag then Library.Flags[ColorpickerConfig.Flag] = Colorpicker end
                return Colorpicker
            end

            return ElementFunction
        end

        -- ── Section ──────────────────────────────────────────────────
        local ElementFunction = {}
        function ElementFunction:AddSection(SectionConfig)
            SectionConfig.Name = SectionConfig.Name or "Section"

            local SectionLabelRow = SetProps(MakeElement("TFrame"), {
                Size = UDim2.new(1, 0, 0, 18),
                ClipsDescendants = false
            })

            -- Glassmorphism Akzentlinie: Indigo-Gradient
            local SectionAccent = SetChildren(SetProps(MakeElement("Frame"), {
                Size             = UDim2.new(0, 2, 0, 14),
                Position         = UDim2.new(0, 0, 0.5, 0),
                AnchorPoint      = Vector2.new(0, 0.5),
                BackgroundColor3 = Color3.fromRGB(90, 120, 255),
                BorderSizePixel  = 0
            }), {
                Create("UICorner", {CornerRadius = UDim.new(0, 2)}),
                Create("UIGradient", {
                    Color    = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 160, 255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 60, 200))
                    }),
                    Rotation = 90
                })
            })
            SectionAccent.Parent = SectionLabelRow

            AddThemeObject(SetProps(MakeElement("Label", SectionConfig.Name, 13), {
                Size     = UDim2.new(1, -10, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                Font     = Enum.Font.GothamBold,
                Parent   = SectionLabelRow
            }), "TextDark")

            local SectionFrame = SetChildren(SetProps(MakeElement("TFrame"), {
                Size   = UDim2.new(1, 0, 0, 28),
                Parent = Container
            }), {
                SectionLabelRow,
                SetChildren(SetProps(MakeElement("TFrame"), {
                    AnchorPoint = Vector2.new(0, 0),
                    Size        = UDim2.new(1, 0, 1, -24),
                    Position    = UDim2.new(0, 0, 0, 24),
                    Name        = "Holder"
                }), {
                    MakeElement("List", 0, 6)
                })
            })

            AddConnection(SectionFrame.Holder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
                SectionFrame.Size = UDim2.new(1, 0, 0, SectionFrame.Holder.UIListLayout.AbsoluteContentSize.Y + 33)
                SectionFrame.Holder.Size = UDim2.new(1, 0, 0, SectionFrame.Holder.UIListLayout.AbsoluteContentSize.Y)
            end)

            local SectionFunction = {}
            for i, v in next, GetElements(SectionFrame.Holder) do
                SectionFunction[i] = v
            end
            return SectionFunction
        end

        for i, v in next, GetElements(Container) do
            ElementFunction[i] = v
        end

        if TabConfig.PremiumOnly then
            for i, v in next, ElementFunction do
                ElementFunction[i] = function() end
            end
            Container:FindFirstChild("UIListLayout"):Destroy()
            Container:FindFirstChild("UIPadding"):Destroy()
            SetChildren(SetProps(MakeElement("TFrame"), {
                Size   = UDim2.new(1, 0, 1, 0),
                Parent = ItemParent
            }), {
                AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://3610239960"), {
                    Size             = UDim2.new(0, 18, 0, 18),
                    Position         = UDim2.new(0, 15, 0, 15),
                    ImageTransparency = 0.4
                }), "Text"),
                AddThemeObject(SetProps(MakeElement("Label", "Unauthorised Access", 14), {
                    Size             = UDim2.new(1, -38, 0, 14),
                    Position         = UDim2.new(0, 38, 0, 18),
                    TextTransparency = 0.4
                }), "Text")
            })
        end
        return ElementFunction
    end

    return TabFunction
end

-- ============================================================
-- DESTROY
-- ============================================================

function Library:Destroy()
    Container:Destroy()
end

return Library
