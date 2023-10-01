--[[

	R(it) Compile(r)
		v1

	(c) Watsuprico 2023, see https://github.com/Watsuprico/RCompile

]]
local args = {...};
local launchTime = os.epoch("utc");



local debug = false;


local RCompile = {
	["RootDirectory"] = "/Compiler"
};


-- Verify support platform
RCompile.Platform = "cc"; -- ComputerCraft
if (System ~= nil and type(System) == "table" and type(System.GetPlatform) == "function") then
	RCompile.Platform = "ro"; -- RitoOS
else
	if (computer ~= nil and type(computer) == "table") then
		RCompile.Platform = "oc"; -- OpenComputers
		error("Unsupported platform!");
	end
end


--[[

	Asserts an argument (have) is of one of the types provided by (...).
	If the argument is not one of the correct types, an error is thrown: "bad argument n (* or * expected, got *)"

	n specifies the argument number

]]
function RCompile.CheckArgument(n, have, ...)
	have = type(have);
	local function check(want, ...)
		if not want then
			return false;
		else
			return have == want or check(...);
		end
	end
	if not check(...) then
		local msg = string.format("bad argument #%d (%s expected, got %s)", tostring(n), table.concat({...}, " or "), have);
		error(msg, 3);
	end
end

-- Gets the path given the relative compiler path (combines the relative with the root).
function RCompile.GetPathTo(relativePath)
	return fs.combine(RCompile.RootDirectory, relativePath);
end


--[[

	Logging

]]
RCompile.LogHandle = fs.open(RCompile.GetPathTo("/Logs/latest.log"),"w");
RCompile.LogHandle.writeLine("--- RCompile, v1. (c) Watsuprico ---\n");
RCompile.LogHandle.flush();

local function internalLog(state, message)
	local now = os.epoch("utc");
	local logTime = (now - launchTime) / 1000;
	pcall(function()
		local logLine = ("["..logTime.."]["..state.."] "..message.."\n");
		RCompile.LogHandle.write(logLine);
		RCompile.LogHandle.flush();
	end)
end

RCompile.Log = {
	["Info"] = function(msg) internalLog("Info", msg); end,
	["Warn"] = function(msg) internalLog("Warn",msg); end,
	["Alert"] = function(msg) internalLog("Alert", msg); end,
	["Error"] = function(msg) internalLog("Error",msg); end
};


-- Gets and API
function RCompile.GetAPI(name)
	local apiPath = RCompile.GetPathTo("lib/" .. name .. ".api");
	RCompile.Log.Info("Loading API: " .. name .. " (at: \"" .. apiPath .. "\")");
	local internalsChunk, err = loadfile(apiPath);
	if not internalsChunk then
		local errorMessage = "Failed to load " .. name .. " (" .. apiPath ..")";
		if err then
			errorMessage = errorMessage .. ". Error: " .. err;
		end

		RCompile.Log.Alert(errorMessage);
		printError(errorMessage);
	end
	return internalsChunk(RCompile);
end
RCompile.GetAPI("RCompile");


