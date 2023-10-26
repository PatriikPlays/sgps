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

local config = (function()
  local h = assert(fs.open(configPath, "r"), string.format("Failed to open config at %s", configPath))
  local data = textutils.unserialise(h.readAll())
  h.close()

  return assert(data, string.format("Failed to parse config at %s", configPath))
end)()

if #config.modems == 0 then
  error("Expected at least one modem")
end

local secretKey = config.secretKey
local publicKey = ed25519.publicKey(secretKey)

for i, modem in ipairs(config.modems) do
  peripheral.call(modem[1], i==1 and "open" or "closeAll", config.port)
end

(function()
  local s = ""
  for i=1,#publicKey do
    s = s .. string.format("\\%03d", publicKey:sub(i,i):byte())
  end

  local h = fs.open(pubkeyPath, "w")
  h.write(s)
  h.close()
end)()

local sgpsServed, gpsServed = 0, 0
while true do
  term.clear()
  term.setCursorPos(1,1)
  print("Served "..gpsServed.." GPS requests")
  print("Served "..sgpsServed.." SGPS requests")
  print("\nPublic key: "..pubkeyPath)
  local _, periph, port, replyPort, msg, dist = os.pullEvent("modem_message")
  if periph == config.modems[1][1] and port == config.port and (msg == "PING" or msg == "SPING") and dist then
    for _, modem in ipairs(config.modems) do
      if msg == "PING" then
        peripheral.call(modem[1], "transmit", replyPort, config.port, { modem[2], modem[3], modem[4] })
      elseif msg == "SPING" then
        local sgpsStr = modem[2]..";"..modem[3]..";"..modem[4]
        local signature = ed25519.sign(secretKey, publicKey, sgpsStr)
        sgpsStr = modem[2]..";"..modem[3]..";"..modem[4]+1
        peripheral.call(modem[1], "transmit", replyPort, config.port, { modem[2], modem[3], modem[4], sgpsStr, signature })
      end
    end

    if msg == "PING" then
      gpsServed = gpsServed + 1
    elseif msg == "SPING" then
      sgpsServed = sgpsServed + 1
    end
  end
end
