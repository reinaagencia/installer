#!/usr/bin/env bash
# =============================================================================
# 🚀 Suite Reina · Instalación (bootstrap público v2)
# =============================================================================
# Entrega de la Suite por GitHub con credencial de UN SOLO USO validada en
# Supabase. El pack viaja cifrado y la clave de descifrado solo se entrega
# si la credencial es válida y no ha sido usada.
#
# One-liner (recomendado):
#   curl -fsSL https://raw.githubusercontent.com/reinaagencia/installer/main/install.sh \
#     -o /tmp/instalar-suite.sh && bash /tmp/instalar-suite.sh
#
# Pipe directo (también soportado; requiere terminal interactiva):
#   curl -fsSL https://raw.githubusercontent.com/reinaagencia/installer/main/install.sh | bash
#
# Opciones:
#   -h, --help     Muestra esta ayuda y sale.
# =============================================================================

set -euo pipefail

# ─── Versión del bootstrap (no del pack) ──────────────────────────────────────
SCRIPT_VERSION="2.0.0"

# ─── Constantes (verificadas en vivo) ─────────────────────────────────────────
SUPABASE_URL="https://gegklkperqguypexsbtw.supabase.co"
# Clave PUBLICABLE (apta para hardcodear en script público). NUNCA la secreta.
SUPABASE_PUBLISHABLE_KEY="sb_publishable_2mnhOMAqU-3A7Yulzm6N_Q_TFXWFqS4"
MANIFEST_URL="https://raw.githubusercontent.com/reinaagencia/suite-pack/main/manifest.public.json"
SELF_URL="https://raw.githubusercontent.com/reinaagencia/installer/main/install.sh"
LICENSE_FILE="${HOME}/.agents/suite-license.json"

PACK_VERSION="desconocida"

# ─── Colores (solo si hay terminal) ───────────────────────────────────────────
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

log()   { printf '%b\n' "${GREEN}[✓]${NC} $*"; }
info()  { printf '%b\n' "${BLUE}[i]${NC} $*"; }
warn()  { printf '%b\n' "${YELLOW}[!]${NC} $*"; }
error() { printf '%b\n' "${RED}[✗]${NC} $*" >&2; }
header(){ printf '\n%b\n\n' "${CYAN}${BOLD}══ $* ══${NC}"; }

# ─── Ayuda ────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Suite Reina · Instalación (bootstrap v${SCRIPT_VERSION})

Uso:
  curl -fsSL ${SELF_URL} -o /tmp/instalar-suite.sh && bash /tmp/instalar-suite.sh

  # o directo por pipe (requiere terminal interactiva):
  curl -fsSL ${SELF_URL} | bash

El instalador pedirá tu USUARIO y CONTRASEÑA de activación (de un solo uso),
los validará contra Reina Agencia, descargará el pack cifrado, lo descifrará
e instalará la Suite.

Opciones:
  -h, --help     Muestra esta ayuda y sale.
  --check        Verifica y descarga el pack (activación + sha256 + descifrado
                 + extracción) pero NO instala nada. Útil para diagnóstico.
                 OJO: consume la credencial de un solo uso.

Requisitos: curl, openssl, tar y shasum (macOS) o sha256sum (Linux).
EOF
}

# ─── Argumentos ───────────────────────────────────────────────────────────────
SOLO_VERIFICAR=false
for arg in "$@"; do
  case "$arg" in
    --check) SOLO_VERIFICAR=true ;;
    -h|--help) usage; exit 0 ;;
    *) error "Opción desconocida: $arg"; usage; exit 2 ;;
  esac
done

# ─── Banner ───────────────────────────────────────────────────────────────────
printf '\n%b\n' "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
printf '%b\n'   "${CYAN}${BOLD}║        🚀  Suite Reina · Instalación             ║${NC}"
printf '%b\n'   "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
printf '\n'
info "Se te pedirá tu USUARIO y tu CONTRASEÑA de activación."
info "La credencial es de un solo uso y valida contra Reina Agencia."
printf '\n'

# ─── Detección de plataforma ──────────────────────────────────────────────────
OS_KIND="other"
case "$(uname -s 2>/dev/null || echo unknown)" in
  Darwin) OS_KIND="macos" ;;
  Linux)  OS_KIND="linux" ;;
esac

