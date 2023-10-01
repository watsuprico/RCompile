local args = {...};
local RCompile = args[1];

if (RCompile == nil or type(RCompile) ~= "table") then
	error("Missing RCompile object!");
end

return {
	["Name"] = "CompilerStatements",
	["Author"] = "Watsuprico",
	["Version"] = "v1",

	["CompileString"] = function(string)
		--[[
			format: `--#key` (like `--#if`)

			beginning statement: `--#`
			key(s): `header`, `if`, `else`, `end`
			


			TO DO :
				variables: `$debug` (if compiled as debug mode), `$buildNumber` (build number)
		]]

		local startIndex, endIndex = 0

		local cursor = 0
		while true do
			startIndex, endIndex = string:find("%-%-#", cursor) -- Find where the next `--#` is
			if not startIndex then break end

			local statementEndIndex = string:find("\n",endIndex) -- Find where that line ends
			local statement = string:sub(endIndex+1, statementEndIndex-1) -- Grabs the string between `--#` and then end of the line (so the statement, like `header` in `--#header`)
			local words = {} -- These are the words within the statement (split via white space)
			local wordNumber = 0
			for word in statement:gmatch("[^%s]+") do
				words[wordNumber] = word
				wordNumber = wordNumber + 1
			end

			-- Okay, so we have the statement it is split up via white space.
			-- At the moment we support {header}, {if}, {else}, and {end}

			if words[0] == "header" then
				-- We're in a header. Find the end, remove block
				local _,endStatement = string:find("%-%-#end\n",statementEndIndex)
				string = string:sub(1,startIndex-1) .. string:sub(endStatement+1,-1) -- Everything before the statement, everything after.
			elseif string.lower(words[0]) == "if" then
				if (string.lower(words[1]) == "debug") then
					STATEMENT = (debug==true) -- update later idk

					local elseFound = false

					-- Else or end?
					local endStatementS,endStatementE = string:find("%-%-#end",statementEndIndex)
					local elseStatementS,elseStatementE = string:find("%-%-#else",statementEndIndex)
					if not endStatementE then
						RCompile.Log.Warn("CompilerStatements: Expected --#end to close --#if at index " + startIndex)
						-- can't really do much, kinda ignore it, plus the reset is probably messed up
						break
					end
					if elseStatementE then
						if (elseStatementE<endStatementE) then
							-- Else statement exists, remove it.
							elseFound = true
						end
					end

					if STATEMENT==true then
						-- Keep code, remove else block
						if (elseFound) then
							string = string:sub(1,startIndex-1) .. string:sub(statementEndIndex+2,elseStatementS-1) .. string:sub(endStatementE+2, -1) -- include code before else
						else
							string = string:sub(1,startIndex-1) .. string:sub(statementEndIndex+2,endStatementS-1) .. string:sub(endStatementE+2, -1) -- include code before end statement
						end					
					else
						if (elseFound) then
							string = string:sub(1,startIndex-1) .. string:sub(elseStatementE+2,endStatementS-1) .. string:sub(endStatementE+2, -1) -- include code after else
						else
							string = string:sub(1,startIndex-1) .. string:sub(endStatementE+2, -1) -- include no code
						end
					end
				else
					-- just remove it
					local _,endStatement = string:find("\-\-\#end\n",statementEndIndex)
					string = string:sub(1,startIndex-1) .. string:sub(endStatement+2,-1) -- Everything before the statement, everything after.
				end

			else
				cursor = endIndex+1
			end
		end

		return string
	end
};