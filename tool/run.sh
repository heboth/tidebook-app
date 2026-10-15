#!/usr/bin/env bash
# ==============================================================================
# Kør/byg appen med adresserne fra den fælles miljøfil for Tide-suiten.
#
#   tool/run.sh                    = flutter run
#   tool/run.sh run -d iPhone      = flutter run -d iPhone
#   tool/run.sh build ios          = flutter build ios
#
# Læser KUN TIDE_CORE_URL, TIDE_CMS_URL og TIDE_BOOKING_WEB_URL fra ../.env (eller TIDE_ENV_FILE) og giver dem
# videre som --dart-define=TIDEBOOK_API_URL / TIDECMS_URL / TIDEBOOK_SITE_URL. Brug aldrig --dart-define-from-file med den fælles fil:
# alt i den (også hemmeligheder) ville blive bygget ind i appen.
# Allerede satte TIDEBOOK_API_URL / TIDECMS_URL i miljøet vinder. localhost-adresser gives videre som "local"
# (localhost på iOS, 10.0.2.2 på Android-emulatoren). Uden fælles fil bruger appen Tide-suiten online.
# ==============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
ENV_FILE="${TIDE_ENV_FILE:-$(dirname "$(pwd)")/.env}"

# Én nøgle fra filen (sidste forekomst), uden at indlæse resten
read_key() {
  [[ -f "$ENV_FILE" ]] || return 0
  sed -nE "s/^[[:space:]]*(export[[:space:]]+)?$1=(.*)$/\2/p" "$ENV_FILE" | tail -n 1 | sed -E "s/^['\"](.*)['\"]$/\1/"
}

api="${TIDEBOOK_API_URL:-$(read_key TIDE_CORE_URL)}"
cms="${TIDECMS_URL:-$(read_key TIDE_CMS_URL)}"
site="${TIDEBOOK_SITE_URL:-$(read_key TIDE_BOOKING_WEB_URL)}"

defines=()
is_local() { [[ "$1" =~ ^https?://(localhost|127\.0\.0\.1)(:|/|$) ]]; }
# Uden adresse bruger appen Tide-suiten online (tidebook.ceniconsulting.dk). localhost-adresser bliver til "local",
# så appen selv vælger localhost (iOS) eller 10.0.2.2 (Android-emulatoren).
if [[ -n "$api" ]]; then if is_local "$api"; then defines+=("--dart-define=TIDEBOOK_API_URL=local"); else defines+=("--dart-define=TIDEBOOK_API_URL=$api"); fi; fi
if [[ -n "$cms" ]]; then if is_local "$cms"; then defines+=("--dart-define=TIDECMS_URL=local"); else defines+=("--dart-define=TIDECMS_URL=$cms"); fi; fi
if [[ -n "$site" ]]; then if is_local "$site"; then defines+=("--dart-define=TIDEBOOK_SITE_URL=local"); else defines+=("--dart-define=TIDEBOOK_SITE_URL=$site"); fi; fi

[[ $# -gt 0 ]] || set -- run
echo "flutter $* ${defines[*]:-}"
exec flutter "$@" ${defines[@]+"${defines[@]}"}
