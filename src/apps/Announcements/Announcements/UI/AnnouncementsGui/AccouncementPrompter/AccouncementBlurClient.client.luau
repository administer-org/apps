local ChangeBlur = script.Parent:WaitForChild("ChangeBlur") :: RemoteEvent
local Lighting = game:GetService("Lighting")
local BlurEffect = Instance.new("BlurEffect")
BlurEffect.Size = 0
BlurEffect.Parent = Lighting
BlurEffect.Name = "AnnouncementBlur"
local TweenService = game:GetService("TweenService")
local GeneralTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)
local BlurAmount = 35

ChangeBlur.OnClientEvent:Connect(function(Value)
	local FinalBlurValue = Value * BlurAmount

	local Goal = {
		Size = FinalBlurValue,
	}

	local Tween = TweenService:Create(BlurEffect, GeneralTweenInfo, Goal)
	Tween:Play()
end)
