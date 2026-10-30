Locale = Locale or {}

function Locale:new(tbl)
    tbl = tbl or {}
    setmetatable(tbl, self)
    self.__index = self
    return tbl
end

function Locale:t(key, vars)
    local value = key
    local node = self.phrases or self.translations or {}

    for part in string.gmatch(key, "[^%.]+") do
        if type(node) == "table" then
            node = node[part]
        else
            node = nil
            break
        end
    end

    if type(node) == "string" then
        value = node
    end

    if vars and type(value) == "string" then
        for k, v in pairs(vars) do
            value = value:gsub("%%{" .. k .. "}", tostring(v))
        end
    end

    return value
end

Lang = Lang or Locale:new({
    phrases = {},
    warnOnMissing = false
})
