#!/usr/bin/env bash
set -euo pipefail

IN="${1:-}"
OUT="${2:-}"

if [[ -z "${IN}" ]]; then
  echo "Usage: md2pdf input.md [output.pdf]" >&2
  exit 1
fi

if [[ ! -f "${IN}" ]]; then
  echo "File not found: ${IN}" >&2
  exit 1
fi

if [[ -z "${OUT}" ]]; then
  base="$(basename "${IN}")"
  OUT="/work/${base%.*}.pdf"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

yaml_tmp="${tmp}/frontmatter.yml"
clean_md="${tmp}/clean.md"
rendered_md="${tmp}/rendered.md"
style_css="${tmp}/style.css"
index_html="${tmp}/index.html"
tmp_pdf="${tmp}/out.pdf"

# -----------------------------
# Extract YAML front matter
# -----------------------------
awk '
  function is_blank(s){ return s ~ /^[[:space:]]*$/ }
  function is_delim(s){ return s ~ /^[[:space:]]*---[[:space:]]*$/ }

  BEGIN { started=0; in_fm=0 }

  started==0 {
    if (is_blank($0)) next
    started=1
    if (is_delim($0)) { in_fm=1; next }
    exit
  }

  in_fm==1 {
    if (is_delim($0)) exit
    print
  }
' "${IN}" > "${yaml_tmp}" || true

yaml_get() {
  local key="$1"
  awk -v k="$key" '
    BEGIN { FS=":" }
    $1 ~ "^[[:space:]]*"k"[[:space:]]*$" {
      $1=""
      sub(/^:/, "", $0)
      gsub(/\r$/, "", $0)  # <-- add this
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      gsub(/^'\''|'\''$/, "", $0)
      gsub(/^"|"$/, "", $0)
      print
      exit
    }
  ' "${yaml_tmp}"
}

escape() { printf '%s' "$1" | sed 's/[\/&|\\]/\\&/g'; }

# -----------------------------
# Read YAML fields
# -----------------------------
TYPE="$(yaml_get type)"
NAME="$(yaml_get name)"
EMAIL="$(yaml_get email)"
PHONE="$(yaml_get phone)"
LOCATION="$(yaml_get location)"
COMPANY="$(yaml_get company)"
HR_MANAGER="$(yaml_get hr_manager)"
POSITION="$(yaml_get position)"
DATE_VAL="$(yaml_get date)"
SIGNATURE="$(yaml_get signature)"

[[ -z "${TYPE}" ]] && TYPE="resume"
[[ -z "${NAME}" ]] && NAME="Resume"

if [[ "${DATE_VAL}" == "auto" || ( "${TYPE}" == "cover" && -z "${DATE_VAL}" ) ]]; then
  DATE_VAL="$(date +"%B %-d, %Y")"
fi

