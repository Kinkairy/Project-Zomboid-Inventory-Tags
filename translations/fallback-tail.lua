function IT.language()
    local language=Translator and Translator.getLanguage() or nil
    local name=tostring(IT.call(language,"name") or "EN"):upper():gsub("%-","_")
    if name=="ZH_CN" or name=="ZH_HANS" or name=="ZH" then return "CN" end
    if name=="ZH_TW" or name=="ZH_HANT" then return "CH" end
    return name
end
function IT.text(id)
    local key="IGUI_InventoryTags_"..id
    local native=getTextOrNull and getTextOrNull(key) or getText(key)
    local lang=IT.language()
    local english=fallback.EN[id]
    if fallback[lang] and (not native or native==key or native==english) then
        return fallback[lang][id] or english or key
    end
    return native or english or key
end
