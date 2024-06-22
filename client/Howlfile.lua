local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")

local function grabLatestCommitHash(gitDir)
	local path = gitDir

	local s, ret = pcall(function()
		local h = fs.open(fs.combine(path, "HEAD"), "r")
		local d1 = h.readAll()
		h.close()

		local branch = d1:match("ref: refs/heads/(.+)"):gsub("[\r\n]+$", "")

		local refpath = fs.combine(path, "refs/heads/" .. branch)
		local h, err = fs.open(refpath, "r")
		local d2 = h.readAll()
		h.close()

		return d2:gsub("[\r\n]+$", "")
	end)

	if not s then
		return "<unknown>"
	end

	return ret
end

local function grabLatestSGPSCommitHash(root)
	return grabLatestCommitHash(fs.combine(root, "../.git/")) -- root is "reporoot/client"
end

local function grabLatestCCryptoLibCommitHash(root)
	return grabLatestCommitHash(fs.combine(root, "../.git/modules/client/ccryptolib/"))
end

local Task = require "howl.tasks.Task"
local assert = require "howl.lib.assert"
local Runner = require "howl.tasks.Runner"

Options:Default("trace")

Tasks:clean()

Tasks:minify "minify" {
    input = "build/sgps.lua",
    output = "build/sgps.min.lua",
}

Tasks:require "main" {
    startup = "sgps.lua",
    output = "build/sgps.lua",
}

local InfoTask = Task:subclass("sgps.client.InfoTask"):addOptions( { "comments" } )

function InfoTask:initialize(context, name, dependencies)
	Task.initialize(self, name, dependencies)

	self:description "Add comments on the top of a file"
end

function InfoTask:setup(context, runner)
	Task.setup(self, context, runner)

	if type(self.options.comments) ~= "table" then
		context.logger:error("Task '%s': Invalid option 'comments', expected table, got %s", self.name, type(self.options.comments))
	else
		for commenti, comment in ipairs(self.options.comments) do
			local commentStr = comment[1]
			local files = comment[2]

			if not (type(commentStr) == "string" or type(commentStr) == "function") then
				context.logger:error("Task '%s': Invalid comment in comment #%d, expected string|function, got %s", self.name, commenti, type(commentStr))
			end

			if type(files) ~= "table" then
				context.logger:error("Task '%s': Invalid files in comment #%d, expected string, got %s", self.name, commenti, type(files))
			else
				for i, file in ipairs(files) do
					if type(file) ~= "string" then
						context.logger:error("Task '%s': Invalid comment #%d - invalid file #%d, expected string, got %s", self.name, commenti, i, type(file))
					end
				end
			end
		end
	end
end

function InfoTask:runAction(context)
	for commenti, comment in ipairs(self.options.comments) do
		local commentStr = comment[1]
		
		if type(commentStr) == "function" then
			local s,ret = pcall(commentStr, context)
			if not s then
				context.logger:error("Info task '%s': failed to execute comment generator fn #%d: %s", self.name, commenti, ret)
			elseif type(ret) == "string" then
				commentStr = ret
			else
				context.logger:error("Info task '%s': invalid return type from comment generator fn #%d: expected string, got %s", self.name, commenti, type(ret))
			end
		end

		if type(commentStr) == "string" then
			for filei, file in ipairs(comment[2]) do
				context.logger:verbose(string.format("Info task '%s': doing comment #%d for file #%d (%s)", self.name, commenti, filei, file))
				file = fs.combine(context.root, file)
				local data
				do
					local h, err = fs.open(file, "r")
					if h then
						data = h.readAll()
						h.close()
					else
						context.logger:error("Info task '%s': failed to open file with 'r': %s", self.name, err)
					end
				end
				if data then
					local h, err = fs.open(file, "w")
					if h then
						h.write(commentStr .. "\n" .. data)
						h.close()
					else
						context.logger:error("Info task '%s': failed to open file with 'w': %s", self.name, err)
					end
				end
			end
		end
	end
end

Runner:include({ infoTask = function(self, name, taskDepends, taskAction)
	return self:injectTask(InfoTask(self.env, name, taskDepends, taskAction))
end})

Tasks:infoTask "info" {
	comments = {
		{ 
			function(ctx)
				return table.concat({
					"-- Copyright (c) 2024 PatriikPlays",
					"-- ",
					"-- This work is licensed under the terms of the MIT license.",
					"-- For a copy, see <https://opensource.org/licenses/MIT>.",
					"-- ",
					string.format("-- SGPS client %s (https://github.com/PatriikPlays/sgps), built at %s", grabLatestSGPSCommitHash(ctx.root), timestamp),
					string.format("-- This program uses ccryptolib %s (https://github.com/migeyel/ccryptolib), which is licensed under the MIT license", grabLatestCCryptoLibCommitHash(ctx.root))
				}, "\n")
			end,
			{ "build/sgps.lua", "build/sgps.min.lua" }
		}
	}
}

Tasks:Task "build" {"clean", "minify", "info"} :Description("Main build task")

Tasks:Default "build"