-- Exact signed-int32 decimal wire values, independent of SDK JSON numbers.
-- Shared by save headers and future explicit domain/RNG codecs; never replaces
-- the global JSON decoder or silently repairs a previously rounded number.
DecimalInteger={MIN=-2147483647-1,MAX=2147483647}
local function bounds(low,high)
    low,high=low or DecimalInteger.MIN,high or DecimalInteger.MAX
    return low,high,math.type(low)=="integer" and math.type(high)=="integer"
        and low>=DecimalInteger.MIN and high<=DecimalInteger.MAX and low<=high
end
function DecimalInteger.encode(value,low,high)
    local valid; low,high,valid=bounds(low,high)
    if not valid or math.type(value)~="integer" then return nil,"native-integer-required" end
    if value<low or value>high then return nil,"out-of-range" end
    return string.format("%d",value)
end
function DecimalInteger.decode(text,low,high)
    local valid; low,high,valid=bounds(low,high)
    if not valid or type(text)~="string" or #text<1 or #text>11
        or not(text=="0" or text:match("^-?[1-9][0-9]*$")) then return nil,"invalid-integer-text" end
    local value
    if text=="-2147483648" then value=DecimalInteger.MIN
    else
        local negative=text:sub(1,1)=="-"
        local digits=negative and text:sub(2) or text
        value=0
        for i=1,#digits do
            local digit=digits:byte(i)-48
            if value>(DecimalInteger.MAX-digit)//10 then return nil,"integer-overflow" end
            value=value*10+digit
        end
        if negative then value=-value end
    end
    if value<low or value>high then return nil,"out-of-range" end
    return value
end
