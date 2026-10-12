# Dotfiles para Arch Linux

Configuración de **Neovim**, **Alacritty** y **Oh My Bash** con el tema
**Catppuccin Mocha** en todo, más scripts que la instalan en un Arch ya instalado o que
instalan el Arch entero desde el ISO.

La parte visual y de utilidades de Neovim se inspira en
[t4lentles5/minflair](https://github.com/t4lentles5/minflair) (GPL-3.0), adaptada
a Neovim 0.11+, blink.cmp y Catppuccin. El código está reescrito, no copiado.

Las ideas de los scripts (capturas, selector de sesiones tmux, yazi flotante,
informe del sistema) y de la barra de estado en píldoras vienen de
[gbbarcelos/dotfiles](https://github.com/gbbarcelos/dotfiles). Ese repo no tiene
licencia, así que no se copió código: todo está escrito de nuevo.

`panic-mode`, `layout-preset` y `keys` están inspirados en
[rhythmcreative/hyprland](https://github.com/rhythmcreative/hyprland) (GPL-3.0). Son
reescrituras con otra lógica (por ejemplo, `panic-mode` devuelve las ventanas a su
workspace); no se copió su código ni su instalador.

El selector de wallpapers opcional usa
[ujjalsigdel/hyprquickpaper](https://github.com/ujjalsigdel/hyprquickpaper) (MIT),
descargado del original.

Hay cinco escritorios opcionales, que se descargan del original y se parchean al
instalar; no se incluyen en este repo:
- [vmaltarello/bezel-hyprland](https://github.com/vmaltarello/bezel-hyprland) (GPL-3.0).
- [dhrruvsharma/shell](https://github.com/dhrruvsharma/shell) (GPL-3.0 o posterior).
  Sus wallpapers ([dhrruvsharma/wallpapers](https://github.com/dhrruvsharma/wallpapers))
  no tienen licencia, así que no se redistribuyen: la opción `--wallpapers` los
  descarga en tu equipo desde su repo.
- [Volcha-Z/Docky.rs](https://github.com/Volcha-Z/Docky.rs) (MIT): un dock y barra
  escritos en Rust.
- [MystiaFin/suzuha](https://github.com/MystiaFin/suzuha), un shell de escritorio
  para Niri hecho con [MystiaFin/amane](https://github.com/MystiaFin/amane) (MIT).
  suzuha no tiene licencia, así que no se redistribuye: el instalador lo descarga
  en tu equipo desde su repo.
- [Sn3akyy1/lucid](https://github.com/Sn3akyy1/lucid) (MIT): shell para Hyprland
  hecho con Quickshell.

## Estructura

```
dotfiles/
├── arch-install.sh         # instalador de Arch completo desde el ISO (disco, kernel, GRUB, usuario)
├── installer/
│   ├── defaults.conf       # valores por defecto: kernel zen, teclado us, whole disk…
│   ├── chroot-setup.sh     # configura el sistema recién instalado (dentro del chroot)
│   └── first-login.sh      # termina la instalación (dotfiles y escritorio) en el primer login
├── install.sh              # dotfiles: paquetes + symlinks, sobre un Arch ya instalado
├── bash/.bashrc            # Oh My Bash, historial, alias, fzf, zoxide, mise
├── alacritty/
│   ├── alacritty.toml
│   └── themes/catppuccin-mocha.toml   # dynamic.toml (vacío, sin versionar) lo rellena matugen
├── tmux/tmux.conf          # Catppuccin Mocha, sin plugins
├── bin/                    # scripts que se enlazan en ~/.local/bin
│   ├── capture             # capturas y grabación de pantalla (Wayland)
│   ├── sysreport           # temperatura, batería, CPU, memoria y disco
│   ├── panic-mode          # tecla de jefe: oculta ventanas, silencia y activa No molestar
│   ├── layout-preset       # presets temporales de layout y huecos
│   ├── keys                # lista de atajos de Hyprland con búsqueda
│   ├── yazi-float          # yazi flotante en Hyprland
│   ├── wallpaper-picker    # abre el selector de wallpapers
│   └── wallpaper-restore   # vuelve a poner el último wallpaper al iniciar sesión
├── components/
│   └── wallpaper-picker/   # selector de wallpapers opcional
│       └── install.sh      # descarga hyprquickpaper fijado a un commit y lo configura
├── desktops/
│   ├── bezel/              # escritorio Hyprland + Quickshell (opcional)
│   │   ├── install.sh      # descarga bezel fijado a un commit, lo parchea e instala
│   │   ├── patch.sh        # kitty → Alacritty y paleta → Catppuccin Mocha
│   │   ├── palette.map     # tabla de colores bezel → Catppuccin
│   │   └── recolor.pl
│   ├── dhruv/              # rice con colores del wallpaper (opcional)
│   │   ├── install.sh      # descarga el shell fijado a un commit, lo parchea e instala
│   │   └── patch.sh        # kitty → Alacritty e instalador sin preguntas con --yes
│   ├── docky/              # dock y barra en Rust (opcional)
│   │   ├── install.sh      # descarga Docky.rs fijado a un commit, lo parchea y compila
│   │   ├── patch.sh        # energía con systemctl y colores de Alacritty en vez de kitty
│   │   ├── alacritty-sync.tail.sh   # escribe alacritty/dynamic.toml con los colores del wallpaper
│   │   └── dockyrs.lua.in  # atajos y arranque para Hyprland
│   ├── suzuha/             # shell en Rust para Niri (opcional)
│   │   ├── install.sh      # descarga amane y suzuha fijados a un commit, parchea y compila
│   │   ├── patch.sh        # Alacritty en la integración de terminales y tmux con -e
│   │   └── alacritty.rs.in # función que escribe alacritty/dynamic.toml
│   ├── lucid/              # shell Quickshell con ajustes, bloqueo y selector (opcional)
│   │   ├── install.sh      # descarga Lucid fijado a un commit, lo parchea y ejecuta su instalador
│   │   └── patch.sh        # Alacritty en lugar de kitty, con colores por matugen
│   ├── matugen-alacritty.toml   # plantilla de colores de Alacritty (dhruv y lucid)
│   ├── hyprland-base.lua   # base mínima de Hyprland que usan dhruv y docky
│   └── niri-base.kdl       # base mínima de Niri que usa suzuha
└── nvim/
    ├── init.lua
    ├── .stylua.toml
    ├── spell/              # diccionario personal (zg)
    └── lua/
        ├── config/         # options, keymaps, autocmds, bootstrap de lazy.nvim
        └── plugins/        # un archivo por tema (lsp, telescope, ui, editor…)
```

## Instalar Arch completo desde el ISO

`arch-install.sh` instala Arch desde cero. Arranca el ISO oficial (en UEFI),
conéctate a internet (cable, o `iwctl` si es wifi) y:

```bash
pacman -Sy git          # si el ISO no lo trae
git clone <url-de-tu-repo> dotfiles && cd dotfiles
./arch-install.sh       # lo pregunta todo
```

Los colores del instalador siguen la paleta de Killjoy (Valorant): amarillo eléctrico sobre negro y grises,
con naranja para avisos y rojo para errores. Están en `installer/ui.sh`; en la consola del kernel, que solo tiene 16
colores, usa el amarillo brillante, y con `NO_COLOR=1` no pinta nada.

Al arrancar muestra una portada "KILLJOY INSTALLER" en letras de bloque (se adapta al ancho de la
consola y no sale si la salida no es una terminal).

El script pregunta, en este orden: usuario, nombre del equipo, disco, modo (disco
completo o dual-boot), escritorio y cuenta root; después las contraseñas. No hace
falta conocer la ruta del disco: lista los que encuentra con tamaño, bus (nvme, sata,
usb), modelo y los sistemas de archivos que contienen (si ve NTFS lo marca, porque
suele ser Windows), y eliges por número. Si hay uno solo, basta con Enter. No ofrece
el pendrive del ISO. Para verlos a mano, en otra consola (`Alt+F2`) usa `lsblk -p`.
Antes de borrar pide escribir la ruta del disco tal como sale en el resumen.

Los valores por defecto están en `installer/defaults.conf`:

| Qué | Por defecto |
|---|---|
| Kernel | `linux-zen` (más `linux-zen-headers`) |
| Teclado | `us` |
| Disco | **entero**: EFI de 1 GiB + raíz con el resto |
| Raíz | btrfs con subvolúmenes `@`, `@home`, `@log`, `@pkg`, `@snapshots` (zstd); `--fs ext4` si lo prefieres |
| Arranque | GRUB en `/efi`; los kernels viven en `/boot`, dentro de la raíz |
| Swap | zram (sin partición de swap) |
| Usuario | lo pide el script; con sudo |
| Root | bloqueado (se usa sudo); el script pregunta si prefieres darle contraseña (`--root password`) |
| Red | NetworkManager |
| Zona / idioma | `America/Tijuana`, `en_US.UTF-8` (y se genera `es_MX.UTF-8`) |

**Dual-boot (`--mode dualboot`)**: no borra nada. Usa el mayor espacio libre del
disco (mínimo 30 GiB) para la raíz, reutiliza la partición EFI que ya exista
(la de Windows, sin formatearla) y activa `os-prober` en GRUB. Antes tienes que
dejar ese espacio libre desde Windows (Administración de discos → Reducir
volumen); el script no redimensiona particiones ajenas. Si el disco usa MBR
en lugar de GPT, se niega.

Instalación sin preguntas:

```bash
echo 'mi-contraseña' > /tmp/pw
./arch-install.sh --disk /dev/nvme0n1 --mode whole --desktop lucid \
  --hostname arch --user andres --password-file /tmp/pw --confirm-disk /dev/nvme0n1
```

Con `--dry-run` hace las preguntas, enseña el resumen y sale sin tocar nada.

**Cómo se reparte el trabajo**: el ISO instala un sistema base que arranca (kernel,
GRUB, usuario, red, drivers de GPU y microcódigo detectados). Los paquetes de los
dotfiles, Neovim, Oh My Bash y el escritorio elegido se instalan en tu **primer
inicio de sesión** en una consola (`installer/first-login.sh`), ya con el sistema
arrancado. Necesita internet (por cable va solo; con wifi usa `nmtui`). Si algo
falla se repite al volver a entrar, y la pantalla de inicio de sesión (greetd +
tuigreet) solo se activa cuando el escritorio se instaló bien, para no dejar el
equipo arrancando en algo roto. En una laptop (batería detectada) añade `--laptop`.

**Qué no hace todavía**: cifrado LUKS, soporte BIOS/MBR, hibernación (no hay swap
en disco), ni escritorio bspwm.

## Instalación sobre un Arch ya instalado


```bash
git clone <url-de-tu-repo> ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

Opciones: `-y` (sin confirmaciones de pacman), `--no-packages` (solo enlazar la
configuración), `--no-omb` (no clonar Oh My Bash), `--desktop bezel|dhruv|docky|lucid|suzuha` (ver
más abajo), `--wallpapers` (solo con `--desktop dhruv`), `--wallpaper-picker`
(ver más abajo) y `--laptop` (instala y activa TLP para ahorrar batería).

Los archivos que ya existan (`~/.bashrc`, `~/.config/nvim`, `~/.config/alacritty`,
`~/.config/tmux` y los scripts de `~/.local/bin`) se mueven a `~/.dotfiles-backup/<fecha>/` antes de crear los symlinks. El repo
debe quedarse en su sitio, porque la configuración apunta a él.

Después abre una terminal nueva y ejecuta `nvim`. La primera vez lazy.nvim
instala los plugins, Mason instala los servidores LSP y treesitter compila los
parsers; revisa `:checkhealth` al terminar.

## Qué incluye

### Bash
- Oh My Bash con el tema `agnoster` (necesita Nerd Font, ya incluida).
- Historial grande sin duplicados ni comandos triviales, `eza` en lugar de `ls`,
  `bat` en lugar de `cat`, `fzf` con los colores del tema, `zoxide` (`z <dir>`) y
  `mise` si está instalado.
- `update` actualiza pacman y, si existe, yay.
- `tm` elige un directorio de zoxide con fzf y abre (o retoma) su sesión de tmux.
- Tu configuración local va en `~/.bashrc.local`, que no se versiona.

### Alacritty
- Catppuccin Mocha, JetBrainsMono Nerd Font 12, opacidad 0.95, padding de 16 y
  recarga automática de la configuración.
- Los colores están en `alacritty/themes/catppuccin-mocha.toml`. Después se
  importa `alacritty/dynamic.toml`, vacío por defecto: si usas el escritorio
  `dhruv`, matugen lo rellena con los colores del wallpaper y sustituye a
  Catppuccin. Para volver, vacía ese archivo.

### tmux
- Catppuccin Mocha, colores reales, ratón, ventanas desde 1 y barra arriba.
  Sin plugins. Se abre con `tm` o con `tmux`.

### Scripts (`bin/`)
- `capture full|region|rec-full|rec-region|stop`: capturas y grabaciones en
  Wayland. Copia la captura al portapapeles y avisa con una notificación. Si
  tienes `wayfreeze` (AUR), congela la pantalla mientras eliges la región.
  Ejemplo de atajo en Hyprland: `bind = , Print, exec, capture region`.
- `sysreport`: temperatura, batería (con su salud y consumo), CPU, memoria,
  disco y los procesos más pesados.
- `yazi-float`: en Hyprland abre yazi flotante y centrado si el workspace está
  vacío, o como ventana normal si no. Ejemplo: `bind = SUPER, E, exec, yazi-float`.
- `panic-mode`: tecla de jefe. Esconde todas las ventanas en un workspace
  especial, pausa la música, silencia salida y micrófono y activa No molestar
  (mako, dunst o swaync). Al pulsarlo otra vez devuelve cada ventana a su
  workspace y restaura el sonido como estaba. No bloquea la sesión.
- `layout-preset code|read|reset`: cambia al vuelo la distribución y los huecos
  (`code`: dwindle con huecos pequeños; `read`: master con márgenes amplios;
  `reset`: recarga tu configuración). Son cambios temporales.
- `keys`: lista los atajos que Hyprland tiene cargados (lee `hyprctl binds`, así
  que incluye los tuyos) y te deja buscar con fzf. `keys --print` solo los imprime.

Con los escritorios que usan la base de Hyprland (dhruv y docky) vienen ya
enlazados: `SUPER+Escape` (panic-mode), `SUPER+ALT+1/2/3` (layout-preset) y
`SUPER+F1` (keys). Con bezel o con tu propia configuración, añade tú los atajos.

### Laptop
`./install.sh --laptop` instala TLP y brightnessctl, activa `tlp.service` y
enmascara `systemd-rfkill`, como indica la documentación de TLP. TLP no debe
convivir con `power-profiles-daemon`: si lo tienes, el script avisa y no instala
nada; quita uno de los dos y vuelve a ejecutarlo.

### Neovim (requiere 0.11 o superior)

| Área | Plugin |
|---|---|
| Plugins | lazy.nvim |
| Tema y barra | catppuccin, lualine (extremos redondeados) |
| Interfaz | noice + nvim-notify, alpha-nvim (dashboard), indent-blankline, mini.indentscope, nvim-highlight-colors |
| Atajos | which-key |
| Búsqueda | telescope (con fzf-native), todo-comments |
| Explorador | neo-tree |
| Sintaxis | nvim-treesitter (rama `main`), nvim-ts-autotag |
| LSP | nvim-lspconfig, mason, mason-lspconfig (API nativa `vim.lsp.config`), trouble |
| Completado | blink.cmp + friendly-snippets |
| Formateo | conform.nvim |
| Git | gitsigns (con blame en la línea), lazygit.nvim |
| Edición | nvim-autopairs, nvim-surround, bufdelete |

El comentado con `gc` ya viene incluido en Neovim 0.10+, por eso no hay plugin.

Servidores LSP: `lua_ls` y `taplo` siempre. Si tienes `npm`, también `bashls`,
`jsonls`, `yamlls`, `html`, `cssls`, `ts_ls`, `pyright`, `tailwindcss` y
`emmet_language_server`. Con `go` se añade `gopls`; con `cargo`, `rust_analyzer`;
y con `gem`, `ruby_lsp`. Los servidores de Go, Rust y Ruby se instalan solos en el
siguiente arranque cuando existe el toolchain, así que puedes instalar esos
lenguajes con `mise` o `rustup` después. Java (`jdtls`) no está incluido; añádelo
en `lua/plugins/lsp.lua` si lo necesitas.

Ortografía en inglés y español: se activa sola en markdown, texto y mensajes de
commit, y se alterna con `<leader>us`. La primera vez Neovim ofrece descargar el
diccionario de español.

## Atajos de Neovim

El leader es la **barra espaciadora**. Pulsa el leader y espera para ver el menú
de which-key.

| Atajo | Acción |
|---|---|
| `<leader>ff` / `<leader><leader>` | Buscar archivos |
| `<leader>fg` / `<leader>fw` | Buscar texto / palabra bajo el cursor |
| `<leader>fb` / `<leader>fr` | Buffers / archivos recientes |
| `<leader>ft` | Buscar TODOs |
| `<leader>/` | Buscar dentro del buffer |
| `<leader>e` | Explorador de archivos |
| `gd` / `gD` / `gy` | Definición / declaración / tipo |
| `K` | Documentación bajo el cursor |
| `grn` / `gra` / `grr` | Renombrar / code action / referencias (defaults de 0.11) |
| `<leader>ca` / `<leader>cr` | Code action / referencias con telescope |
| `<leader>cf` / `<leader>cF` | Formatear / alternar el formateo al guardar |
| `gl` | Diagnóstico de la línea |
| `[d` `]d` / `[h` `]h` / `[t` `]t` | Diagnóstico / cambio de git / TODO anterior y siguiente |
| `<leader>xx` / `<leader>xX` | Diagnósticos del proyecto / del buffer (Trouble) |
| `<leader>xs` / `<leader>xl` | Símbolos / LSP en Trouble |
| `<leader>gg` | LazyGit |
| `<leader>bd` | Cerrar buffer sin romper las ventanas |
| `<C-h/j/k/l>` | Moverse entre ventanas |
| `<S-h>` / `<S-l>` | Buffer anterior / siguiente |
| `<A-j>` / `<A-k>` | Mover la línea o selección |
| `ys` `ds` `cs` | Añadir / borrar / cambiar delimitadores (surround) |
| `<leader>un` `ur` `us` `uw` `ud` | Alternar números, números relativos, ortografía, ajuste de línea, diagnósticos |

## Escritorio opcional: bezel (Hyprland + Quickshell)

```bash
./install.sh --desktop bezel          # todo junto
desktops/bezel/install.sh             # solo el escritorio
desktops/bezel/install.sh --patch-only    # descarga y parchea, sin instalar
desktops/bezel/install.sh --uninstall     # vuelve a tu configuración anterior
```

Es el escritorio de [bezel](https://github.com/vmaltarello/bezel-hyprland): barra
vertical, marco alrededor de la pantalla, widgets, launcher (`SUPER+Space`),
notificaciones, bloqueo de pantalla y, con `--greeter`, pantalla de inicio de
sesión. `SUPER+H` muestra todos los atajos.

Qué hace el script:
1. Descarga bezel fijado al commit probado (`BEZEL_REF` en `desktops/bezel/install.sh`).
2. Cambia **kitty por Alacritty** en el launcher, la barra, las reglas de ventana
   y la lista de paquetes.
3. Recolorea **toda** su paleta (shell, GTK/Qt, yazi, btop, lazygit, zathura, imv,
   pantalla de bloqueo) a **Catppuccin Mocha**. El acento es mauve; la tabla está
   en `desktops/bezel/palette.map`.
4. Ejecuta su instalador con yazi, btop, lazygit, zathura e imv. Su Neovim,
   starship y Zed no se instalan, para no pisar los tuyos.

Si algún parche deja de encajar porque bezel cambió, el script se detiene con un
error en vez de dejar una instalación a medias. Para actualizar bezel, cambia
`BEZEL_REF` y vuelve a ejecutar.

Ten en cuenta:
- Requiere **Hyprland 0.56 o superior** (configuración en Lua).
- Bezel **reemplaza** tu configuración de Hyprland, Quickshell y GTK/Qt. Lo
  anterior queda en `~/.local/state/bezel/backup/`.
- Alacritty no tiene el modo de un solo proceso de kitty, así que cada ventana es
  un proceso aparte (algo más de RAM), ni el rastro del cursor. Si ves una barra
  de título en Alacritty, pon `decorations = "None"` en `alacritty.toml`.
- Quickshell y Hyprland no se han podido probar aquí: los parches se verificaron
  como cambios de texto, pero el escritorio no se ha ejecutado.

## Selector de wallpapers opcional

```bash
./install.sh --wallpaper-picker
```

[hyprquickpaper](https://github.com/ujjalsigdel/hyprquickpaper) es un selector de
wallpapers con teclado hecho con Quickshell: 10 diseños (dock, coverflow,
flotante, rejilla…), miniaturas en caché y soporte de videos. Funciona en
Hyprland, niri, sway y river; no en X11 ni KDE. **No lo uses con `--desktop dhruv`,
`--desktop docky`, `--desktop lucid` ni `--desktop suzuha`**, que ya traen el suyo (el instalador lo impide).

Qué hace el script:
1. Instala `quickshell`, `qt6-5compat`, `jq`, `imagemagick` y `swaybg`.
2. Descarga el selector fijado al commit probado (`HQP_REF`).
3. Lo configura la primera vez: carpeta `~/Pictures/wallpapers`, `swaybg` como
   demonio y el mauve de Catppuccin como color de borde. En las siguientes
   ejecuciones conserva tu configuración, incluido el diseño que hayas elegido.
4. Genera las miniaturas si ya hay imágenes en esa carpeta.

No edita la configuración de tu compositor. Al terminar imprime las líneas que
tienes que añadir (Hyprland en Lua o en `.conf`, y niri). Los comandos son
`wallpaper-picker` (abre el selector), `wallpaper-picker settings` (cambia el
diseño) y `wallpaper-restore`, que pones en el arranque porque `swaybg` no
recuerda el fondo al reiniciar la sesión.

Para recolorear Alacritty con cada wallpaper, añade a `post_apply` en
`~/.local/share/dotfiles/hyprquickpaper/config.json` un comando de matugen, por
ejemplo `matugen image \"$WALLPAPER_STILL\"`. Hace falta la plantilla de
`desktops/matugen-alacritty.toml` registrada en matugen. Los videos
necesitan además `ffmpeg` y `mpvpaper` (AUR).

## Escritorio opcional: dhruv (Hyprland + Quickshell, colores del wallpaper)

```bash
./install.sh --desktop dhruv --wallpapers   # todo junto
desktops/dhruv/install.sh --help            # solo el escritorio, con más opciones
desktops/dhruv/install.sh --uninstall
```

Es el shell de [dhrruvsharma/shell](https://github.com/dhrruvsharma/shell): barra
superior, centro de control, launcher, cambiador de ventanas, portapapeles,
bloqueo y 14 temas de escritorio. La diferencia con bezel es que **los colores
salen del wallpaper** con matugen, no son fijos. `SUPER+W` abre el selector de
wallpapers; al elegir uno cambian los colores del shell, de Alacritty y de los
bordes de Hyprland.

Qué hace el script:
1. Descarga el shell fijado al commit probado (`DHRUV_REF`).
2. Cambia **kitty por Alacritty** y hace que el instalador original no pregunte
   cuando usas `-y`.
3. Actualiza el sistema (`pacman -Syu`) y ejecuta el instalador original: instala
   sus paquetes, enlaza `~/.config/quickshell` y añade sus atajos a Hyprland.
4. Si no tienes `~/.config/hypr/hyprland.lua`, instala una base mínima propia
   (`desktops/hyprland-base.lua`, teclado US). Si ya existe, no la toca. Si solo
   tienes un `hyprland.conf`, no crea nada para no desactivarlo y te avisa.
5. Registra en matugen una plantilla para Alacritty y otra para los bordes de
   Hyprland.
6. Con `--wallpapers`, copia su colección (unos 730 MB) a `~/Pictures/wallpapers`
   sin pisar lo que ya tengas.

Ten en cuenta:
- No se puede usar a la vez que bezel: los dos reemplazan Quickshell.
- Requiere **Hyprland 0.56 o superior** (configuración en Lua) y el monitor a
  escala 1; los paneles están dimensionados para eso.
- Neovim, fzf y tmux siguen en Catppuccin Mocha, así que no cambian con el
  wallpaper. Solo Alacritty, el shell y los bordes de Hyprland lo hacen.
- Los lectores de anime, manga y novela, el chat con IA y el navegador de
  Wallhaven necesitan backends aparte (`--extras` instala sus entornos de
  Python). Sin eso, esos paneles no funcionan.
- La base de Hyprland usa la API Lua tal como la usa el repo original; no se ha
  podido comprobar contra un Hyprland real.
- El reparto de los 16 colores ANSI de Alacritty a partir de Material You es una
  elección propia (rojo siempre es el de error); ajústalo en
  `desktops/matugen-alacritty.toml`.

## Escritorio opcional: docky (Hyprland + Rust, el más ligero)

```bash
./install.sh --desktop docky
desktops/docky/install.sh --help       # solo el escritorio, con más opciones
desktops/docky/install.sh --uninstall
```

Es [Volcha-Z/Docky.rs](https://github.com/Volcha-Z/Docky.rs): un único binario de
unos 13 MB con dock de apps ancladas, buscador de aplicaciones, historial del
portapapeles, capturas, selector de wallpapers, barra de widgets (reloj,
workspaces, música, CPU/RAM, bandeja), indicadores de volumen y brillo, y demonio
de notificaciones. No usa Quickshell.

Qué hace el script:
1. Descarga Docky.rs fijado al commit probado (`DOCKY_REF`) en
   `~/.local/share/dotfiles/docky`.
2. Aplica dos parches: los botones de suspender, reiniciar y apagar usan
   `systemctl` en lugar de `sudo -n`, y la sincronización de colores escribe
   `~/.config/alacritty/dynamic.toml` en lugar de la configuración de kitty.
3. Instala las dependencias con `pacman -Syu`, matugen y un demonio de
   wallpapers (`awww`, o `swww` si no está; si no, intenta `yay`/`paru`).
4. Compila con `cargo build --release`.
5. Si no tienes `~/.config/hypr/hyprland.lua`, genera uno desde
   `desktops/hyprland-base.lua`; si ya existe, solo añade `require("dockyrs")`. Si
   solo tienes un `hyprland.conf`, no crea nada y te avisa.

Atajos principales: `SUPER+D` buscador, `SUPER+W` wallpapers, `SUPER+V`
portapapeles, `F8`/`F9` captura de región/pantalla, `F10` grabar. Con docky el
atajo para pasar una ventana a flotante es `SUPER+SHIFT+V`.

Ten en cuenta:
- No se puede usar a la vez que bezel o dhruv.
- Sus wallpapers van en `~/Pictures/Wallpapers` (con mayúscula), distinta de la
  `~/Pictures/wallpapers` de los otros módulos.
- Para que los colores sigan al wallpaper hay que activar `accent_from_wallpaper`
  en `~/.config/dockyrs/config.json`.
- El instalador original de Docky.rs crea reglas de sudoers y desactiva otros
  demonios de notificaciones; este no hace ninguna de las dos cosas.
- Cambiar la fuente desde su menú no afecta a Alacritty (solo sabe hacerlo con kitty).
- Requiere **Hyprland 0.56 o superior** (configuración en Lua).

## Escritorio opcional: lucid (Hyprland + Quickshell, el más completo)

```bash
./install.sh --desktop lucid
desktops/lucid/install.sh --help       # solo el escritorio, con más opciones
desktops/lucid/install.sh --uninstall
```

Es [Sn3akyy1/lucid](https://github.com/Sn3akyy1/lucid), con diseño Material 3 y
colores que salen del wallpaper. Trae barra con paneles (reloj, calendario,
Wi-Fi, Bluetooth, notificaciones, energía), dock que se convierte en lanzador
(apps, comandos, emoji, wallpapers, portapapeles, ventanas), centro de control,
espacios especiales (música, chat, tareas, monitor del sistema), widgets de
escritorio, selector de wallpapers y de temas, pantalla de bloqueo con PAM,
capturas con OCR, una app de Ajustes (red, pantallas, ventanas, almacenamiento,
cuentas, atajos) y un tema para SDDM. Incluye Catppuccin Mocha, Gruvbox, Nord,
Nightfox y Tokyo Night, cada uno con modo claro.

Qué hace el script:
1. Descarga Lucid fijado al commit probado (`LUCID_REF`).
2. Aplica parches: la terminal es **Alacritty** (`F9` y también `SUPER+Q`), y se añade
   una plantilla de matugen para que Alacritty siga el tema o el wallpaper.
3. Actualiza el sistema y ejecuta **su instalador** con `--no-look` (no toca
   kitty, starship, VSCode ni el tema GTK) y `--no-plugins` (no compila el cursor
   que se inclina). Sin `--apps` también pasa `--no-apps`: no instala Zen,
   VSCodium, Spotify, Steam, Vesktop ni Proton VPN. Sus paquetes salen de pacman
   y, los que no estén, del AUR con `yay` o `paru`.
4. Copia sus wallpapers (unos 180 MB) a `~/Pictures/wallpapers/<tema>`. Con
   `--no-wallpapers` no.

Atajos principales: `SUPER` (tocar) lanzador, `SUPER+B` wallpapers, `SUPER+T` temas,
`SUPER+S` ajustes, `SUPER+/` lista de atajos, `SUPER+W` vista de workspaces,
`SUPER+Escape` pantalla de sesión, `F10` bloquear, `Print` captura. Se editan en
Ajustes → Atajos.

Ten en cuenta:
- **Sustituye tu configuración de Hyprland** por la suya (atajos, reglas, blur y
  arranque). La tuya se copia antes a `~/.config/hypr.backup-<fecha>`.
- No se puede usar a la vez que bezel, dhruv, docky ni suzuha.
- Si tienes otro demonio de notificaciones (dunst, mako, swaync), su instalador
  ofrece enmascararlo, porque la barra de Lucid sirve las notificaciones.
- Si tienes SDDM, instala su tema con `sudo` pero no lo activa; para usarlo pon
  `Current=lucid` bajo `[Theme]` en `/etc/sddm.conf`.
- Requiere **Hyprland 0.55 o superior** (configuración en Lua).
- Por usar `--no-look` no se aplica su tema GTK (adw-gtk3 y los iconos FairyWren)
  ni su prompt de starship; el prompt sigue siendo Oh My Bash.
- El deslizador «Glass» de Ajustes (transparencia de la terminal) solo sabe cambiar
  la opacidad de kitty; con Alacritty la terminal queda con la opacidad de su
  configuración (`window.opacity`).
- `--wallpapers` no se puede combinar con lucid; sus wallpapers van incluidos.

## Escritorio opcional: suzuha (Niri + shell en Rust)

```bash
./install.sh --desktop suzuha
desktops/suzuha/install.sh --help       # solo el escritorio, con más opciones
desktops/suzuha/install.sh --uninstall
```

Es la configuración [MystiaFin/suzuha](https://github.com/MystiaFin/suzuha), hecha
con la librería [amane](https://mystiafin.github.io/amane/): todo el shell es un
programa en Rust que dibuja con la GPU, sin QML ni GTK. Trae barra, lanzador (con
modo comandos con `>`), centro de control con visualizador de audio, panel de
utilidades (Wi-Fi, Bluetooth, brillo, calendario, notificaciones, grabador),
selector de wallpapers, widgets flotantes, pomodoro, conversor de archivos, menú
de apagado, pantalla de bloqueo y ventana de ajustes. Es el único escritorio de
este repo para **Niri**, no para Hyprland.

Qué hace el script:
1. Descarga amane y suzuha fijados a un commit probado (`AMANE_REF`, `SUZUHA_REF`).
2. Aplica tres parches a suzuha: Alacritty entra en su integración de terminales
   (solo conocía kitty y foot) y escribe `~/.config/alacritty/dynamic.toml` con los
   colores del shell, esa integración viene activada, y el selector de proyectos
   de tmux abre Alacritty con `-e`.
3. Instala dependencias con `pacman -Syu`: Niri, Alacritty, las librerías de amane y
   las fuentes. Poppins, Material Design Icons y `xdg-desktop-portal-gnome` se
   buscan en pacman y, si no están, en el AUR con `yay` o `paru`.
4. Si no tienes `~/.config/niri/config.kdl`, instala una base mínima propia
   (`desktops/niri-base.kdl`, teclado US). Si ya existe, no la toca y te dice qué
   líneas añadir.
5. Compila el CLI de amane en `~/.local/bin` y luego el shell con `amane compile`.
   La primera vez tarda varios minutos.

Atajos de la base: `SUPER+Q` terminal, `SUPER+E` yazi, `SUPER+C` cerrar,
`SUPER+SHIFT+V` flotante, `SUPER+ESPACIO` lanzador, `SUPER+SHIFT+W` wallpapers,
`SUPER+A` centro de control, `SUPER+N` utilidades, `SUPER+SHIFT+S` ajustes y
`SUPER+L` bloquear. Los wallpapers van en `~/Pictures/Wallpapers`.

Ten en cuenta:
- No se puede usar a la vez que bezel, dhruv o docky, ni con `--wallpaper-picker`.
- Necesita una **GPU con Vulkan** y su controlador (`vulkan-radeon`, `vulkan-intel`
  o `nvidia-utils`); el instalador solo avisa si no encuentra ninguno.
- amane está en versión 0.1 y se describe como experimental; suzuha es la
  configuración personal de su autor y puede cambiar o romperse.
- `panic-mode`, `layout-preset`, `keys` y `yazi-float` usan `hyprctl`: con Niri no
  funcionan.
- Para que tmux siga los colores del wallpaper, activa la integración de tmux en
  los ajustes del shell y añade `source-file -q ~/.local/state/amane/tmux-colors.conf`
  a `tmux/tmux.conf`. Viene desactivada porque cambia la barra de Catppuccin.
- Si el shell se bloquea con la pantalla de bloqueo puesta, el compositor no
  muestra el escritorio; recupera la sesión desde otra TTY.
- Cambiar de tema a Gruvbox o Catppuccin fijo en los ajustes solo afecta al shell,
  Alacritty y lo que actives en sus integraciones; Neovim y fzf no cambian.

## Qué no se ha probado

Los parches de bezel y de dhruv solo se verificaron como cambios de texto, y los
instaladores de dhruv, docky y del selector de wallpapers se ejecutaron de principio
a fin con pacman, sudo, `swaybg` y la descarga de fuentes simuladas. Docky.rs sí se
compiló de verdad con los parches aplicados, pero no se ha ejecutado. Lo mismo con
amane y suzuha: el CLI y el shell compilan con mis parches, pero no se han
ejecutado (no hay Wayland, Vulkan ni Niri en mi entorno de pruebas), así que no
sé si Alacritty recarga `dynamic.toml` al cambiar el wallpaper, ni si los
nombres de paquete de Poppins y Material Design Icons son los correctos. La
configuración de Niri solo se comprobó como sintaxis KDL, no con `niri validate`. No se han usado
con Quickshell, Hyprland, niri ni matugen reales, y no he probado que
`swaybg` pinte el fondo ni que el selector se abra.

`arch-install.sh`: el particionado (modos whole y dualboot, con y sin partición EFI
previa, disco MBR y falta de espacio), `mkfs`, los montajes (ext4), `genfstab`, la
creación del usuario, la contraseña y todo `chroot-setup.sh` se ejecutaron de verdad
sobre un disco virtual, con un `pacstrap` simulado que copia un sistema base falso;
las particiones de un Windows simulado quedaron idénticas. `grub-install`,
`grub-mkconfig`, `locale-gen` y `systemctl` fueron simulados, así que no sé si el
sistema real arranca. btrfs y la EFI en vfat no se pudieron montar en mi entorno de
pruebas (el kernel no los trae), por lo que el camino btrfs, los subvolúmenes y el
`fstab` con la EFI no se ejecutaron. Los nombres de paquete (`greetd-tuigreet`,
`nvidia-open-dkms`…), las opciones de `tuigreet` y que `os-prober` encuentre Windows
desde el chroot sin pasos extra tampoco están comprobados. Pruébalo primero en una
máquina virtual UEFI.

Lucid: el módulo se probó con `pacman`, `sudo` y el instalador de Lucid simulados
(los parches se aplican, los conflictos de opciones fallan y el reinstalado es
idempotente). La plantilla de Alacritty sí se renderizó con matugen 4.2.0 real y el resultado es un TOML
válido con todos los colores resueltos. No lo he ejecutado con Hyprland ni Quickshell, así
que no sé si el shell arranca, ni si Alacritty recarga `dynamic.toml` al cambiar
de wallpaper. La plantilla de Alacritty para matugen está en `desktops/matugen-alacritty.toml`
y `--uninstall` de Lucid solo se revisó leyendo el código.

`panic-mode`, `layout-preset` y `keys` se ejecutaron con un `hyprctl` simulado: no sé
si `hyprctl dispatch`/`keyword` se comportan igual con la configuración en Lua de un
Hyprland real, y `keys` supone los campos de `hyprctl binds -j` según su
documentación. Además `capture`, `sysreport`, la función `tm` y el instalador se ejecutaron en un
entorno de pruebas con las herramientas externas (grim, wf-recorder, tmux, pacman)
sustituidas por simulaciones. No se han usado con Wayland, tmux ni TLP reales.
`yazi-float` depende del formato de salida de `hyprctl` y solo se revisó con
shellcheck.

## Personalizar

- **Tema de Neovim**: cambia `flavour` en `nvim/lua/plugins/colorscheme.lua`.
- **Tema de Bash**: cambia `OSH_THEME` en `bash/.bashrc`.
- **Más plugins**: crea un archivo en `nvim/lua/plugins/` que devuelva una
  tabla de lazy.nvim; se carga solo.
- **Quitar noice** (línea de comandos flotante): borra su bloque en
  `nvim/lua/plugins/ui.lua`.
- **Formateo al guardar**: está activo. Si en un proyecto ajeno genera diffs
  grandes, desactívalo con `<leader>cF`.
- Después del primer arranque, versiona `nvim/lazy-lock.json` para fijar las
  versiones de los plugins.

## Opcional

Bash no trae autosugerencias ni resaltado de sintaxis como zsh. Si los quieres,
`ble.sh` los añade (está en el AUR como `blesh-git`).
