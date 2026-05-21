--[[
    ╔══════════════════════════════════════════════════════╗
    ║           NEXUS  —  Remote Loader  v1.0              ║
    ║  Carga NexusClient.lua directamente desde GitHub     ║
    ║  sin necesidad de insertar nada en el juego.         ║
    ╠══════════════════════════════════════════════════════╣
    ║  USO EN EJECUTOR (Synapse, KRNL, Fluxus, etc.)       ║
    ║                                                      ║
    ║    loadstring(game:HttpGet(                          ║
    ║      "https://raw.githubusercontent.com/             ║
    ║       itzstxx/Nexus/main/src/NexusLoader.lua"        ║
    ║    ))()                                              ║
    ║                                                      ║
    ║  O pega este archivo completo en el ejecutor.        ║
    ╚══════════════════════════════════════════════════════╝

    CÓMO FUNCIONA:
      1. Descarga NexusClient.lua desde tu repo en GitHub.
      2. Lo ejecuta con loadstring() en el contexto local.
      3. Si HttpGet falla (sin permisos de HTTP o sin red)
         muestra un error claro en la consola.

    PERSONALIZACIÓN:
      · Cambia RAW_URL si mueves el archivo en el repo.
      · Cambia LOGO_IMAGE_ID por el asset id de tu logo
        (puedes hacerlo aquí para no tocar NexusClient.lua).
]]

-- ── URL del archivo fuente en GitHub (rama main) ──────────
local RAW_URL = "https://raw.githubusercontent.com/itzstxx/Nexus/main/src/NexusClient.lua"

-- ── (Opcional) Sobreescribe el logo antes de ejecutar ─────
--  Si lo dejas en "" se usa el valor que esté en NexusClient.
--  Ejemplo: "rbxassetid://123456789"
local LOGO_OVERRIDE = ""

-- ════════════════════════════════════════════════════════════
-- Descarga y ejecución
-- ════════════════════════════════════════════════════════════
local source do
    local ok, result = pcall(function()
        return game:HttpGet(RAW_URL, true)
    end)

    if not ok or type(result) ~= "string" or #result < 10 then
        error(
            "[NEXUS Loader] No se pudo descargar NexusClient.\n" ..
            "  → Verifica que HttpService esté habilitado en el juego.\n" ..
            "  → URL: " .. RAW_URL .. "\n" ..
            "  → Error: " .. tostring(result),
            2
        )
        return
    end

    source = result
end

-- Inyecta el logo override si se definió uno arriba
if LOGO_OVERRIDE ~= "" then
    -- Reemplaza la primera aparición de la línea LOGO_IMAGE_ID
    source = source:gsub(
        'local LOGO_IMAGE_ID%s*=%s*"[^"]*"',
        'local LOGO_IMAGE_ID = "' .. LOGO_OVERRIDE .. '"',
        1   -- solo la primera ocurrencia
    )
end

-- Compila
local fn, compileErr = loadstring(source, "NexusClient")
if not fn then
    error(
        "[NEXUS Loader] Error al compilar NexusClient:\n  " ..
        tostring(compileErr),
        2
    )
    return
end

-- Ejecuta en entorno protegido para capturar errores de runtime
local ok, runtimeErr = pcall(fn)
if not ok then
    error(
        "[NEXUS Loader] Error al ejecutar NexusClient:\n  " ..
        tostring(runtimeErr),
        2
    )
    return
end

print("[NEXUS Loader] NexusClient cargado correctamente desde GitHub.")
