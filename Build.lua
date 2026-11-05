local Target = "Build/nexus"
local Build = "Build"

local CC = os.getenv("CC") or "gcc"
local CXX = os.getenv("CXX") or "g++"

local CFlags = "-Wall -Wextra"
local CXXFlags = "-Wall -Wextra -O2"
local ASFlags = ""
local LdFlags = "-lunicorn"
local Libs = ""

local Sources = {
	"Source",
}

local Includes = {
	"Source",
	"Include",
}

local Data = "Data"

local function Fail(Message)
	io.stderr:write(Message .. "\n")
	os.exit(1)
end

local function Quote(Value)
	return "'" .. tostring(Value):gsub("'", "'\\''") .. "'"
end

local function Run(Command)
	local Success, Reason, Code = os.execute(Command)

	if Success ~= true and Success ~= 0 then
		Fail("Command failed: " .. Command .. " (" .. tostring(Code or Reason or Success) .. ")")
	end
end

local function Capture(Command)
	local Pipe = io.popen(Command, "r")

	if not Pipe then
		Fail("Could not execute: " .. Command)
	end

	local Result = Pipe:read("*a")
	local Success, Reason, Code = Pipe:close()

	if Success ~= true and Success ~= 0 then
		Fail("Command failed: " .. Command .. " (" .. tostring(Code or Reason or Success) .. ")")
	end

	return Result
end

local function Mkdir(Path)
	Run("mkdir -p " .. Quote(Path))
end

local function Exists(Path)
	local File = io.open(Path, "rb")

	if File then
		File:close()
		return true
	end

	return false
end

local function Mtime(Path)
	return tonumber(Capture("stat -c %Y " .. Quote(Path) .. " 2>/dev/null"):match("%d+"))
end

local function IsNewer(Input, Output)
	if not Exists(Output) then
		return true
	end

	local InputTime = Mtime(Input)
	local OutputTime = Mtime(Output)

	return not InputTime or not OutputTime or InputTime > OutputTime
end

local function Basename(Path)
	return Path:match("([^/]+)$")
end

local function Stem(Path)
	return Basename(Path):gsub("%.[^.]+$", "")
end

