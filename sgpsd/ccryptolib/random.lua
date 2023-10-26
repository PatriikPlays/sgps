local expect   = require "cc.expect".expect
local blake3   = require "ccryptolib.blake3"
local chacha20 = require "ccryptolib.chacha20"
local util     = require "ccryptolib.internal.util"

local lassert = util.lassert

-- Extract local context.
local ctx = {
    "ccryptolib 2023-04-11T19:43Z random.lua initialization context",
    os.epoch("utc"),
    os.epoch("ingame"),
    math.random(0, 2 ^ 24 - 1),
    math.random(0, 2 ^ 24 - 1),
    tostring({}),
    tostring({}),
}

local state = blake3.digest(table.concat(ctx, "|"))
local initialized = false

--- Mixes entropy into the generator, and marks it as initialized.
--- @param seed string The seed data.
local function init(seed)
    expect(1, seed, "string")
    state = blake3.digestKeyed(state, seed)
    initialized = true
end

--- Mixes extra entropy into the generator state.
--- @param data string The additional entropy to mix.
local function mix(data)
    expect(1, data, "string")
    state = blake3.digestKeyed(state, data)
end

--- Generates random bytes.
--- @param len number The desired output length.
--- @return string bytes 
local function random(len)
    expect(1, len, "number")
    lassert(initialized, "attempt to use an uninitialized random generator", 2)
    local msg = ("\0"):rep(math.max(len, 0) + 32)
    local nonce = ("\0"):rep(12)
    local out = chacha20.crypt(state, nonce, msg, 8, 0)
    state = out:sub(1, 32)
    return out:sub(33)
end

return {
    init = init,
    mix = mix,
    random = random,
}