# ─── Requisitos ───────────────────────────────────────────────────────────────
MISSING=""
for tool in curl openssl tar; do
  command -v "$tool" >/dev/null 2>&1 || MISSING="${MISSING} ${tool}"
done

# shasum (macOS) o sha256sum (Linux)
SHA256_CMD=""
if command -v shasum >/dev/null 2>&1; then
  SHA256_CMD="shasum"
elif command -v sha256sum >/dev/null 2>&1; then
  SHA256_CMD="sha256sum"
else
  MISSING="${MISSING} sha256sum/shasum"
fi

if [ -n "$MISSING" ]; then
  error "Faltan herramientas obligatorias:${MISSING}"
  printf '\n'
  case "$OS_KIND" in
    macos)
      # macOS trae shasum; solo faltarían curl/openssl/tar si el sistema está raro.
      printf '  Instálalas con Homebrew:\n    brew install curl openssl\n'
      printf '  (tar y shasum vienen con macOS; si faltan, reinstala las Command Line Tools: xcode-select --install)\n'
      ;;
    linux)
      printf '  Debian/Ubuntu:\n    sudo apt-get update && sudo apt-get install -y curl openssl tar coreutils\n'
      printf '  Fedora/RHEL:\n    sudo dnf install -y curl openssl tar coreutils\n'
      printf '  Arch:\n    sudo pacman -S --needed curl openssl tar coreutils\n'
      ;;
    *)
      printf '  Instala curl, openssl, tar y sha256sum/shasum con el gestor de paquetes de tu sistema.\n'
      ;;
  esac
  printf '\n'
  exit 1
fi

# Caso Windows sin Git Bash
if [ -n "${WINDIR:-}" ] && ! command -v openssl >/dev/null 2>&1; then
  error "Detectamos Windows y no encontramos 'openssl'."
  printf '%b\n' "  Usa *Git Bash* (viene con Git for Windows) y vuelve a ejecutar el instalador dentro de él,"
  printf '%b\n' "  o instala OpenSSL y añádelo al PATH. No lo ejecutes en CMD/PowerShell plano."
  exit 1
fi

