local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = ReplicatedStorage.GameEvents
local buylist = {
    "Carrot", "Strawberry", "Blueberry", "Tomato"
}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Leaderstats = LocalPlayer.leaderstats
local Backpack = LocalPlayer.Backpack
local PlayerGui = LocalPlayer.PlayerGui

local ShecklesCount = Leaderstats.Sheckles
local GameInfo = MarketplaceService:GetProductInfo(game.PlaceId)

--// ReGui
local ReGui = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/ReGui.lua'))()
local PrefabsId = "rbxassetid://" .. ReGui.PrefabsId

--// Folders
local GameEvents = ReplicatedStorage.GameEvents
local Farms = workspace.Farm

local Accent = {
    DarkGreen = Color3.fromRGB(45, 95, 25),
    Green = Color3.fromRGB(69, 142, 40),
    Brown = Color3.fromRGB(26, 20, 8),
}

--// ReGui configuration (Ui library)
ReGui:Init({
	Prefabs = InsertService:LoadLocalAsset(PrefabsId)
})
ReGui:DefineTheme("GardenTheme", {
	WindowBg = Accent.Brown,
	TitleBarBg = Accent.DarkGreen,
	TitleBarBgActive = Accent.Green,
    ResizeGrab = Accent.DarkGreen,
    FrameBg = Accent.DarkGreen,
    FrameBgActive = Accent.Green,
	CollapsingHeaderBg = Accent.Green,
    ButtonsBg = Accent.Green,
    CheckMark = Accent.Green,
    SliderGrab = Accent.Green,
})

--// Dicts
local SeedStock = {}
local OwnedSeeds = {}


local auto = false
local function GetFarms()
	return Farms:GetChildren()
end
local function HarvestPlant(Plant: Model)
	local Prompt = Plant:FindFirstChild("ProximityPrompt", true)

	--// Check if it can be harvested
	if not Prompt then return end
	fireproximityprompt(Prompt)
end
local function CanHarvest(Plant): boolean?
    local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
	if not Prompt then return end
    if not Prompt.Enabled then return end

    return true
end

local function CollectHarvestable(Parent, Plants, IgnoreDistance: boolean?)
	local Character = LocalPlayer.Character
	local PlayerPosition = Character:GetPivot().Position

    for _, Plant in next, Parent:GetChildren() do
        --// Fruits
		local Fruits = Plant:FindFirstChild("Fruits")
		if Fruits then
			CollectHarvestable(Fruits, Plants, IgnoreDistance)
		end

		--// Distance check
		local PlantPosition = Plant:GetPivot().Position
		local Distance = (PlayerPosition-PlantPosition).Magnitude
		if not IgnoreDistance and Distance > 15 then continue end

		--// Ignore check
		local Variant = Plant:FindFirstChild("Variant")
        --// Collect
        if CanHarvest(Plant) then
            table.insert(Plants, Plant)
        end
	end
    return Plants
end

local function GetHarvestablePlants(IgnoreDistance: boolean?)
    local Plants = {}
    CollectHarvestable(PlantsPhysical, Plants, IgnoreDistance)
    return Plants
end

local function HarvestPlants(Parent: Model)
	local Plants = GetHarvestablePlants()
    for _, Plant in next, Plants do
        HarvestPlant(Plant)
    end
end

local function GetFarmOwner(Farm: Folder): string
	local Important = Farm.Important
	local Data = Important.Data
	local Owner = Data.Owner

	return Owner.Value
end
local function GetFarm(PlayerName: string): Folder?
	local Farms = GetFarms()
	for _, Farm in next, Farms do
		local Owner = GetFarmOwner(Farm)
		if Owner == PlayerName then
			return Farm
		end
	end
    return
end
local MyFarm = GetFarm(LocalPlayer.Name)
local MyImportant = MyFarm.Important
local PlantLocations = MyImportant.Plant_Locations
local autobuy,autosubmit,Event;
local autosell = true
local function GetSeedInfo(Seed: Tool): number?
	local PlantName = Seed:FindFirstChild("Plant_Name")
	local Count = Seed:FindFirstChild("Numbers")
	if not PlantName then return end

	return PlantName.Value, Count.Value
