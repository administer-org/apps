--/ Administer

--// PyxFluff 2022-2024

local function PlaySFX()
	script.Sound:Play()
end

local last = "ServerDir"

for i, v in script.Parent.Parent:GetChildren() do
	if table.find({ "CanvasGroup", "Frame" }, v.ClassName) == nil then continue end

	v:GetPropertyChangedSignal("Visible"):Connect(function()
		if v.Visible == true then last = v.Name end
	end)
end

for i, v in ipairs(script.Parent.buttons:GetChildren()) do
	local frame = string.sub(v.Name, 2, 100)
	if not v:IsA("ImageLabel") then continue end

	v.TextButton.MouseButton1Click:Connect(function()
		if script.Parent.Parent:FindFirstChild(frame) then
			PlaySFX()

			script.Parent.Parent[tostring(last)].Visible = false
			last = frame
			task.wait(0.2)
			script.Parent.Parent[frame].Visible = true
		else
			warn(`{frame} not found! this is an issue on administer's end, report it.`)
		end
	end)
end
