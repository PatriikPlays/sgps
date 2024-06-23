local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")

local lzwCompress = (function() local a=bit32;local function b(bn1,bn2)bytes={}bytes[1]=a.band(bn1,0xFF)bytes[2]=a.rshift(bn1,8)+a.lshift(a.band(bn2,0xF),4)bytes[3]=a.rshift(bn2,4)return bytes[1],bytes[2],bytes[3]end;local function c(d,e,f)bn1=d+a.lshift(a.band(e,0xF),8)bn2=a.lshift(f,4)+a.band(a.rshift(e,4),0xF)return bn1,bn2 end;local function g(h)local i={}for j=1,255 do if h then i[string.char(j)]=j else i[j]=string.char(j)end end;if not h then i[256]=256 end;return i end;local function k(l)local m=g(true)local n=""local o;local p=256;local q=string.len(l)local r={}local s;for j=1,q do if p==4095 then r[#r+1]=m[n]r[#r+1]=256;m=g(true)p=256;n=""end;o=string.sub(l,j,j)s=n..o;if m[s]then n=s else r[#r+1]=m[n]p=p+1;m[s]=p;n=o end end;r[#r+1]=m[n]return r end;local function t(u)local m=g(false)local v;local o;local w;local r={}r[#r+1]=m[u[1]]prefix=m[u[1]]for j=2,#u do w=u[j]if w==256 then m=g(false)prefix=""else v=m[w]if v then o=string.sub(v,1,1)r[#r+1]=v;if prefix~=""then m[#m+1]=prefix..o end else o=string.sub(prefix,1,1)r[#r+1]=prefix..o;m[#m+1]=prefix..o end;prefix=m[w]end end;return table.concat(r)end;local function x(y)for j=0,2 do if y[#y]==0 then y[#y]=nil end end end;function decompress(z)local A={}for j=1,#z,3 do A[#A+1],A[#A+2]=c(z[j],z[j+1]or 0,z[j+2]or 0)end;x(A)return t(A)end;function compress(z)local A={}local u=k(z)for j=1,#u,2 do A[#A+1],A[#A+2],A[#A+3]=b(u[j],u[j+1]or 0)end;x(A)return A end;local a=bit32;local function b(bn1,bn2)bytes={}bytes[1]=a.band(bn1,0xFF)bytes[2]=a.rshift(bn1,8)+a.lshift(a.band(bn2,0xF),4)bytes[3]=a.rshift(bn2,4)return bytes[1],bytes[2],bytes[3]end;local function g(h)local i={}for j=1,255 do if h then i[string.char(j)]=j else i[j]=string.char(j)end end;if not h then i[256]=256 end;return i end;local function k(l)local m=g(true)local n=""local o;local p=256;local q=string.len(l)local r={}local s;for j=1,q do if p==4095 then r[#r+1]=m[n]r[#r+1]=256;m=g(true)p=256;n=""end;o=string.sub(l,j,j)s=n..o;if m[s]then n=s else r[#r+1]=m[n]p=p+1;m[s]=p;n=o end end;r[#r+1]=m[n]return r end;local function x(y)for j=0,2 do if y[#y]==0 then y[#y]=nil end end end;return function(z)local A={}local u=k(z)for j=1,#u,2 do A[#A+1],A[#A+2],A[#A+3]=b(u[j],u[j+1]or 0)end;x(A)return A end end)()
local lzwDecompressStr = [====[local a=bit32;local function b(c,d,e)bn1=c+a.lshift(a.band(d,0xF),8)bn2=a.lshift(e,4)+a.band(a.rshift(d,4),0xF)return bn1,bn2 end;local function f(g)local h={}for i=1,255 do if g then h[string.char(i)]=i else h[i]=string.char(i)end end;if not g then h[256]=256 end;return h end;local function j(k)local l=f(false)local m;local n;local o;local p={}p[#p+1]=l[k[1]]prefix=l[k[1]]for i=2,#k do o=k[i]if o==256 then l=f(false)prefix=""else m=l[o]if m then n=string.sub(m,1,1)p[#p+1]=m;if prefix~=""then l[#l+1]=prefix..n end else n=string.sub(prefix,1,1)p[#p+1]=prefix..n;l[#l+1]=prefix..n end;prefix=l[o]end end;return table.concat(p)end;local function q(r)for i=0,2 do if r[#r]==0 then r[#r]=nil end end end;return function(s)local t={}for i=1,#s,3 do t[#t+1],t[#t+2]=b(s[i],s[i+1]or 0,s[i+2]or 0)end;q(t)return j(t)end]====]

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

Options:Default("verbose")

Tasks:clean()

Tasks:minify "minify" {
    input = "build/sgps.lua",
    output = "build/sgps.min.lua",
}

Tasks:require "main" {
    startup = "sgps.lua",
    output = "build/sgps.lua",
}

local CompressTask = Task:subclass("sgps.client.CompressTask"):addOptions( { "files" } )

function CompressTask:initialize(context, name, dependencies)
	Task.initialize(self, name, dependencies)

	self:description "Compress lua files"
end

function CompressTask:setup(context, runner)
	Task.setup(self, context, runner)

	if type(self.options.files) ~= "table" then 
		context.logger:error("Task '%s': Invalid option 'files', expected table, got %s", self.name, type(self.options.files))
	else
		for filei, file in ipairs(self.options.files) do
			if type(file) ~= "table" then
				context.logger:error("Task '%s': Invalid file pair #%d, expected table, got %s", self.name, filei, type(file))
			else
				if type(file[1]) ~= "string" then
					context.logger:error("Task '%s': Invalid file #1 in file pair #%d - expected string, got %s", self.name, filei, type(file[1]))
				end
				if type(file[2]) ~= "string" then
					context.logger:error("Task '%s': Invalid file #2 in file pair #%d - expected string, got %s", self.name, filei, type(file[2]))
				end
			end
		end
	end
end

function CompressTask:runAction(context)
	for pairi, pair in ipairs(self.options.files) do
		local src = fs.combine(context.root, pair[1])
		local dest = fs.combine(context.root, pair[2])
		
		local h, err = fs.open(src, "r")
		if h then
			d = h.readAll()
			h.close()

			local compressedRaw = ""
			for k,v in pairs(compress(d)) do
				compressedRaw = compressedRaw .. string.char(v)
			end

			local h = fs.open("afile", "w")
			for i=1,#compressedRaw do
				h.write(compressedRaw:sub(i,i):byte().."\n")
			end
			h.close()

			local s = ""
			for i=1,255 do
				s = s .. string.format("%03d ", compressedRaw:sub(i,i):byte())
			end
			print(s)

			local compressed = string.format(
				"local x=[[\13]] if x:byte()==10 then print('x', x:sub(1,1):byte()) local libPath=select(2,...)or error('This SGPS library has to be required')local h,d=fs.open(libPath,'rb')or error('Failed to open SGPS library')d=h.readAll()h.close()return load(d, nil, nil, _G)()else return load(load([====[%s]====],nil,nil,_G)()({([=================================[%s]=================================]):byte(1,-1)}),nil,nil,_G)()end"
			, lzwDecompressStr, compressedRaw)

			print(load(lzwDecompressStr,nil,nil,_G)()({compressedRaw:byte(1,-1)}):sub(0,100))

			local h, err = fs.open(dest, "wb")
			if h then
				h.write(compressed)
				h.close()

				context.logger:verbose(string.format("Compress task '%s': compressed file #%d %s (%db) -> %s (%db)", self.name, pairi, src, #d, dest, #compressed))
			else
				context.logger:error("Compress task '%s': failed to open file with 'w': %s", self.name, err)
			end
		else
			context.logger:error("Compress task '%s': failed to open file with 'r': %s", self.name, err)
		end
	end
end

Runner:include({ compressTask = function(self, name, taskDepends, taskAction)
	return self:injectTask(CompressTask(self.env, name, taskDepends, taskAction))
end})

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
					local h, err = fs.open(file, "rb")
					if h then
						data = h.readAll()
						h.close()
					else
						context.logger:error("Info task '%s': failed to open file with 'rb': %s", self.name, err)
					end
				end
				if data then
					local h, err = fs.open(file, "wb")
					if h then
						h.write(commentStr .. "\n" .. data)
						h.close()
					else
						context.logger:error("Info task '%s': failed to open file with 'wb': %s", self.name, err)
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
			{ "build/sgps.lua", "build/sgps.cmp.lua", "build/sgps.min.lua", "build/sgps.min.cmp.lua" }
		}
	}
}

Tasks:compressTask "compress" {
	files = {
		{ "build/sgps.lua", "build/sgps.cmp.lua" },
		{ "build/sgps.min.lua", "build/sgps.min.cmp.lua" }
	}
}

Tasks:Task "build" {"clean", "minify", "compress", "info"} :Description("Main build task")

Tasks:Default "build"