CONTACT=""
parts=()
[[ -n "${EMAIL}" ]] && parts+=("${EMAIL}")
[[ -n "${PHONE}" ]] && parts+=("${PHONE}")
[[ -n "${LOCATION}"  ]] && parts+=("${LOCATION}")
if (( ${#parts[@]} > 0 )); then
  CONTACT="$(printf '%s • ' "${parts[@]}" | sed 's/ • $//')"
fi

# -----------------------------
# Remove YAML and optional H1
# -----------------------------
awk '
  function is_blank(s){ return s ~ /^[[:space:]]*$/ }
  function is_delim(s){ return s ~ /^[[:space:]]*---[[:space:]]*$/ }

  BEGIN { started=0; in_fm=0; h1_stripped=0 }

  {
    sub(/\r$/, "", $0)            # handle CRLF
    gsub(/^\xef\xbb\xbf/, "", $0) # strip UTF-8 BOM if present

    if (started==0) {
      if (is_blank($0)) next
      started=1
      if (is_delim($0)) { in_fm=1; next }
    }

    if (in_fm==1) {
      if (is_delim($0)) { in_fm=0; next }
      next
    }

    if (h1_stripped==0) {
      if (is_blank($0)) next
      if ($0 ~ /^[[:space:]]*#[[:space:]]+/) { h1_stripped=1; next }
      h1_stripped=1
    }

    print
  }
' "${IN}" > "${clean_md}"

# -----------------------------
# Replace tokens
# -----------------------------
sed \
-e "s|{{name}}|$(escape "${NAME}")|g" \
-e "s|{{email}}|$(escape "${EMAIL}")|g" \
-e "s|{{phone}}|$(escape "${PHONE}")|g" \
-e "s|{{location}}|$(escape "${LOCATION}")|g" \
-e "s|{{contact}}|$(escape "${CONTACT}")|g" \
-e "s|{{company}}|$(escape "${COMPANY}")|g" \
-e "s|{{hr_manager}}|$(escape "${HR_MANAGER}")|g" \
-e "s|{{position}}|$(escape "${POSITION}")|g" \
-e "s|{{date}}|$(escape "${DATE_VAL}")|g" \
-e "s|{{signature}}|$(escape "${SIGNATURE}")|g" \
"${clean_md}" > "${rendered_md}"

# -----------------------------
# CSS
# -----------------------------
if [[ -f "/work/style.css" ]]; then
  cp "/work/style.css" "${style_css}"
else
  cat > "${style_css}" <<'CSS'
@page { margin: 0.75in; }
body { font-family: "Inter", "Noto Sans", sans-serif; font-size: 11.5pt; line-height: 1.45; }

.resume-header { display:flex; justify-content:space-between; margin-bottom:1em; }
.resume-header .name { font-size:18pt; font-weight:700; }
.resume-header .contact { font-size:10pt; }

.cover-header { margin-bottom:1.5em; }
.cover-header .name { font-size:14pt; font-weight:700; }
.cover-header .meta div { line-height:1.35; }

p { margin:0.4em 0; }
CSS
fi

# -----------------------------
# HTML template
# -----------------------------
if [[ "${TYPE}" == "cover" ]]; then
  {
    echo '<!doctype html>'
    echo '<html>'
    echo '<head>'
    echo '<meta charset="utf-8">'
    echo "<title>Cover Letter - ${NAME}</title>"
    echo '<link rel="stylesheet" href="style.css">'
    echo '</head>'
    echo '<body class="cover">'
    echo '<div class="cover-sender">'
    echo "  <div>${NAME}</div>"
    echo "  <div>${EMAIL}</div>"
    echo "  <div>${PHONE}</div>"
    echo "  <div>${LOCATION}</div>"
    echo '</div>'
    echo '<div class="cover-date">'
    echo "    <div>${DATE_VAL}</div>"
    echo '</div>'
    echo '<div class="cover-recipient">'
    echo "  <div>${HR_MANAGER}</div>"
    echo "  <div>${COMPANY}</div>"
    echo '</div>'
    echo '<div class="content">'
    echo '  {{ toHTML "rendered.md" }}'
    echo '</div>'
    echo '</body>'
    echo '</html>'
  } > "${index_html}"
else
  {
    echo '<!doctype html>'
    echo '<html>'
    echo '<head>'
    echo '<meta charset="utf-8">'
    echo "<title>Resume - ${NAME}</title>"
    echo '<link rel="stylesheet" href="style.css">'
    echo '</head>'
    echo '<body class="resume">'
    echo '<div class="resume-header">'
    echo "  <div class=\"name\">${NAME}</div>"
    echo "  <div class=\"contact\">${CONTACT}</div>"
    echo '</div>'
    echo '<div class="content">'
    echo '  {{ toHTML "rendered.md" }}'
    echo '</div>'
    echo '</body>'
    echo '</html>'
  } > "${index_html}"
fi

# -----------------------------
# Build curl args
# -----------------------------
curl_files=(
  -F "files=@${index_html};filename=index.html"
  -F "files=@${rendered_md};filename=rendered.md"
  -F "files=@${style_css};filename=style.css"
)

if [[ -n "${SIGNATURE}" ]]; then
  if [[ -f "${SIGNATURE}" ]]; then
    curl_files+=( -F "files=@${SIGNATURE};filename=$(basename "${SIGNATURE}")" )
  fi
fi

# -----------------------------
# Start Gotenberg
# -----------------------------
gotenberg >/tmp/gotenberg.log 2>&1 &
pid=$!

for _ in {1..60}; do
  curl -fsS http://127.0.0.1:3000/health >/dev/null 2>/dev/null && break
  sleep 0.2
done

if ! curl -fsS http://127.0.0.1:3000/health >/dev/null 2>/dev/null; then
  echo "Gotenberg failed to start"
  tail -n 200 /tmp/gotenberg.log
  exit 1
fi

# -----------------------------
# Convert
# -----------------------------
http_code=$(curl -sS -o "${tmp_pdf}" -w "%{http_code}" \
  -X POST http://127.0.0.1:3000/forms/chromium/convert/markdown \
"${curl_files[@]}")

if [[ "${http_code}" != "200" ]]; then
  echo "ERROR: Gotenberg returned HTTP ${http_code}"
  tail -n 200 /tmp/gotenberg.log
  exit 1
fi

mkdir -p "$(dirname "${OUT}")"
mv -f "${tmp_pdf}" "${OUT}"

kill "${pid}" >/dev/null 2>&1 || true
echo "PDF written to ${OUT}"