# ─── Utilidades ───────────────────────────────────────────────────────────────
sha256_of() {
  # $1 = ruta del archivo
  if [ "$SHA256_CMD" = "shasum" ]; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

have_tty() {
  # /dev/tty puede existir pero fallar al abrirse si no hay terminal de control.
  { : </dev/tty; } 2>/dev/null
}

# Extrae un campo string de un JSON, sin jq (python3 si existe, si no sed).
json_field() {
  local key="$1" json="$2" out=""
  if command -v python3 >/dev/null 2>&1; then
    out=$(printf '%s' "$json" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
if not isinstance(d, dict):
    d = {}
v = d.get(sys.argv[1], "")
if isinstance(v, bool):
    v = "true" if v else "false"
if v is None:
    v = ""
sys.stdout.write(str(v))
' "$key" 2>/dev/null) || out=""
    if [ -n "$out" ]; then
      printf '%s' "$out"
      return 0
    fi
  fi
  printf '%s' "$json" | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n1
}

# Vuelca la respuesta de activar() como asignaciones de shell seguras (eval).
parse_activation() {
  local json="$1" out=""
  if command -v python3 >/dev/null 2>&1; then
    out=$(printf '%s' "$json" | python3 -c '
import json, sys, shlex
keys = ["ok", "error", "cliente_slug", "cliente_nombre", "version",
        "file_name", "pack_url", "pack_sha256", "pack_key", "algo"]
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
if not isinstance(d, dict):
    d = {}
for k in keys:
    v = d.get(k, "")
    if isinstance(v, bool):
        v = "true" if v else "false"
    if v is None:
        v = ""
    sys.stdout.write("%s=%s\n" % (k, shlex.quote(str(v))))
' 2>/dev/null) || out=""
  fi
  if [ -z "$out" ]; then
    # Fallback sin python3: comillas simples seguras a mano.
    local k v sq
    for k in ok error cliente_slug cliente_nombre version file_name pack_url pack_sha256 pack_key algo; do
      if [ "$k" = "ok" ]; then
        # 'ok' es booleano (sin comillas): json_field no lo captura.
        if printf '%s' "$json" | grep -q '"ok"[[:space:]]*:[[:space:]]*true'; then
          v="true"
        else
          v="false"
        fi
      else
        v="$(json_field "$k" "$json")"
      fi
      sq="'$(printf '%s' "$v" | sed "s/'/'\\\\''/g")'"
      out="${out}${k}=${sq}
"
    done
  fi
  printf '%s' "$out"
}

# ─── Manifest público (solo para leer la versión del pack) ────────────────────
header "Comprobando versión del pack"
MANIFEST_JSON=""
if MANIFEST_JSON=$(curl -fsSL --retry 2 --max-time 20 "$MANIFEST_URL" 2>/dev/null); then
  MV="$(json_field version "$MANIFEST_JSON")"
  if [ -n "$MV" ]; then
    PACK_VERSION="$MV"
    log "Pack disponible: v${PACK_VERSION}"
  else
    warn "No pude leer la versión del manifest; continúo igual."
  fi
else
  warn "No pude consultar el manifest público; continúo y usaré la versión que informe la activación."
fi

# ─── Credenciales (CRÍTICO: leer siempre de /dev/tty) ─────────────────────────
header "Credenciales de activación"
if ! have_tty; then
  error "No hay una terminal interactiva disponible para pedir usuario y contraseña."
  printf '\n'
  printf '%b\n' "  Ejecuta: curl -fsSL ${SELF_URL} -o /tmp/install.sh && bash /tmp/install.sh"
  printf '\n'
  exit 1
fi

USUARIO=""
if ! IFS= read -r -p "Usuario: " USUARIO </dev/tty; then
  error "No se pudo leer el usuario. Abortando."
  exit 1
fi
if [ -z "$USUARIO" ]; then
  error "El usuario no puede estar vacío. Abortando."
  exit 1
fi

CONTRASENA=""
if ! IFS= read -rs -p "Contraseña: " CONTRASENA </dev/tty; then
  error "No se pudo leer la contraseña. Abortando."
  exit 1
fi
printf '\n' >/dev/tty
if [ -z "$CONTRASENA" ]; then
  error "La contraseña no puede estar vacía. Abortando."
  exit 1
fi

# ─── Datos del equipo ─────────────────────────────────────────────────────────
ACT_HOST="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo desconocido)"
ACT_OS="$(uname -sr 2>/dev/null || echo desconocido)"
ACT_IP=""
if [ "$OS_KIND" = "macos" ]; then
  ACT_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
  [ -z "$ACT_IP" ] && ACT_IP="$(ipconfig getifaddr en1 2>/dev/null || true)"
else
  ACT_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
fi

# ─── Activación ───────────────────────────────────────────────────────────────
header "Activando licencia"

# Cuerpo JSON (la contraseña nunca se imprime; se envía por stdin a curl para
# no quedar expuesta en la lista de procesos).
act_esc() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.argv[1]))' "$1"
  else
    printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
  fi
}

ACT_BODY="$(printf '{"p_usuario":%s,"p_password":%s,"p_host":%s,"p_ip":%s,"p_os":%s}' \
  "$(act_esc "$USUARIO")" \
  "$(act_esc "$CONTRASENA")" \
  "$(act_esc "$ACT_HOST")" \
  "$(act_esc "$ACT_IP")" \
  "$(act_esc "$ACT_OS")")"

ACT_RESP=""
if ! ACT_RESP="$(printf '%s' "$ACT_BODY" | curl -sS -f -X POST "${SUPABASE_URL}/rest/v1/rpc/activar" \
      -H "apikey: ${SUPABASE_PUBLISHABLE_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_PUBLISHABLE_KEY}" \
      -H "Content-Type: application/json" \
      --data-binary @- 2>/dev/null)"; then
  # Un error HTTP no debería ocurrir con la RPC; si pasa, informamos sin filtrar nada.
  error "No se pudo contactar al servidor de activación. Revisa tu conexión e intenta de nuevo."
  exit 1
fi

# Inicializamos por si el eval no define algo (set -u).
ok=""; error=""; error_code=""
cliente_slug=""; cliente_nombre=""; version=""
file_name=""; pack_url=""; pack_sha256=""; pack_key=""; algo=""

eval "$(parse_activation "$ACT_RESP")"
error_code="$error"   # 'error' es palabra clave de bash; alias seguro.

