
# ── Alacritty (parche de dotfiles) ───────────────────────────────────────────
# Sustituye la salida para kitty: escribe los colores en dynamic.toml, que
# alacritty.toml importa después del tema Catppuccin. Los tonos ANSI se calculan
# a partir del tono de cada color (rojo, verde, amarillo…), no de los roles de
# Material You.
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/alacritty"
mkdir -p "$config_dir"
out="$config_dir/dynamic.toml"

py="$(mktemp)"
trap 'rm -f "$py"' EXIT
cat > "$py" <<'PYEOF'
import json, sys, colorsys

c = json.load(sys.stdin)

def to_rgb(hexstr):
    hexstr = hexstr.lstrip("#")
    return tuple(int(hexstr[i:i+2], 16) / 255 for i in (0, 2, 4))

def to_hex(rgb):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v * 255))) for v in rgb)

sats, lits = [], []
for role in ("primary", "secondary", "tertiary"):
    r, g, b = to_rgb(c[role])
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    sats.append(s)
    lits.append(l)
sat = sum(sats) / len(sats)
lit = sum(lits) / len(lits)

def hue(deg, bright=False):
    l = lit + (1.0 - lit) * 0.4 if bright else lit * 0.72
    return to_hex(colorsys.hls_to_rgb(deg / 360, min(1.0, l), sat))

def section(name, **pairs):
    print(f"[{name}]")
    for key, value in pairs.items():
        print(f'{key} = "{value}"')
    print()

section("colors.primary", background=c["surface"], foreground=c["on_surface"],
        dim_foreground=c["outline"], bright_foreground=c["on_surface"])
section("colors.cursor", text=c["on_primary"], cursor=c["primary"])
section("colors.selection", text=c["on_primary_container"], background=c["primary_container"])
section("colors.normal", black=c["surface_container"], red=hue(0), green=hue(120),
        yellow=hue(50), blue=hue(240), magenta=hue(300), cyan=hue(180), white=c["outline"])
section("colors.bright", black=c["outline_variant"], red=hue(0, True), green=hue(120, True),
        yellow=hue(50, True), blue=hue(240, True), magenta=hue(300, True),
        cyan=hue(180, True), white=c["on_surface"])
PYEOF

# Se escribe a un archivo temporal y se renombra, para que Alacritty no lea el TOML a medias
echo "$roles_json" | python3 "$py" > "$out.tmp"
mv "$out.tmp" "$out"

echo "Alacritty colors synced from $src_desc"
