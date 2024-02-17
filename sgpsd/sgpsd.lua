local random = require("ccryptolib.random")
local ed25519 = require("ccryptolib.ed25519")

-- FIXME: make sure that this doesnt bring the gps cluster down ( add more random sources )
function initRandom()
  local postHandle = assert(http.post("https://krist.dev/ws/start", ""))
  local data = textutils.unserializeJSON(postHandle.readAll())
  postHandle.close()

  random.init(data.url)

  http.websocket(data.url).close()
end

initRandom()

local srcPath = fs.getDir(shell.getRunningProgram())
local configPath = fs.combine(srcPath, "sgpsd.conf")
local pubkeyPath = fs.combine(srcPath, "key.pub")
local seckeyPath = fs.combine(srcPath, "key")

local function stringifyKey(key)
  local s = ""
  for i=1,#key do
    s = s .. string.format("%02x", key:sub(i,i):byte())
  end
  return s
end

local function parseStringifiedKey(key)
  if #key ~= 64 then
    return false, "key_length_invalid"
  end

  local res = ""
  for i=1,32 do
    local n = tonumber(key:sub(i*2-1,i*2), 16)
    if not n then
      return false, "key_malformated"
    end
    res = res .. string.char(n)
  end
  return res
end

local args = {...}

if args[1] and args[1]:lower() == "help" then
  print("Usage:\n")
  print("help   - help")
  print("keygen - generate keys")
  return
elseif args[1] and args[1]:lower() == "keygen" then
  io.write("Generating key pair... ")
  local seckey = random.random(32)
  local pubkey = ed25519.publicKey(seckey)
  print("Done")

  if fs.exists(seckeyPath) then
    local s = "I am aware that this will replace the private key and invalidate the public key."
    printError("Private key file already exists, please enter \""..s.."\" to confirm this, anything else to cancel")
    local r = read()
    if r == s then
      print("Continuing")
    else
      printError("Cancelled")
      return
    end
  end

  io.write("Saving key pair to file... ")
  local h = fs.open(seckeyPath, "w")
  h.write(stringifyKey(seckey))
  h.close()
  local h = fs.open(pubkeyPath, "w")
  h.write(stringifyKey(pubkey))
  h.close()
  print("Done")
  return
end

local config = (function()
  local h = assert(fs.open(configPath, "r"), string.format("Failed to open config at %s", configPath))
  local data = textutils.unserialise(h.readAll())
  h.close()

  return assert(data, string.format("Failed to parse config at %s", configPath))
end)()

if #config.sgpsMeta > 255 then
  error("sgpsMeta can't be longer than 255 characters")
end
if #config.modems == 0 then
  error("Expected at least one modem")
end

local secretKey, secretKeyError = (function()
  local h = fs.open(seckeyPath, "r")
  if not h then return false, "no_key_file" end
  local d = h.readAll()
  h.close()
  d, err = parseStringifiedKey(d)
  return d, err
end)()

if secretKey == false then
  if secretKeyError == "no_key_file" then
    printError("No key file: "..seckeyPath)
  elseif secretKeyError == "key_malformated" then
    printError("Malformated key in: "..seckeyPath)
  elseif secretKeyError == "key_length_invalid" then
    printError("Key length invalid in: "..seckeyPath)
  end
  return
end

local publicKey = ed25519.publicKey(secretKey)

for i, modem in ipairs(config.modems) do
  peripheral.call(modem[1], "closeAll")
  if i == 1 then
    peripheral.call(modem[1], config.serveGPS and "open" or "close", config.gpsPort)
    peripheral.call(modem[1], config.serveSGPS and "open" or "close", config.sgpsPort)
  end
end

do
  local s = stringifyKey(publicKey)

  local h = fs.open(pubkeyPath, "w")
  h.write(s)
  h.close()
end

-- TODO: great idea, don't rely on big pcall
local function mkresponse(VERSION, data)
  if VERSION == 1 then
    local respData = string.pack(">iiic32Ls1", data.pos[1], data.pos[2], data.pos[3], data.challengeString, os.epoch("utc"), config.sgpsMeta)

    return string.pack(">bs2c64c32", VERSION, respData, ed25519.sign(secretKey, publicKey, respData), publicKey)
  end

  return false
end

local sgpsServed, gpsServed = 0, 0
while true do
  term.clear()
  term.setCursorPos(1,1)
  print("Served "..gpsServed.." GPS requests")
  print("Served "..sgpsServed.." SGPS requests")
  print("\nPublic key: "..pubkeyPath)

  local _, periph, port, replyPort, msg, dist = os.pullEvent("modem_message")

  if periph == config.modems[1][1] and port == config.gpsPort and msg == "PING" and dist and config.serveGPS then
    for _, modem in ipairs(config.modems) do
      peripheral.call(modem[1], "transmit", replyPort, config.gpsPort, { modem[2], modem[3], modem[4] })
    end

    gpsServed = gpsServed + 1
  elseif periph == config.modems[1][1] and port == config.sgpsPort and type(msg) == "string" and #msg == 33 and dist and config.serveSGPS then
    for _, modem in ipairs(config.modems) do
      local ver, challenge = string.unpack(">bc32", msg)

      local ok, resp = pcall(mkresponse, ver, {
        pos = {modem[2], modem[3], modem[4]},
        challengeString = challenge
      })

      if ok and resp then
        peripheral.call(modem[1], "transmit", replyPort, config.sgpsPort, resp)
      end
      if not ok then error(resp) end
    end

    sgpsServed = sgpsServed + 1
  end
end
