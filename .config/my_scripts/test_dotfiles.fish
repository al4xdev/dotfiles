#!/usr/bin/env -S fish --no-config
#
# Unit tests for this dotfiles repository.
#
# Sources the repo files directly and asserts every behavior we care about:
# config.fish loads cleanly, aliases expand as expected, the gen launcher
# works, completions are registered, wrappers (agy/claude) wire the grammar-editor,
# kitty.conf maps page scroll keys, and helper scripts have valid syntax + no path regressions.
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

# Source config.fish directly into this shell context
source $fish_dir/config.fish >/dev/null 2>&1

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
echo "=== agy & claude wrappers ==="

for wrapper in agy claude
    set -l fpath $fish_dir/functions/$wrapper.fish
    if test -f $fpath
        source $fpath
        if functions -q $wrapper
            _ok "function $wrapper loaded"
            set -l body (functions $wrapper | string collect)
            _assert_contains "$wrapper sets grammar-fix-editor.sh EDITOR" \
                "grammar-fix-editor.sh" "$body"
        else
            _bad "function $wrapper failed to load"
        end
    else
        _bad "wrapper file missing: $fpath"
    end
end

# ---------------------------------------------------------------------------
echo ""
echo "=== kitty.conf ==="

set -l kitty_cfg $repo_root/.config/kitty/kitty.conf
if test -f $kitty_cfg
    _ok "kitty.conf exists"
    set -l kitty_content (cat $kitty_cfg | string collect)
    _assert_contains "kitty.conf maps page_up" "map page_up" "$kitty_content"
    _assert_contains "kitty.conf maps page_down" "map page_down" "$kitty_content"
    _assert_contains "kitty.conf maps shift+page_up" "map shift+page_up" "$kitty_content"
    _assert_contains "kitty.conf maps shift+page_down" "map shift+page_down" "$kitty_content"
else
    _bad "kitty.conf not found at $kitty_cfg"
end

# ---------------------------------------------------------------------------
echo ""
echo "=== my_scripts ==="

for script in $scripts_dir/start.sh $scripts_dir/start_video.sh $scripts_dir/grammar-fix-editor.sh
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
if grep -qE '^\s*python\s+home/' $scripts_dir/start_video.sh
    _bad "start_video.sh has the 'python home/...' typo regression"
else
    _ok "start_video.sh uses an absolute python path"
end

# Specific tests for grammar-fix-editor.sh
set -l gscript $scripts_dir/grammar-fix-editor.sh
if test -x $gscript
    _ok "grammar-fix-editor.sh is executable"
else
    _bad "grammar-fix-editor.sh is not executable"
end

# Test empty file handling in grammar-fix-editor.sh
set -l tmp_empty (mktemp)
bash $gscript $tmp_empty 2>/dev/null
_assert_status "grammar-fix-editor.sh on empty file returns 0" 0 $status
if test ! -s $tmp_empty
    _ok "grammar-fix-editor.sh leaves empty file untouched"
else
    _bad "grammar-fix-editor.sh modified empty file"
end
rm -f $tmp_empty

set -l gscript_content (cat $gscript | string collect)
_assert_contains "grammar-fix-editor.sh supports DEEPSEEK_API_KEY" "DEEPSEEK_API_KEY" "$gscript_content"
_assert_contains "grammar-fix-editor.sh supports OPENROUTER_API_KEY" "OPENROUTER_API_KEY" "$gscript_content"
_assert_contains "grammar-fix-editor.sh handles reasoning_content" "reasoning_content" "$gscript_content"
_assert_contains "grammar-fix-editor.sh strips think tags" "think" "$gscript_content"

# ---------------------------------------------------------------------------
echo ""
echo "=== summary ==="
echo "  passed: $_pass"
echo "  failed: $_fail"

if test $_fail -gt 0
    exit 1
end
