-- Pure view-model. No Unity globals; exercised by Lua behavioral tests.
local model = {}
function model.filter(mods, query, tag)
    local result = {}; query = (query or ""):lower()
    for _, item in ipairs(mods) do
        local tags = table.concat(item.tags or {}, " ")
        local matches = tag == nil or tag == "全部"
        for _, candidate in ipairs(item.tags or {}) do if candidate == tag then matches = true end end
        local haystack = (item.id .. " " .. item.name .. " " .. item.description .. " " .. tags):lower()
        if matches and (query == "" or haystack:find(query, 1, true)) then result[#result + 1] = item end
    end
    return result
end
function model.tags(mods)
    local result, seen = { "全部" }, {}
    for _, item in ipairs(mods) do for _, tag in ipairs(item.tags or {}) do
        if not seen[tag] then result[#result + 1] = tag; seen[tag] = true end
    end end
    return result
end
function model.page(items, index, count)
    local pages = math.max(1, math.ceil(#items / count))
    index = math.max(1, math.min(index, pages))
    local result = {}; for i = (index - 1) * count + 1, math.min(index * count, #items) do result[#result + 1] = items[i] end
    return result, index, pages
end
function model.next_value(field, value, direction)
    if field.type == "bool" then return value == "true" and "false" or "true" end
    if field.type == "enum" then
        for i, option in ipairs(field.options) do if option == value then
            return field.options[(i - 1 + direction) % #field.options + 1]
        end end
        return field.default
    end
    if field.type == "number" then
        local current = tonumber(value) or tonumber(field.default)
        local steps = math.floor((current - field.min) / field.step + 0.5) + direction
        local n = math.max(field.min, math.min(field.max, field.min + steps * field.step))
        return string.format("%.6g", n)
    end
    return value
end
function model.theme(values)
    return {
        opacity = tonumber(values.opacity) or 0.95,
        count = values.density == "紧凑" and 7 or 5,
        scale = tonumber(values.font_scale) or 1,
        show_tags = values.show_tags ~= "false",
        compact = values.density == "紧凑",
    }
end
return model
