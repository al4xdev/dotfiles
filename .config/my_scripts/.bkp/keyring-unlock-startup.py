#!/usr/bin/env python3
#
# keyring-unlock-startup.py
# Helper run at login by keyring-unlock-startup.sh (via the autostart .desktop).
#
# Stores/updates an item (the login date/time) INSIDE the Default keyring via
# libsecret. That write forces GNOME to ask for the keyring password once, and
# the keyring stays unlocked for the rest of the session. Takes the log path
# as argv[1].
#
import gi, datetime, sys

gi.require_version("Secret", "1")
from gi.repository import Secret

SCHEMA = Secret.Schema.new(
    "org.user.StartupUnlock",
    Secret.SchemaFlags.NONE,
    {"app": Secret.SchemaAttributeType.STRING},
)
attrs = {"app": "startup-unlock"}
val = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

# store into the DEFAULT collection -> if it's locked, this triggers the password prompt
ok = Secret.password_store_sync(
    SCHEMA, attrs, Secret.COLLECTION_DEFAULT,
    "Startup unlock — last login", val, None,
)

line = f"{val}  ->  {'OK (keyring unlocked)' if ok else 'FAILED/cancelled'}\n"
try:
    with open(sys.argv[1], "a") as f:
        f.write(line)
except Exception:
    pass
print(line, end="")
