# Suite Reina — Instalador

Bootstrap de instalación de la **Suite Reina** (agentes + skills para opencode) en un solo comando.

## Instalación

```bash
curl -fsSL https://raw.githubusercontent.com/reinaagencia/installer/main/install.sh -o /tmp/instalar-suite.sh && bash /tmp/instalar-suite.sh
```

El instalador pedirá **USUARIO** y **CONTRASEÑA de activación** (de un solo uso, emitidos por Reina Agencia).

Qué hace, en orden:

1. Verifica requisitos (`curl`, `openssl`, `tar`, `shasum`/`sha256sum`).
2. Valida la credencial contra Reina Agencia (licencia de **un solo uso**).
3. Descarga el pack **cifrado** y verifica su **sha256**.
4. Lo descifra (AES-256-CBC / PBKDF2-sha256) y lo extrae.
5. Ejecuta el instalador interno de la Suite.
6. Registra la licencia en `~/.agents/suite-license.json` y borra los temporales.

## Diagnóstico

```bash
bash /tmp/instalar-suite.sh --check
```

Verifica y descarga el pack (activación + sha256 + descifrado + extracción) **sin instalar nada**.
Deja el pack extraído en `~/.agents/tmp/`. Ojo: consume la credencial de un solo uso.

## Si opencode abre pero no responde

La autenticación con las API keys nuevas (`oc_sk_…`) se resuelve **conectando la cuenta**, no solo escribiendo `auth.json`:

1. Abre `opencode`.
2. Escribe `/connect`.
3. Elige **OpenCode Go**.
4. Pega la API key y selecciona el modelo `opencode-go/deepseek-v4.1-flash`.

## Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| "Esta credencial ya fue usada" | La licencia es de un solo uso | Pide una nueva a Reina Agencia |
| "La verificación sha256 falló" | Descarga incompleta/proxy | Reintenta; si persiste, avisa a Reina Agencia |
| "No se pudo descifrar el pack" | Clave inválida | Contacta a Reina Agencia |
| "No hay una terminal interactiva" | Se ejecutó con pipe | Usa el comando con `-o /tmp/... && bash /tmp/...` |
| opencode no responde | Falta `/connect` | Ver sección anterior |

---

Reina Agencia · El pack se descarga cifrado: nunca se envía por correo.
