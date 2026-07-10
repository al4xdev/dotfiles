#!/usr/bin/env -S fish --no-config
#
# Unit tests for this dotfiles repository.
#
# Sources the repo files directly and asserts every behavior we care about:
# config.fish loads cleanly, aliases expand as expected, the gen launcher
# works, completions are registered, the deprecated archive function is
# callable, and helper scripts have valid syntax + no path regressions.
#
# Runs under `fish --no-config` (via env -S) so results are not contaminated
# by whatever is currently autoloaded from the user's shell.
#
# Usage:
#   ./.config/my_scripts/test_dotfiles.fish
#   # or, if env -S is unavailable:
#   fish --no-config .config/my_scripts/test_dotfiles.fish
#
# Exits 0 if all tests pass, 1 otherwise.

set -l repo_root (realpath (dirname (status filename))/../..)
set -l fish_dir $repo_root/.config/fish
set -l scripts_dir $repo_root/.config/my_scripts

set -g _pass 0
set -g _fail 0

function _ok
    set -g _pass (math $_pass + 1)
    echo "  ok   $argv"
end

function _bad
    set -g _fail (math $_fail + 1)
    echo "  FAIL $argv"
end

function _assert_contains
    set -l label $argv[1]
    set -l needle $argv[2]
    set -l haystack $argv[3]
    if string match -q "*$needle*" -- $haystack
        _ok $label
    else
        _bad "$label (missing '$needle')"
    end
end

function _assert_status
    set -l label $argv[1]
    set -l want $argv[2]
    set -l got $argv[3]
    if test "$want" = "$got"
        _ok $label
    else
        _bad "$label (want exit $want, got $got)"
    end
end

# ---------------------------------------------------------------------------
echo "=== config.fish ==="

set -l cfg_errors (source $fish_dir/config.fish 2>&1 >/dev/null | string collect)
if test -z "$cfg_errors"
    _ok "config.fish sources without errors"
else
    _bad "config.fish emitted errors:"
    echo $cfg_errors
end

_assert_contains "ls alias uses eza with expected flags" \
    "eza -al --color=always --group-directories-first --icons" \
    (functions ls | string collect)

_assert_contains "la alias uses eza" "eza -a --color=always" \
    (functions la | string collect)
_assert_contains "ll alias uses eza" "eza -l --color=always" \
    (functions ll | string collect)
_assert_contains "lt alias uses eza" "eza -aT --color=always" \
    (functions lt | string collect)
_assert_contains "l. alias uses eza" "eza -ald --color=always" \
    (functions l. | string collect)

if set -q eza_opts
    _bad "eza_opts leaked into shell scope: $eza_opts"
else
    _ok "eza_opts is local to config.fish"
end

if functions -q grubup
    _bad "grubup alias should have been removed"
else
    _ok "grubup alias is not defined"
end

# Trailing-space regression: the wrapper body must not have a double
# space between the command tail and \$argv.
set -l wget_body (functions wget | string collect)
if string match -qr 'wget -c {2,}\$argv' -- $wget_body
    _bad "wget alias still has trailing space"
else
    _ok "wget alias has no trailing space"
end

# ---------------------------------------------------------------------------
echo ""
echo "=== gen launcher ==="

source $fish_dir/functions/gen.fish
source $fish_dir/completions/gen.fish

set -l help_out (gen --help 2>&1 | string collect)
_assert_contains "gen --help prints usage" "Usage: gen" $help_out
_assert_contains "gen --help lists image method" image $help_out
_assert_contains "gen --help lists video method" video $help_out

set -l noarg_out (gen 2>&1 | string collect)
_assert_contains "gen with no args prints usage" "Usage: gen" $noarg_out

gen foobar >/dev/null 2>&1
_assert_status "gen <unknown> returns exit 1" 1 $status

set -l completions (complete --do-complete='gen ' | string collect)
_assert_contains "completions register 'image'" image $completions
_assert_contains "completions register 'video'" video $completions
_assert_contains "completion description for image" "image generation" $completions
_assert_contains "completion description for video" "video generation" $completions

# ---------------------------------------------------------------------------
echo ""
echo "=== deprecated archive ==="

source $fish_dir/functions/deprecated.fish
if functions -q deprecated
    _ok "deprecated function loaded"
else
    _bad "deprecated function not found"
end
_assert_contains "deprecated prints commit prefix summary" "commit prefixes" \
    (deprecated 2>&1 | string collect)

# ---------------------------------------------------------------------------
echo ""
echo "=== deepcode functions & abbreviations ==="

