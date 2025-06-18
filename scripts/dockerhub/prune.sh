#!/usr/bin/env bash

##
# This script deletes all tags older than 90 days from a given Docker Hub
# repository. It cannot delete untagged images as there does not appear to be a
# way to find or delete them yet.
#
# Only Linux & macOS are supported by this script.
#
# Required dependencies
# * GNU date
# * jq
#
# Authentication
#   If your organization has SSO enforced or your account has MFA enabled,
#   you must use a personal access token (PAT) instead of a password.
#
#   Environment variables:
#     DOCKER_LOGIN
#       The identifier of the account to create an access token for. If using a
#       password or personal access token, this must be a username. If using an
#       organization access token, this must be an organization name.
#     DOCKER_PASSWORD
#       The secret of the account to create an access token for. This can be a
#       password, personal access token, or organization access token.
##

set -euo pipefail

#################################################################################
# Platform detection
#################################################################################

DETECTED_OS="$(uname -s)"
readonly DETECTED_OS

OS="${OS:-${DETECTED_OS}}"
readonly OS

if [[ "${OS}" != "Darwin" && "${OS}" != "Linux" ]]; then
    echo "Unsupported platform: ${OS}" >&2
    echo "This script only supports Darwin & Linux" >&2
    exit 1
fi

#################################################################################
# Dependency variables
#################################################################################

if [[ "${OS}" == "Darwin" ]]; then
    DATE_CMD="gdate"
elif [[ "${OS}" == "Linux" ]]; then
    DATE_CMD="date"
fi

readonly DATE_CMD

DATE="${DATE:-$(which "${DATE_CMD}" || true)}"
JQ="${JQ:-$(which jq || true)}"

readonly DATE
readonly JQ

#################################################################################
# Colour variables
#################################################################################

NC="$(tput -Txterm sgr0)"
BLACK="$(tput -Txterm setaf 0)"
RED="$(tput -Txterm setaf 1)"
GREEN="$(tput -Txterm setaf 2)"
YELLOW="$(tput -Txterm setaf 3)"
BLUE="$(tput -Txterm setaf 4)"
MAGENTA="$(tput -Txterm setaf 5)"
CYAN="$(tput -Txterm setaf 6)"
WHITE="$(tput -Txterm setaf 7)"

readonly NC
readonly BLACK
readonly RED
readonly GREEN
readonly YELLOW
readonly BLUE
readonly MAGENTA
readonly CYAN
readonly WHITE

#################################################################################
# Authentication variables
#################################################################################

DOCKER_LOGIN="${DOCKER_LOGIN:-}"
DOCKER_PASSWORD="${DOCKER_PASSWORD:-}"

readonly DOCKER_LOGIN
readonly DOCKER_PASSWORD

#################################################################################
# API URL variables
#################################################################################

API_BASE_URL="https://hub.docker.com/v2"
API_AUTH_TOKEN_URL="${API_BASE_URL}/auth/token"
API_REPOSITORIES_URL="${API_BASE_URL}/repositories"

readonly API_BASE_URL
readonly API_AUTH_TOKEN_URL
readonly API_REPOSITORIES_URL

#################################################################################
# API URL template variables
#################################################################################

API_NAMESPACE_TMPL="${API_REPOSITORIES_URL}/%s"
API_REPOSITORY_TMPL="${API_NAMESPACE_TMPL}/%s"
API_TAGS_TMPL="${API_REPOSITORY_TMPL}/tags"
API_TAG_TMPL="${API_TAGS_TMPL}/%s"

readonly API_NAMESPACE_TMPL
readonly API_REPOSITORY_TMPL
readonly API_TAGS_TMPL
readonly API_TAG_TMPL

#################################################################################
# Dependency functions
#################################################################################

function check_dependency() {
    local name
    local var

    readonly name="$1"
    readonly var="$2"

    if [[ "${var}" == "" ]]; then
        echo "Error: Could not find dependency: ${name}" >&2
        exit 1
    fi
}

#################################################################################
# API functions
#################################################################################

# Unauthenticated POST
function curl_post() {
    local post_data
    local url
    local accept_header

    readonly post_data="$1"
    readonly url="$2"
    readonly accept_header="Content-Type: application/json"

    curl -s -X POST -H "${accept_header}" -d "${post_data}" "${url}"
}