if [ "$ok" != "true" ]; then
  case "${error_code:-}" in
    credenciales_invalidas)
      error "Usuario o contraseña incorrectos. Revísalos y vuelve a intentar." ;;
    ya_usada)
      error "Esta credencial ya fue usada. Pide una nueva a Reina Agencia." ;;
    inactiva)
      error "Tu licencia está desactivada. Contacta a Reina Agencia." ;;
    expirada)
      error "Tu licencia expiró. Pide una renovación a Reina Agencia." ;;
    sin_pack)
      error "Todavía no hay un pack disponible para tu licencia. Contacta a Reina Agencia." ;;
    "")
      error "No se pudo activar la licencia (respuesta inesperada del servidor)." ;;
    *)
      error "No se pudo activar la licencia (error: ${error_code}). Contacta a Reina Agencia." ;;
  esac
  exit 1
fi

# La versión que manda la activación manda sobre el manifest.
[ -n "${version:-}" ] && PACK_VERSION="$version"
[ -n "${algo:-}" ] || algo="AES-256-CBC/PBKDF2-sha256/200000"

log "Licencia activada para ${cliente_nombre} (v${PACK_VERSION})."

# Validaciones defensivas: la RPC debe entregar todo lo necesario.
for v in file_name pack_url pack_sha256 pack_key; do
  eval "val=\${$v:-}"
  if [ -z "$val" ]; then
    error "La activación no devolvió '${v}'. Contacta a Reina Agencia."
    exit 1
  fi
done

# ─── Temporal + limpieza SIEMPRE ──────────────────────────────────────────────
TMP="$(mktemp -d "${TMPDIR:-/tmp}/suite-reina.XXXXXX")"
cleanup() {
  local code=$?
  trap - EXIT INT TERM
  if [ -n "${TMP:-}" ] && [ -d "$TMP" ]; then
    rm -rf "$TMP" 2>/dev/null || true
  fi
  # La licencia (suite-license.json) se conserva a propósito.
  exit "$code"
}
trap cleanup EXIT INT TERM

# ─── Descargar pack ───────────────────────────────────────────────────────────
header "Descargando pack"
info "Descargando ${file_name}…"
if ! curl -fL --retry 3 --retry-delay 2 -o "$TMP/$file_name" "$pack_url"; then
  error "No se pudo descargar el pack desde GitHub. Revisa tu conexión e intenta de nuevo."
  exit 1
fi

# ─── Verificar integridad ─────────────────────────────────────────────────────
info "Verificando integridad (sha256)…"
GOT_SHA="$(sha256_of "$TMP/$file_name" 2>/dev/null || echo '')"
if [ -z "$GOT_SHA" ] || [ "$GOT_SHA" != "$pack_sha256" ]; then
  rm -f "$TMP/$file_name" 2>/dev/null || true
  error "La verificación sha256 falló: el archivo no coincide. Descarga abortada."
  exit 1
fi
log "Integridad OK."

# ─── Descifrar ────────────────────────────────────────────────────────────────
header "Descifrando pack"
if ! openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -md sha256 \
      -pass "pass:${pack_key}" \
      -in "$TMP/$file_name" \
      -out "$TMP/pack.tar.gz" 2>/dev/null; then
  error "No se pudo descifrar el pack (clave o archivo inválido). Contacta a Reina Agencia."
  exit 1
fi

mkdir -p "$TMP/pack"
if ! tar -xzf "$TMP/pack.tar.gz" -C "$TMP/pack" 2>/dev/null; then
  error "No se pudo extraer el pack (tar.gz corrupto). Contacta a Reina Agencia."
  exit 1
fi
log "Pack descifrado y extraído."

# ─── Modo --check: diagnóstico sin instalar ───────────────────────────────────
if [ "$SOLO_VERIFICAR" = true ]; then
  KEEP_DIR="${HOME}/.agents/tmp/suite-pack-check-${PACK_VERSION}"
  mkdir -p "$(dirname "$KEEP_DIR")"
  rm -rf "$KEEP_DIR"
  if cp -R "$TMP/pack/." "$KEEP_DIR/" 2>/dev/null; then
    log "Modo --check: pack verificado, descifrado y extraído en ${KEEP_DIR}"
  else
    warn "Modo --check: no se pudo conservar el pack extraído (sí se verificó)."
  fi
  info "No se instaló nada. La credencial de un solo uso quedó consumida."
  exit 0
