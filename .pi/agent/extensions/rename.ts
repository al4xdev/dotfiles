/**
 * /rename command - set or show session name
 *
 * pi has a built-in /name and Ctrl+R binding; this provides the /rename
 * spelling the user prefers, with Ctrl+R disabled in keybindings.json.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.registerCommand("rename", {
		description: "Set or show session name (usage: /rename [new name])",
		handler: async (args, ctx) => {
			const name = args.trim();

			if (name) {
				pi.setSessionName(name);
				ctx.ui.notify(`Session named: ${name}`, "info");
			} else {
				const current = pi.getSessionName();
				ctx.ui.notify(current ? `Session: ${current}` : "No session name set", "info");
			}
		},
	});
}
