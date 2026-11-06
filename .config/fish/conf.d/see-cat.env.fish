# Guarded so a fresh machine without cargo installed does not error on every shell start.
test -f "$HOME/.cargo/env.fish"; and source "$HOME/.cargo/env.fish"