local ok,err = pcall(function() 
	RCompile.Log.Info("! Beginning");

	RCompile.Settings.BuildVersion.Build = RCompile.Settings.BuildVersion.Build + 1;
	local versionString = RCompile.Settings.BuildVersion.Major .. ".";
	versionString = versionString .. RCompile.Settings.BuildVersion.Minor .. ".";
	versionString = versionString .. RCompile.Settings.BuildVersion.Build;
	RCompile.SaveSettings();


	local buildUUID = RCompile.UUID.Create();
	RCompile.Log.Info("Unique build identifier: " .. buildUUID);
	if (not RCompile.Settings.SignOnCompile) then
		RCompile.Log.Alert("Will NOT be signing compiled files!");
		RCompile.Log.Warn("Signing files allows users and yourself to verify the code authenticity. Learn more at https://github.com/Watsuprico/RCompile/Docs/CodeSigning.md");
	end

	local releaseBuild = debug ~= true;
	if (not releaseBuild) then
		RCompile.Settings.Minify = false;
	end

	-- log to screen and the log file
	local function log(msg, printFunction)
		RCompile.Log.Info(msg);
		printFunction(msg);
	end

	log(">. RIT Compiler", print);
	log("", print);
	log("    build id: " .. buildUUID, print);
	log("    target: " .. (releaseBuild == true and "release" or "debug"), print);
	log("    version: " .. versionString, print);
	log("    " .. (RCompile.Settings.Minify == true and "will minify" or "will not minify"), print);
	log("    " .. (RCompile.Settings.SignOnCompile == true and "will sign" or "will NOT sign files"), print);

	local totalDuration = 0;
	local preCompileSize = 0;
	local postCompileSize = 0;

	local filesToCompile = RCompile.GetFilesToCompile();
	log("    files to compile: " .. #filesToCompile, print);
	log("", print);
	log("", print);
	log("", print);

	local x,y = term.getCursorPos();
	y = y-2;
	for _,name in ipairs(filesToCompile) do
		term.setCursorPos(x, y);
		term.clearLine();
		term.write("Compiling ... (" .. _ .. "/" .. #filesToCompile .. ").");

		local start = os.epoch("utc");

		term.setCursorPos(x, y+2);
		term.clearLine();
		RCompile.LogHandle.write("\n");
		log("    Compiling " .. name .. " (file " .. _ .. "/" .. #filesToCompile .. ")", term.write);
		local preSize = fs.getSize(name);
		preCompileSize = preCompileSize + preSize;
		RCompile.CompileFile(name);

		postSize = fs.getSize(fs.combine(RCompile.Settings.OutputPath, name));
		postCompileSize = postCompileSize + postSize;
		RCompile.Log.Info("Saved ")


		local now = os.epoch("utc");
		local duration = (now - start) / 1000;
		local savedSpace = math.floor( (postSize/preSize) * 10000 ) / 100;
		log(" ... completed (in " .. (duration) .. " seconds, saved " .. savedSpace .. "% disk space)", term.write);
		totalDuration = totalDuration + duration;
	end

	term.setCursorPos(x, y+2);
	term.clearLine();
	term.setCursorPos(x, y);
	term.clearLine();

	local averageTime = math.floor( (totalDuration/#filesToCompile) * 100 ) / 100;
	local outputLogPath = fs.combine(RCompile.Settings.OutputPath, "CompileLog.rlog");
	local outputPublicKeyPath = fs.combine(RCompile.Settings.OutputPath, "CompilerPublic.key");
	local savedSpacePercent = math.floor( (postCompileSize/preCompileSize) * 10000 ) / 100;

	log("Compiled in " .. totalDuration .. " seconds", print);
	log("    (" .. #filesToCompile .. " files, average of " .. averageTime .. "s per file. Total size: " .. (math.floor(postCompileSize/10)/100) .. "kb, saved " .. savedSpacePercent .. "%)", print);
	log("", print);
	log("Compiled details saved to: " .. outputLogPath .. ". Compiler public key: " .. outputPublicKeyPath, print);

	if (fs.exists(outputLogPath)) then
		fs.delete(outputLogPath);
	end
	fs.copy(RCompile.GetPathTo("Logs/latest.log"), outputLogPath);

	local _, publicKey = RCompile.GetKey(RCompile.Settings.KeyType);
	RCompile.WriteFileContents(outputPublicKeyPath, textutils.serialize(publicKey));
end);


local function closeLog()
	RCompile.Log.Info("Exiting.. Goodbye!");
	RCompile.LogHandle.close();
end

if not ok then
	RCompile.Log.Error("RCompile has crashed! Error:");
	if err then
		RCompile.Log.Error(err);
		printError(err);
	else
		printError("Unknown error encountered.");
	end
end

closeLog();