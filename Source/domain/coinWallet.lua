-- Blue's two-byte BCD counter, represented as an exact bounded session integer.
-- No inventory slot, encoded quest flags, or separate mutable wallet exists.
CoinWallet = {}
local limit
function CoinWallet.limit()
    if not limit then
        local record = assert(json.decodeFile("data/coinWallet.json"))
        assert(record.schema == 1 and record.source_revision == "af519899719f0754965776faac0e836a3b906e6d"
            and record.limit == 9999, "unverified Blue coin counter")
        limit = record.limit
    end
    return limit
end
function CoinWallet.empty()
    return 0
end
function CoinWallet.normalize(value)
    assert(Party._integer(value, 0, CoinWallet.limit()), "invalid Blue coin counter")
    return assert(math.tointeger(value))
end
