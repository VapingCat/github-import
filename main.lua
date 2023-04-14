local Module, Metatable = {}, {}

local RepositoryPattern = "^https://github.com/(%w+)/(%w+)"
local CurrentRepository = nil

local import

local function HandleError(Error, Path)
    if Path then
        warn(('Compilation error on path `%s`:\n%s'):format(Path, Error))
    else
        warn(('Compilation error on import:\n%s'):format(Path, Error))
    end
    
    local Thread = coroutine.running()
    
    task.defer(function()
        coroutine.close(Thread)
    end)
    
    return coroutine.yield()
end

local function RunFunctionWithEnvironment(Function, Path)
    local Environment = setmetatable({
        ['import'] = import
    }, { __index = getgenv() })
    
	setfenv(Function, Environment)
	
	local Returns = {pcall(coroutine.wrap(Function))}
	local Success = Returns[1]
	
	if not Success then
        return HandleError(Returns[2], Path)
	end
	
	return select(2, unpack(Returns))
end

import = function(pathOrStringOrFunction, branch)
    local Function = loadstring(pathOrStringOrFunction)
    
    if Function then
        return RunFunctionWithEnvironment(Function)
	else
		if type(pathOrStringOrFunction) == 'function' then
			return RunFunctionWithEnvironment(pathOrStringOrFunction)
		else
			if not CurrentRepository then return end

			local Url = ("https://raw.githubusercontent.com/%s/%s/%s/%s"):format(unpack(CurrentRepository), branch or "main", pathOrStringOrFunction)
			local Success, Source = pcall(function()
				return game:HttpGet(Url)
			end)

			if not Success then
				return error("Unknown github path.")
			end

			local Function, CompileError = loadstring(Source)

			if Function then
				return RunFunctionWithEnvironment(Function, pathOrStringOrFunction)
			else
				return error(CompileError)
			end
		end
	end
end

local function IsGithubRepository(urlOrUsername, repositoryName)
	if urlOrUsername then
		if repositoryName then
			return urlOrUsername, repositoryName
		end
		
		return urlOrUsername:match(RepositoryPattern) or ("https://github.com/"..urlOrUsername):match(RepositoryPattern)
	end
	
	return false
end

function Module:SetRepository(githubUrlOrName, repositoryName)
	local Username, RepositoryName = IsGithubRepository(githubUrlOrName, repositoryName)
	
	if Username then
		CurrentRepository = {Username, RepositoryName}
	end
end

Metatable.__call = import

return setmetatable(Module, Metatable)
