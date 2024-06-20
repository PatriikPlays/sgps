local ed25519 = require("ccryptolib.ed25519")
local expect = require("cc.expect").expect

CHANNEL_SGPS = 65524

local PROTOCOL_VERSION = 1

function parseStringifiedKey(key)
    if #key ~= 64 then
        return false, "key_length_invalid"
    end

    local res = ""
    for i=1,32 do
        local n = tonumber(key:sub(i*2-1,i*2), 16)
        if not n then
            return false, "key_malformed"
        end
        res = res .. string.char(n)
    end
    return res
end

local DEFAULT_PUBLIC_KEYS = { parseStringifiedKey("461cfdbc732f44937c4fa5d249a742f5567b0d57d5c7f1eebfdbbd58fb812acf") }

local function trilaterate(A, B, C)
    local a2b = B.vPosition - A.vPosition
    local a2c = C.vPosition - A.vPosition

    if math.abs(a2b:normalize():dot(a2c:normalize())) > 0.999 then
        return nil
    end

    local d = a2b:length()
    local ex = a2b:normalize()
    local i = ex:dot(a2c)
    local ey = (a2c - ex * i):normalize()
    local j = ey:dot(a2c)
    local ez = ex:cross(ey)

    local r1 = A.distance
    local r2 = B.distance
    local r3 = C.distance

    local x = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
    local y = (r1 * r1 - r3 * r3 - x * x + (x - i) * (x - i) + j * j) / (2 * j)

    local result = A.vPosition + ex * x + ey * y

    local zSquared = r1 * r1 - x * x - y * y
    if zSquared > 0 then
        local z = math.sqrt(zSquared)
        local result1 = result + ez * z
        local result2 = result - ez * z

        local rounded1, rounded2 = result1:round(0.01), result2:round(0.01)
        if rounded1.x ~= rounded2.x or rounded1.y ~= rounded2.y or rounded1.z ~= rounded2.z then
            return rounded1, rounded2
        else
            return rounded1
        end
    end

    return result:round(0.01)
end

local function narrow(p1, p2, fix)
    local dist1 = math.abs((p1 - fix.vPosition):length() - fix.distance)
    local dist2 = math.abs((p2 - fix.vPosition):length() - fix.distance)

    if math.abs(dist1 - dist2) < 0.01 then
        return p1, p2
    elseif dist1 < dist2 then
        return p1:round(0.01)
    else
        return p2:round(0.01)
    end
end

local function has(tbl, val)
    for _,v in ipairs(tbl) do
        if v == val then return true end
    end
end

local function findWirelessModem()
    for _, s in ipairs(rs.getSides()) do
        if peripheral.getType(s) == "modem" and peripheral.call(s, "isWireless") then
            return s
        end
    end
end

local function cprint(condition, str)
    if condition then print(str) end
end

function locate(timeout, debug, pubkeys)
    timeout = timeout or 2
    expect(1, timeout, "number")
    expect(2, debug, "boolean", "nil")
    expect(3, pubkeys, "table")

    local modemName = findWirelessModem()
    if not modemName then
        cprint(debug, "Failed to find wireless modem")
        return nil
    end
    local modem = peripheral.wrap(modemName)

    local wasSGPSOpen = modem.isOpen(CHANNEL_SGPS)
    if not wasSGPSOpen then modem.open(CHANNEL_SGPS) end
    cprint(debug and not wasSGPSOpen, "Opened SGPS channel")
    cprint(debug and wasSGPSOpen, "SGPS channel already open")

    cprint(debug, "Transmitting SGPS ping")
    local challengeString = ""
    for i=1,32 do
        challengeString = challengeString .. string.char(math.random(0,255)) -- FIXME: USE CSPRNG
    end
    modem.transmit(CHANNEL_SGPS, CHANNEL_SGPS, string.pack(">bc32", PROTOCOL_VERSION, challengeString))

    local fixes = {}
    local pos1, pos2 = nil, nil
    local timeoutTimer = os.startTimer(timeout)
    while true do
        local e, p1, p2, p3, p4, p5 = os.pullEvent()
        if e == "modem_message" then

            local side, channel, replyChannel, message, distance = p1, p2, p3, p4, p5

            if side == modemName and channel == CHANNEL_SGPS and replyChannel == CHANNEL_SGPS and distance and type(message) == "string" then
                local s,e = pcall(function()
                    local protoVer, sdata, signature, pubkey = string.unpack(">bs2c64c32", message)
                    if protoVer ~= PROTOCOL_VERSION then return end
                    if not has(pubkeys, pubkey) then return end

                    local x, y, z, receivedChallenge, time, meta = string.unpack(">iiic32Ls1", sdata)
                    if os.epoch("utc") - time > 15000 then return end
                    if os.epoch("utc") - time < -2500 then return end
                    if receivedChallenge ~= challengeString then return end
                    if not ed25519.verify(pubkey, sdata, signature) then return end

                    do
                        local tFix = { vPosition = vector.new(x, y, z), distance = distance }
                        cprint(debug, tFix.distance .. " metres from " .. tostring(tFix.vPosition))
                        if tFix.distance == 0 then
                            pos1, pos2 = tFix.vPosition, nil
                        else
                            -- Insert our new position in our table, with a maximum of three items. If this is close to a
                            -- previous position, replace that instead of inserting.
                            local insIndex = math.min(3, #fixes + 1)
                            for i, older in pairs(fixes) do
                                if (older.vPosition - tFix.vPosition):length() < 1 then
                                    insIndex = i
                                    return true
                                end
                            end
                            fixes[insIndex] = tFix

                            if #fixes >= 3 then
                                if not pos1 then
                                    pos1, pos2 = trilaterate(fixes[1], fixes[2], fixes[3])
                                else
                                    pos1, pos2 = narrow(pos1, pos2, fixes[3])
                                end
                            end
                        end
                        if pos1 and not pos2 then
                            return true
                        end
                    end
                end)

                if s and e then break end
            end
        elseif e == "timer" then
            if p1 == timeoutTimer then
                break
            end
        end
    end

    if not wasSGPSOpen then
        modem.close(CHANNEL_SGPS)
    end

    if pos1 and pos2 then
        if debug then
            print("Ambiguous position")
            print("Could be " .. pos1.x .. "," .. pos1.y .. "," .. pos1.z .. " or " .. pos2.x .. "," .. pos2.y .. "," .. pos2.z)
        end
        return nil
    elseif pos1 then
        cprint(debug, "Position is " .. pos1.x .. "," .. pos1.y .. "," .. pos1.z)
        return pos1.x, pos1.y, pos1.z
    else
        cprint(debug, "Could not determine position")
        return nil
    end
end

return {locate=locate, parseStringifiedKey=parseStringifiedKey, DEFAULT_PUBLIC_KEYS=DEFAULT_PUBLIC_KEYS}
