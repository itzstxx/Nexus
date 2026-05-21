# Nexus UI

Interfaz futurista estilo system/status para un proyecto propio de Roblox Studio.

## Instalacion

1. Sube tu logo Nexus a Roblox como imagen/decal.
2. Abre `src/NexusClient.lua`.
3. Cambia `LOGO_IMAGE_ID` por tu asset id:

```lua
local LOGO_IMAGE_ID = "rbxassetid://TU_ID_DEL_LOGO"
```

4. Inserta el archivo como `LocalScript` en:

```text
StarterPlayer
+-- StarterPlayerScripts
```

## Controles

- Click corto en el boton flotante: abre/cierra el panel.
- Mantener presionado el boton flotante: activa/desactiva el modulo.
- Arrastrar el boton flotante: moverlo por pantalla.
- `RightShift`: abre/cierra el panel.
- `RightControl`: activa/desactiva el modulo.

## Integracion

El script crea un `BindableEvent` llamado `NexusChanged` dentro del `ScreenGui`.
Puedes escucharlo desde sistemas de tu propio juego:

```lua
local gui = game.Players.LocalPlayer.PlayerGui:WaitForChild("NexusSystemUI")
local changed = gui:WaitForChild("NexusChanged")

changed.Event:Connect(function(settings)
    print(settings.ModuleEnabled, settings.FOV, settings.Smooth)
end)
```

## Repositorio

```text
https://github.com/itzstxx/Nexus
```

## Raw

El archivo directo esta en:

```text
https://raw.githubusercontent.com/itzstxx/Nexus/main/src/NexusClient.lua
```

Nota: si el repositorio esta privado, el raw solo funcionara con una sesion autorizada de GitHub. Para usarlo sin login, cambia el repositorio a publico o instala el `LocalScript` directamente en Roblox Studio.

No se incluye un `loadstring` de executor. Esta version esta pensada para Roblox Studio y para juegos propios.
