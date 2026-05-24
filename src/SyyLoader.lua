--[[
    ╔══════════════════════════════════════════════════════╗
    ║           SYY  —  Remote Loader  v1.0               ║
    ║  Carga SyyClient.lua directamente desde GitHub      ║
    ╠══════════════════════════════════════════════════════╣
    ║  USO EN EJECUTOR (Synapse, KRNL, Fluxus, etc.)      ║
    ║                                                      ║
    ║    loadstring(game:HttpGet(                          ║
    ║      "https://raw.githubusercontent.com/             ║
    ║       itzstxx/Nexus/main/src/SyyLoader.lua"          ║
    ║    ))()                                              ║
    ║                                                      ║
    ║  O pega este archivo completo en el ejecutor.        ║
    ╚══════════════════════════════════════════════════════╝
]]

local RAW_URL = "https://raw.githubusercontent.com/itzstxx/Nexus/main/src/SyyClient.lua"

local source do
    local ok, result = pcall(function()
        return game:HttpGet(RAW_URL, true)
    end)
    if not ok or type(result) ~= "string" or #result < 10 then
        error("[SYY Loader] No se pudo descargar SyyClient.\n"..
              "  → URL: "..RAW_URL.."\n"..
              "  → Error: "..tostring(result), 2)
        return
    end
    source = result
end

local fn, compileErr = loadstring(source, "SyyClient")
if not fn then
    error("[SYY Loader] Error al compilar:\n  "..tostring(compileErr), 2)
    return
end

local ok2, runtimeErr = pcall(fn)
if not ok2 then
    error("[SYY Loader] Error al ejecutar:\n  "..tostring(runtimeErr), 2)
    return
end

print("[SYY Loader] SyyClient cargado correctamente — "..game.Players.LocalPlayer.Name)