local function ListFiles(Directory, Pattern)
	local Files = {}

	local Command = "find "
		.. Quote(Directory)
		.. " -maxdepth 1 -type f -name "
		.. Quote(Pattern)
		.. " -print 2>/dev/null | sort"

	for Path in Capture(Command):gmatch("[^\r\n]+") do
		Files[#Files + 1] = Path
	end

	return Files
end

local function Join(Values, Separator)
	return table.concat(Values, Separator or " ")
end

local IncludeFlags = {}

for _, Directory in ipairs(Includes) do
	IncludeFlags[#IncludeFlags + 1] = "-I" .. Quote(Directory)
end

CFlags = CFlags .. " " .. Join(IncludeFlags)
CXXFlags = CXXFlags .. " " .. Join(IncludeFlags)

local function GetSourceFiles()
	local CFiles = {}
	local CppFiles = {}
	local SFiles = {}
	local BinFiles = {}

	for _, Directory in ipairs(Sources) do
		for _, Path in ipairs(ListFiles(Directory, "*.c")) do
			CFiles[#CFiles + 1] = Path
		end

		for _, Path in ipairs(ListFiles(Directory, "*.cpp")) do
			CppFiles[#CppFiles + 1] = Path
		end

		for _, Path in ipairs(ListFiles(Directory, "*.s")) do
			SFiles[#SFiles + 1] = Path
		end

		for _, Path in ipairs(ListFiles(Directory, "*.S")) do
			SFiles[#SFiles + 1] = Path
		end
	end

	for _, Path in ipairs(ListFiles(Data, "*.*")) do
		BinFiles[#BinFiles + 1] = Path
	end

	table.sort(CFiles)
	table.sort(CppFiles)
	table.sort(SFiles)
	table.sort(BinFiles)

	return CFiles, CppFiles, SFiles, BinFiles
end

local function ReadDependencies(Path)
	local Dependencies = {}

	if not Exists(Path) then
		return Dependencies
	end

	local File = io.open(Path, "r")
	local Content = File:read("*a")
	File:close()

	Content = Content:gsub("\\\r?\n", " ")

	local DependencyText = Content:match("^[^:]+:%s*(.*)")

	if DependencyText then
		for Dependency in DependencyText:gmatch("%S+") do
			Dependencies[#Dependencies + 1] = Dependency:gsub("\\ ", " ")
		end
	end

	return Dependencies
end

local function NeedsCompile(Source, Object, DependencyFile)
	if IsNewer(Source, Object) then
		return true
	end

	for _, Dependency in ipairs(ReadDependencies(DependencyFile)) do
		if IsNewer(Dependency, Object) then
			return true
		end
	end

	return false
end

local function CompileFile(Source, Kind)
	local Object = Build .. "/" .. Source:gsub("^%./", ""):gsub("%.[^.]+$", "") .. ".o"
	local DependencyFile = Object:gsub("%.o$", ".d")

	if not NeedsCompile(Source, Object, DependencyFile) then
		return Object
	end

	print("compiling " .. Source)

	local Compiler = CC
	local Flags = CFlags
	local ExtraFlags = ""

	if Kind == "cpp" then
		Compiler = CXX
		Flags = CXXFlags
	elseif Kind == "asm" then
		ExtraFlags = " -x assembler-with-cpp " .. ASFlags
	end

	local Directory = Object:match("(.+)/[^/]+$")
	if Directory then
		Mkdir(Directory)
	end

	Run(
		Compiler
			.. " -MMD -MP"
			.. " -MF "
			.. Quote(DependencyFile)
			.. " -MT "
			.. Quote(Object)
			.. " "
			.. Flags
			.. ExtraFlags
			.. " -c "
			.. Quote(Source)
			.. " -o "
			.. Quote(Object)
	)

	return Object
end

local function CompileBinary(Source)
	local Object = Build .. "/" .. Source:gsub("^%./", ""):gsub("%.[^.]+$", "") .. ".o"

	if not IsNewer(Source, Object) then
		return Object
	end

	print("embedding " .. Source)

	local Directory = Object:match("(.+)/[^/]+$")
	if Directory then
		Mkdir(Directory)
	end

	Run("ld -r -b binary " .. Quote(Source) .. " -o " .. Quote(Object))

	return Object
end

local function BuildObjects()
	Mkdir(Build)

	local CFiles, CppFiles, SFiles, BinFiles = GetSourceFiles()
	local Objects = {}

	for _, Source in ipairs(BinFiles) do
		Objects[#Objects + 1] = CompileBinary(Source)
	end

	for _, Source in ipairs(CppFiles) do
		Objects[#Objects + 1] = CompileFile(Source, "cpp")
	end

	for _, Source in ipairs(CFiles) do
		Objects[#Objects + 1] = CompileFile(Source, "c")
	end

	for _, Source in ipairs(SFiles) do
		Objects[#Objects + 1] = CompileFile(Source, "asm")
	end

	return Objects, #CppFiles > 0
end

local function Link(Objects, HasCpp)
	local NeedsLink = not Exists(Target)

	for _, Object in ipairs(Objects) do
		if IsNewer(Object, Target) then
			NeedsLink = true
			break
		end
	end

	if not NeedsLink then
		print(Target .. " is up to date")
		return
	end

	print("linking " .. Target)

	local Linker = HasCpp and CXX or CC

	local LinkObjects = {}
	for _, Object in ipairs(Objects) do
		LinkObjects[#LinkObjects + 1] = Quote(Object)
	end

	Run(Linker .. " " .. Join(LinkObjects) .. " " .. LdFlags .. " " .. Libs .. " -o " .. Quote(Target))

	print("built " .. Target)
end

local function BuildApplication()
	local Objects, HasCpp = BuildObjects()
	Link(Objects, HasCpp)
end

local function Clean()
	print("cleaning " .. Target .. "...")
	Run("rm -rf " .. Quote(Build) .. " " .. Quote(Target))
end

local Commands = {
	all = BuildApplication,
	build = BuildApplication,
	clean = Clean,
}

local Command = arg[1] or "all"
local Action = Commands[Command]

if not Action then
	Fail("Unknown target: " .. Command .. "\nUsage: lua build.lua [all|build|clean]")
end

Action()