# 1. Test deepcode abbreviations expansion
set -l abbr_show (abbr --show | string collect)
for abb in gmmax gmno gmmed gmlow gmun
    if abbr -q $abb
        _ok "abbreviation $abb is defined"
    else
        _bad "abbreviation $abb is NOT defined"
    end
end

_assert_contains "gmmax uses llama-server" "llama-server" "$abbr_show"
_assert_contains "gmmax has temperature top_p top_k samplers" "temperature;top_p;top_k" "$abbr_show"
_assert_contains "gmno has reasoning off" "--reasoning off" "$abbr_show"
_assert_contains "gmmed has mmproj GGUF" "mmproj-F16.gguf" "$abbr_show"
_assert_contains "gmlow has reasoning off and fit-ctx 4096" "--fit-ctx 4096" "$abbr_show"
_assert_contains "gmun has uncensored fast v2 Q4_K_M GGUF" "supergemma4-26b-uncensored-fast-v2-Q4_K_M.gguf" "$abbr_show"

# Mock deepcode function to check what it was called with and the env variables
function deepcode
    set -g _deepcode_called 1
    set -g _deepcode_argv $argv
    set -g _deepcode_model $DEEPCODE_MODEL
    set -g _deepcode_base_url $DEEPCODE_BASE_URL
    set -g _deepcode_api_key $DEEPCODE_API_KEY
end

# 2. Test deepcode-cloud
source $fish_dir/functions/deepcode-cloud.fish
if functions -q deepcode-cloud
    _ok "deepcode-cloud function loaded"
else
    _bad "deepcode-cloud function not found"
end

set -g _deepcode_called 0
set -g _deepcode_argv
set -e DEEPCODE_MODEL
set -e DEEPCODE_BASE_URL
set -e DEEPCODE_API_KEY

deepcode-cloud cloud_arg1 cloud_arg2

_assert_status "deepcode-cloud runs deepcode mock" 1 "$_deepcode_called"
_assert_status "deepcode-cloud passes args" "cloud_arg1 cloud_arg2" "$_deepcode_argv"
_assert_status "deepcode-cloud sets DEEPCODE_MODEL" "deepseek-v4-pro" "$_deepcode_model"
_assert_status "deepcode-cloud sets DEEPCODE_BASE_URL" "https://api.deepseek.com" "$_deepcode_base_url"

# 3. Test deepcode-local
source $fish_dir/functions/deepcode-local.fish
if functions -q deepcode-local
    _ok "deepcode-local function loaded"
else
    _bad "deepcode-local function not found"
end

set -g _deepcode_called 0
set -g _deepcode_argv
set -e DEEPCODE_MODEL
set -e DEEPCODE_BASE_URL
set -e DEEPCODE_API_KEY

deepcode-local local_arg1

_assert_status "deepcode-local runs deepcode mock" 1 "$_deepcode_called"
_assert_status "deepcode-local passes args" "local_arg1" "$_deepcode_argv"
_assert_status "deepcode-local sets DEEPCODE_MODEL" "unsloth/Qwen-AgentWorld-35B-A3B-GGUF" "$_deepcode_model"
_assert_status "deepcode-local sets DEEPCODE_BASE_URL" "http://localhost:8888/v1" "$_deepcode_base_url"
_assert_status "deepcode-local sets DEEPCODE_API_KEY" "sk-unsloth-828bbc10b07eb9f75f6d9d645bdd5d94" "$_deepcode_api_key"

# Clean up mock
functions -e deepcode
set -e _deepcode_called
set -e _deepcode_argv
set -e _deepcode_model
set -e _deepcode_base_url
set -e _deepcode_api_key

# ---------------------------------------------------------------------------
echo ""
echo "=== my_scripts ==="

for script in $scripts_dir/start.sh $scripts_dir/start_video.sh
    set -l name (basename $script)
    if bash -n $script 2>/dev/null
        _ok "syntax ok: $name"
    else
        _bad "syntax error in $name"
    end

    if grep -q '/home/alex/' $script
        _bad "$name still contains stale /home/alex path"
    else
        _ok "$name has no stale /home/alex path"
    end
end

# Specific regression: start_video.sh used to invoke `python home/alex/...`
# (missing leading slash) — make sure that exact bug never returns.
if grep -qE '^\s*python\s+home/' $scripts_dir/start_video.sh
    _bad "start_video.sh has the 'python home/...' typo regression"
else
    _ok "start_video.sh uses an absolute python path"
end

# ---------------------------------------------------------------------------
echo ""
echo "=== summary ==="
echo "  passed: $_pass"
echo "  failed: $_fail"

if test $_fail -gt 0
    exit 1
end
