local BaseAnnouncementsGui = script.Parent.Parent
local BaseGui = BaseAnnouncementsGui.Parent :: CanvasGroup
warn(BaseGui)
local Lighting = game:GetService("Lighting")
local Effects = {}
local Remote = script.Parent:WaitForChild("FixBlur")
for Index, Value : DepthOfFieldEffect in pairs(Lighting:GetDescendants()) do
	if Value and Value:IsA("DepthOfFieldEffect") then
		table.insert(Effects,Value)
	end
end
local TweenService = game:GetService("TweenService")
local Info = TweenInfo.new(
	0.66,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out,
	0,
	false,
	0
)
local EnabledValue = 51.6
local Camera = game:GetService("Workspace").CurrentCamera
local GlassEfectFolder = Camera:WaitForChild("neon") :: Folder

local function ChangeReflectEffectTransparency(Amount)
	for Index, Value : BasePart in pairs(GlassEfectFolder:GetDescendants()) do
		if Value and Value:IsA("BasePart") then
			Value.LocalTransparencyModifier = Amount
		end
	end
end

local function ChangeBlurAmount(Amount : number)
	for Index, Value : DepthOfFieldEffect in pairs(Effects) do
		if Value and Value:IsA("DepthOfFieldEffect") then
			local Goal = {
				FocusDistance = Amount
			}
			
			local Tween = TweenService:Create(Value,Info,Goal)
			Tween:Play()
			
			if Amount == 0 then
				ChangeReflectEffectTransparency(1)
			else
				ChangeReflectEffectTransparency(0)
			end
		end
	end
end

Remote.OnClientEvent:Connect(function()
	ChangeBlurAmount(0)
end)

BaseGui:GetPropertyChangedSignal("Visible"):Connect(function()
	if BaseGui.Visible == true then
		ChangeBlurAmount(EnabledValue)
	elseif BaseGui.Visible == false then
		ChangeBlurAmount(0)
	end
end)

task.wait(1)

ChangeReflectEffectTransparency(0)