end

local function CollectSeedsFromParent(Parent, Seeds: table)
	for _, Tool in next, Parent:GetChildren() do
		local Name, Count = GetSeedInfo(Tool)
		if not Name then continue end

		Seeds[Name] = {
            Count = Count,
            Tool = Tool
        }
	end
end
local function GetOwnedSeeds(): table
	local Character = LocalPlayer.Character
	
	CollectSeedsFromParent(Backpack, OwnedSeeds)
	CollectSeedsFromParent(Character, OwnedSeeds)

	return OwnedSeeds
end

local function GetArea(Base: BasePart)
	local Center = Base:GetPivot()
	local Size = Base.Size

	--// Bottom left
	local X1 = math.ceil(Center.X - (Size.X/2))
	local Z1 = math.ceil(Center.Z - (Size.Z/2))

	--// Top right
	local X2 = math.floor(Center.X + (Size.X/2))
	local Z2 = math.floor(Center.Z + (Size.Z/2))

	return X1, Z1, X2, Z2
end
local function GetRandomFarmPoint(): Vector3
    local FarmLands = PlantLocations:GetChildren()
    local FarmLand = FarmLands[math.random(1, #FarmLands)]

    local X1, Z1, X2, Z2 = GetArea(FarmLand)
    local X = math.random(X1, X2)
    local Z = math.random(Z1, Z2)

    return Vector3.new(X, 4, Z)
end
local function Plant(Position: Vector3, Seed: string)
	GameEvents.Plant_RE:FireServer(Position, Seed)
	wait(.3)
end

local function GetSeedStock(IgnoreNoStock: boolean?): table
	local SeedShop = PlayerGui.Seed_Shop
	local Items = SeedShop:FindFirstChild("Blueberry", true).Parent

	local NewList = {}

	for _, Item in next, Items:GetChildren() do
		local MainFrame = Item:FindFirstChild("Main_Frame")
		if not MainFrame then continue end

		local StockText = MainFrame.Stock_Text.Text
		local StockCount = tonumber(StockText:match("%d+"))

		--// Seperate list
		if IgnoreNoStock then
			if StockCount <= 0 then continue end
			NewList[Item.Name] = StockCount
			continue
		end

		SeedStock[Item.Name] = StockCount
	end

	return IgnoreNoStock and NewList or SeedStock
end

local function BuySeed(Seed: string)
	GameEvents.BuySeedStock:FireServer(Seed)
end

local function BuyAllSelectedSeeds()
    for index, value in ipairs(buylist) do
        local Stock = SeedStock[value]

        if not Stock or Stock <= 0 then return end
        for i = 1, Stock do
            BuySeed(value)
        end
    end
end
local IsSelling = false
local function SellInventory()
	local Character = LocalPlayer.Character
	local Previous = Character:GetPivot()
	local PreviousSheckles = ShecklesCount.Value

	--// Prevent conflict
	if IsSelling then return end
	IsSelling = true

	Character:PivotTo(CFrame.new(62, 4, -26))
	while wait() do
		if ShecklesCount.Value ~= PreviousSheckles then break end
		GameEvents.Sell_Inventory:FireServer()
	end
	Character:PivotTo(Previous)

	wait(0.2)
	IsSelling = false
end
local function CollectCropsFromParent(Parent, Crops: table)
	for _, Tool in next, Parent:GetChildren() do
		local Name = Tool:FindFirstChild("Item_String")
		if not Name then continue end

		table.insert(Crops, Tool)
	end
end

local function GetInvCrops(): table
	local Character = LocalPlayer.Character
	
	local Crops = {}
	CollectCropsFromParent(Backpack, Crops)
	CollectCropsFromParent(Character, Crops)

	return Crops
end
local function AutoSellCheck()
    local CropCount = #GetInvCrops()

    if not AutoSell.Value then return end
    if CropCount < 50 then return end

    SellInventory()
end
local function MakeLoop(Toggle, Func)
	coroutine.wrap(function()
		while wait(.01) do
			if not Toggle.Value then continue end
			Func()
		end
	end)()
end
local function Submitsummer()
    game:GetService("ReplicatedStorage").GameEvents.SummerHarvestRemoteEvent:FireServer("SubmitAllPlants")
end
local function gplant()
for index, value in ipairs(buylist) do
            Plant(GetRandomFarmPoint(), value)
        end
    end
local function checktime()
    local currentTimeTable = os.date("*t")
    local currentMinute = currentTimeTable.min 
    if (currentMinute > 56 ) then
        wait(60*3)
    end
    if (currentMinute >= 0 and currentMinute <= 10) then
        autosell = false
    end
    autosell = true
    return false
end
local function checksummer()
    local js = checktime()
    task.spawn(function()
            while js do
                local pontos = 0
                local success, result = pcall(function()
                    return workspace.SummerHarvestEvent.RewardSign:GetChildren()[2].SurfaceGui.PointTextLabel.ContentText
                end)
                if success and result then
                    local clean = string.gsub(result, "[^%d]", "")
                    pontos = tonumber(clean) or 0
                end
                    Submitsummer()

                task.wait(2.5)
            end
        end)
end
-- FIXED MAIN FUNCTION
local function Main()
    -- Create state objects for GUI binding
    local states = {
        auto = { Value = false },
        autosell = { Value = true }
    }

    local function automationLoop()
        while states.auto.Value do
            BuyAllSelectedSeeds()
            gplant()
            HarvestPlants(PlantsPhysical)
            if states.autosell.Value then
                AutoSellCheck()
            end
            checksummer()
            wait(1)
        end
    end

    -- Background update loop
    coroutine.wrap(function()
        while wait(2) do
            GetSeedStock()
            GetOwnedSeeds()
        end
    end)()

    -- Start automation when enabled
    states.auto.Changed:Connect(function()
        if states.auto.Value then
            coroutine.wrap(automationLoop)()
        end
    end)

    return states
end

local states = Main()

local InsertService = game:GetService("InsertService")
local ReGui = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/ReGui.lua'))()
local PrefabsId = "rbxassetid://" .. ReGui.PrefabsId

ReGui:Init({
    Prefabs = InsertService:LoadLocalAsset(PrefabsId)
})

local Accent = {
    DarkGreen = Color3.fromRGB(45, 95, 25),
    Green = Color3.fromRGB(69, 142, 40),
    Brown = Color3.fromRGB(26, 20, 8),
}

ReGui:DefineTheme("GardenTheme", {
    WindowBg = Accent.Brown,
    TitleBarBg = Accent.DarkGreen,
    TitleBarBgActive = Accent.Green,
    ResizeGrab = Accent.DarkGreen,
    FrameBg = Accent.DarkGreen,
    FrameBgActive = Accent.Green,
    CollapsingHeaderBg = Accent.Green,
    ButtonsBg = Accent.Green,
    CheckMark = Accent.Green,
    SliderGrab = Accent.Green,
})

local function CreateWindow()
	local Window = ReGui:Window({
		Title = "{GameInfo.Name} | Depso",
        Theme = "GardenTheme",
		Size = UDim2.fromOffset(300, 200)
	})
	return Window
end

local Window = CreateWindow()
local AutoMation = Window:TreeNode({Title = "Auto 🥕"})

-- AutoMation:Checkbox({
--     Value = false,
--     Label = "Enabled",
--     OnChanged = function(newValue)
--         states.auto.Value = newValue
--     end
-- })

AutoMation:Checkbox({
    Value = false,
    Label = "Auto Sell",
    OnChanged = function(newValue)
        states.autosell.Value = newValue
    end
})
-- loadstring(game:HttpGetAsync('https://raw.githubusercontent.com/JordiTBA/script/refs/heads/main/a.lua'))()
