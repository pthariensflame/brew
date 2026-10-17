# API helpers for Homebrew's Bash scripts.

# HOMEBREW_API_DEFAULT_DOMAIN HOMEBREW_API_DOMAIN HOMEBREW_CURLRC are set by brew.sh
# shellcheck disable=SC2154
api_urls() {
  local filename="$1"

  if [[ -n "${HOMEBREW_API_DOMAIN:-}" && "${HOMEBREW_API_DOMAIN}" != "${HOMEBREW_API_DEFAULT_DOMAIN}" ]]
  then
    echo "${HOMEBREW_API_DOMAIN}/${filename}"
  fi
  echo "${HOMEBREW_API_DEFAULT_DOMAIN}/${filename}"
}

api_curlrc_args() {
  # HOMEBREW_CURLRC is optionally defined in the user environment.
  if [[ -z "${HOMEBREW_CURLRC:-}" ]]
  then
    echo "-q"
  elif [[ "${HOMEBREW_CURLRC}" == /* ]]
  then
    echo "-q"
    echo "--config"
    echo "${HOMEBREW_CURLRC}"
  fi
}

# Keep conditional requests in sync with Homebrew::API.fetch_json_api_file in api.rb.
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
        echo "--etag-compare"
        echo "${etag_path}"
      fi
    else
      echo "--time-cond"
      echo "${cache_path}"
    fi
  fi
}
