# API helpers for Homebrew's Bash scripts.

# HOMEBREW_API_DEFAULT_DOMAIN HOMEBREW_API_DOMAIN are set by brew.sh
# shellcheck disable=SC2154
api_urls() {
  local filename="$1"

  if [[ -n "${HOMEBREW_API_DOMAIN:-}" && "${HOMEBREW_API_DOMAIN}" != "${HOMEBREW_API_DEFAULT_DOMAIN}" ]]
  then
    echo "${HOMEBREW_API_DOMAIN}/${filename}"
  fi
  echo "${HOMEBREW_API_DEFAULT_DOMAIN}/${filename}"
}

# Keep conditional requests in sync with Homebrew::API.fetch_json_api_file in api.rb.
# Sets fetch_api_file's local conditional_args array without splitting paths.
# shellcheck disable=SC2034
api_conditional_args() {
  local cache_path="$1"
  local etag_path="$2"
  local json_url="$3"

  if [[ -s "${cache_path}" ]]
  then
    if [[ -n "${etag_path}" ]]
    then
      if [[ -s "${etag_path}" && -f "${etag_path}.url" && "$(<"${etag_path}.url")" == "${json_url}" ]]
      then
        conditional_args=(--etag-compare "${etag_path}")
      fi
    else
      conditional_args=(--time-cond "${cache_path}")
    fi
  fi
}