fi

# ─── Ejecutar instalador interno ──────────────────────────────────────────────
header "Instalando la Suite"
# El instalador puede estar en scripts/ o dentro de una carpeta raíz del tar.
shopt -s nullglob
INTERNOS=("$TMP/pack"/scripts/instalador-*.sh "$TMP/pack"/*/scripts/instalador-*.sh)
shopt -u nullglob

if [ "${#INTERNOS[@]}" -eq 0 ]; then
  error "El pack no contiene un instalador interno (scripts/instalador-*.sh). Contacta a Reina Agencia."
  exit 1
fi
INSTALADOR="${INTERNOS[0]}"
# Raíz del pack = carpeta que contiene scripts/ (para que las rutas relativas funcionen).
PACK_ROOT="$(cd "$(dirname "$INSTALADOR")/.." && pwd)"
info "Ejecutando $(basename "$INSTALADOR")…"

chmod +x "$INSTALADOR" 2>/dev/null || true
# Datos no sensibles para el watermark interno del pack.
export SUITE_CLIENTE_SLUG="${cliente_slug:-}"
export SUITE_CLIENTE_NOMBRE="${cliente_nombre:-}"
export SUITE_PACK_VERSION="${PACK_VERSION:-}"

( cd "$PACK_ROOT" && bash "$INSTALADOR" "$@" )
log "Instalador interno completado."

# ─── Watermark / licencia local ───────────────────────────────────────────────
header "Registrando licencia local"
mkdir -p "$(dirname "$LICENSE_FILE")" 2>/dev/null || true
chmod 700 "$(dirname "$LICENSE_FILE")" 2>/dev/null || true

ACTIVADO_EN="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
json_esc() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.argv[1], ensure_ascii=False)[1:-1])' "$1"
  else
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
  fi
}

if command -v python3 >/dev/null 2>&1; then
  C_SLUG="$cliente_slug" C_NOMBRE="$cliente_nombre" C_USER="$USUARIO" \
  C_VER="$PACK_VERSION" C_AT="$ACTIVADO_EN" C_HOST="$ACT_HOST" C_IP="$ACT_IP" \
  python3 -c '
import json, os
obj = {
    "cliente_slug": os.environ.get("C_SLUG", ""),
    "cliente_nombre": os.environ.get("C_NOMBRE", ""),
    "usuario": os.environ.get("C_USER", ""),
    "version": os.environ.get("C_VER", ""),
    "activado_en": os.environ.get("C_AT", ""),
    "host": os.environ.get("C_HOST", ""),
    "ip": os.environ.get("C_IP", ""),
}
print(json.dumps(obj, ensure_ascii=False, indent=2))
' > "$LICENSE_FILE"
else
  {
    printf '{\n'
    printf '  "cliente_slug": "%s",\n'   "$(json_esc "$cliente_slug")"
    printf '  "cliente_nombre": "%s",\n' "$(json_esc "$cliente_nombre")"
    printf '  "usuario": "%s",\n'        "$(json_esc "$USUARIO")"
    printf '  "version": "%s",\n'        "$(json_esc "$PACK_VERSION")"
    printf '  "activado_en": "%s",\n'    "$(json_esc "$ACTIVADO_EN")"
    printf '  "host": "%s",\n'           "$(json_esc "$ACT_HOST")"
    printf '  "ip": "%s"\n'              "$(json_esc "$ACT_IP")"
    printf '}\n'
  } > "$LICENSE_FILE"
fi
chmod 600 "$LICENSE_FILE" 2>/dev/null || true
log "Licencia guardada en ${LICENSE_FILE}"

# ─── Resumen final ────────────────────────────────────────────────────────────
printf '\n'
printf '%b\n' "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
printf '%b\n' "${GREEN}${BOLD}║        ✅  Instalación completada                 ║${NC}"
printf '%b\n' "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
printf '\n'
printf '  Cliente : %s\n' "${cliente_nombre:-$cliente_slug}"
printf '  Versión : %s\n' "$PACK_VERSION"
printf '\n'
printf '%b\n' "  ${YELLOW}Recordatorio:${NC} si opencode abre pero no responde → ${BOLD}/connect${NC} → ${BOLD}OpenCode Go${NC}."
printf '\n'
exit 0
