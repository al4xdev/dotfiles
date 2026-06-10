#!/usr/bin/env python3
#
# show-keyring-secret.py
# Helper called by the fish function `show-keyring --secrets`.
#
# Takes the D-Bus object path of an item (argv[1]) and prints the secret value
# via libsecret. Only used when the user explicitly passes --secrets.
#
import gi, sys

gi.require_version("Secret", "1")
from gi.repository import Secret

path = sys.argv[1]
s = Secret.Service.get_sync(0, None)
it = Secret.Item.new_for_dbus_path_sync(s, path, 0, None)
it.load_secret_sync(None)
v = it.get_secret()
print("      secret:", repr(v.get_text()) if v else None)