# Authenticated GET
function curl_auth_get() {
    local access_token
    local url
    local accept_header
    local auth_header

    readonly access_token="$1"
    readonly url="$2"
    readonly accept_header="Content-Type: application/json"
    readonly auth_header="Authorization: JWT ${access_token}"

    curl -s \
        --retry 5 \
        --retry-max-time 120 \
        -H "${auth_header}" \
        -H "${accept_header}" \
        "${url}"
}

# Authenticated DELETE
function curl_auth_delete() {
    local access_token
    local url
    local accept_header
    local auth_header

    readonly access_token="$1"
    readonly url="$2"
    readonly accept_header="Content-Type: application/json"
    readonly auth_header="Authorization: JWT ${access_token}"

    curl -s \
        --retry 5 \
        --retry-max-time 120 \
        -X DELETE \
        -H "${auth_header}" \
        -H "${accept_header}" \
        "${url}"
}

function get_access_token() {
    local identifier
    local secret

    readonly identifier="${1}"
    readonly secret="${2}"

    # Structure post data
    local post_data
    printf -v post_data \
        '{"identifier":"%s","secret":"%s"}' \
        "${identifier}" \
        "${secret}"
    readonly post_data

    # Fetch an access token
    local resp
    resp="$(curl_post "${post_data}" "${API_AUTH_TOKEN_URL}")"
    readonly resp

    local access_token
    access_token="$(echo "$resp" | ${JQ} -rf jq/dockerhub/auth/access-token.jq)"
    readonly access_token

    if [[ "${access_token}" == "" ]]; then
        echo "Error: Could not fetch access token: ${resp}" >&2
        exit 1
    fi

    echo "${access_token}"
}

function prune_tag_handler() {
    local access_token
    local namespace
    local repository
    local result

    readonly access_token="$1"
    readonly namespace="$2"
    readonly repository="$3"
    readonly result="$4"

    local name
    name="$(echo "$result" | ${JQ} -rf jq/dockerhub/tags/name.jq)"
    readonly name

    local updated
    updated="$(echo "$result" | ${JQ} -rf jq/dockerhub/tags/last-updated.jq)"
    readonly updated

    local updated_ts
    updated_ts=$(${DATE} --date "$updated" +"%s")
    readonly updated_ts

    local threshold
    readonly threshold="5 days ago"

    local threshold_ts
    threshold_ts=$(${DATE} --date "${threshold}" +"%s")
    readonly threshold_ts

    # Tag is newer than threshold
    if [[ $updated_ts -gt $threshold_ts ]]; then
        return
    fi

    echo "${YELLOW}Last updated more than ${threshold}${NC}: ${name}"

    local url
    printf -v url "${API_TAG_TMPL}" "${namespace}" "${repository}" "${name}"
    readonly url

    curl_auth_delete "${access_token}" "${url}" >&2
}

function prune_tags() {
    local access_token
    local namespace
    local repository

    readonly access_token="$1"
    readonly namespace="$2"
    readonly repository="$3"

    local url
    printf -v url "${API_TAGS_TMPL}?page_size=25" "${namespace}" "${repository}"
    readonly url

    local resp
    local results
    local next_url="${url}"

    while [[ "${next_url}" != "null" ]]; do
        resp="$(curl_auth_get "${access_token}" "${next_url}")"
        next_url="$(echo "$resp" | ${JQ} -rf jq/pagination/next.jq)"
        results="$(echo "$resp" | ${JQ} -crf jq/dockerhub/tags/results.jq)"

        if [[ "${results}" == "" ]]; then
            return
        fi

        for result in ${results}; do
            prune_tag_handler "${access_token}" "${namespace}" "${repository}" "${result}"
        done
    done
}

#################################################################################
# Script start
#################################################################################

# Check that dependencies are available
check_dependency "${DATE_CMD}" "${DATE}"
check_dependency "jq" "${JQ}"

# Check required environment variables
if [[ "${DOCKER_LOGIN}" == "" ]]; then
    echo "Error: DOCKER_LOGIN cannot be empty."
    exit 1
fi
if [[ "${DOCKER_PASSWORD}" == "" ]]; then
    echo "Error: DOCKER_PASSWORD cannot be empty."
    exit 1
fi

# Get an access token
ACCESS_TOKEN="$(get_access_token "${DOCKER_LOGIN}" "${DOCKER_PASSWORD}")"
readonly ACCESS_TOKEN

# Get the list of images for the repository
NAMESPACE="sumologic"
REPO="sumologic-otel-collector-ci-builds"
prune_tags "${ACCESS_TOKEN}" "${NAMESPACE}" "${REPO}"

exit 1
