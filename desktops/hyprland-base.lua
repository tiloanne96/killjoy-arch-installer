-- Base mínima de Hyprland (0.56 o superior, configuración en Lua) para los
-- escritorios dhruv y docky. Solo se instala si no tienes ya un
-- ~/.config/hypr/hyprland.lua.
--
-- Los atajos del shell se cargan más abajo con require("quickshell") (dhruv);
-- docky sustituye esa línea por require("dockyrs") y quita los bloques entre
-- las marcas "media-begin/media-end" y "start-begin/start-end" (con arroba
-- delante), porque su drop-in ya trae los atajos con OSD y no usa Quickshell.
--
-- Los colores de los bordes salen del wallpaper (matugen escribe colors.lua);
-- si todavía no existe, se usan unos colores fijos.

local terminal = "alacritty"
local mainMod  = "SUPER"

local ok, colors = pcall(require, "colors")
if not ok then
    colors = {
        primary           = "rgba(cba6f7ff)",
        tertiary          = "rgba(89b4faff)",
        surface_container = "rgba(313244ff)",
        outline           = "rgba(6c7086ff)",
        shadow            = "rgba(11111bff)",
    }
end

-------------------
---- AUTOSTART ----
-------------------

-- @start-begin
hl.on("hyprland.start", function()
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("qs")
end)
-- @start-end

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 15,
        border_size = 2,

        col = {
            active_border   = { colors = { colors.primary, colors.tertiary },         angle = 45 },
            inactive_border = { colors = { colors.surface_container, colors.outline }, angle = 45 },
        },

        resize_on_border = true,
    },

    decoration = {
        rounding = 12,

        shadow = {
            enabled      = true,
            range        = 18,
            render_power = 3,
            color        = colors.shadow,
        },
    },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll = true,
        },
    },

    misc = {
        -- El fondo lo dibuja Quickshell
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})

---------------------
---- KEYBINDINGS ----
---------------------

-- Atajos y toggles de los paneles de Quickshell
require("quickshell")

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(terminal .. " -e yazi"))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Capturas y grabación (script capture de este repo, en ~/.local/bin)
hl.bind("Print",                hl.dsp.exec_cmd("capture full"))
hl.bind("SHIFT + Print",        hl.dsp.exec_cmd("capture region"))
hl.bind("CTRL + Print",         hl.dsp.exec_cmd("capture rec-region"))
hl.bind("CTRL + SHIFT + Print", hl.dsp.exec_cmd("capture stop"))

-- Utilidades de bin/: tecla de jefe, presets de layout y lista de atajos
hl.bind(mainMod .. " + Escape",  hl.dsp.exec_cmd("panic-mode"))
hl.bind(mainMod .. " + ALT + 1", hl.dsp.exec_cmd("layout-preset code"))
hl.bind(mainMod .. " + ALT + 2", hl.dsp.exec_cmd("layout-preset read"))
hl.bind(mainMod .. " + ALT + 3", hl.dsp.exec_cmd("layout-preset reset"))
hl.bind(mainMod .. " + F1",      hl.dsp.exec_cmd(terminal .. " --class keys-float --title atajos -e keys"))

-- Mover el foco con las flechas
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspaces 1-10 (la tecla 0 es el 10) y mover la ventana a cada uno
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Mover y redimensionar ventanas con el ratón
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- @media-begin
-- Volumen, brillo y multimedia
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set +5%"),                          { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"),                          { locked = true, repeating = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),                                 { locked = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd("playerctl play-pause"),                           { locked = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"),                           { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),                             { locked = true })
-- @media-end

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- La lista de atajos (bin/keys) sale flotante
hl.window_rule({
    name  = "keys-float",
    match = { class = "^(keys-float)$" },
    float = true,
})

-- yazi-float (bin/yazi-float) abre yazi con esta clase
hl.window_rule({
    name  = "yazi-float",
    match = { class = "^(yazi-float)$" },
    float = true,
})
