# dotfiles

My personal dotfiles. Public mostly so I can clone them onto a fresh box —
if anything here is useful to you, help yourself.

## Who I am

Materials engineer, Linux since I was a kid. The kind of person who
would rather model a failure mode upfront than learn from production
post-mortems. This repo reflects that — a test suite for *dotfiles*, a
`.gitignore` that denies by default with explicit safety locks at the
bottom, and a `CLAUDE.md` that tells coding agents which files they are
not allowed to touch.

If something here looks over-engineered for personal config, that is the
point: I do not keep a separate "home mode".

## What's tracked

The repository sits at `$HOME` and uses a deny-everything `.gitignore` with
an explicit allowlist for the files I actually care about: a handful of
fish configs, the bashrc, the starship prompt, the `mimeapps.list`, a tiny
set of personal scripts under `.config/my_scripts/`, and the Claude Code
CLI bits (`CLAUDE.md` + `skills/`). Anything else — fish universal
variables, history files, local Claude state, secrets — is ignored by
default. The "SAFETY LOCKS" block at the bottom of `.gitignore` belts the
suspenders for the most sensitive paths.

Daily-driver stack: fish, starship, eza, ugrep, fastfetch, alacritty,
uv for Python, nvm for Node, and Claude Code for everything else.

## Tests

The repo ships a small fish test suite that pins the behaviors I keep
breaking by accident — alias expansion, the `gen` launcher, completions,
and the `my_scripts/` helpers. Run it with:

```fish
./.config/my_scripts/test_dotfiles.fish
```

It self-isolates via `fish --no-config` so it doesn't pick up whatever is
currently installed under `~/.config/`. Exit code is 0 on success.

## Sync model

There is no automated sync. The repo lives at `~/git/my/dotfiles/` and I
copy files into `~/.config/` (or wherever they belong) by hand when I want
changes to take effect on the live shell. Keeping the two paths separate
on purpose — lets me iterate here without breaking my running terminal.

## copyright

Artwork: You tried to pet the space void
Artist: Yuumei;
Source: Image[https://www.yuumeiart.com/].
