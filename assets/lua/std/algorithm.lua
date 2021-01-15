local algorithm = {}

function algorithm.contains(haystack, needle, compareFunc)
    compareFunc = compareFunc or function(a, b) return a == b end
    for _, value in ipairs(haystack) do
        if compareFunc(needle, value) then return true end
    end
    return false
end

function algorithm.any(range, func)
    for _, value in ipairs(range) do
        if func(value) then return true end
    end
    return false
end

function algorithm.applyFiltered(range, filter, apply)
    for _, value in ipairs(range) do
        if filter(value) then apply(value) end
    end
end

return algorithm