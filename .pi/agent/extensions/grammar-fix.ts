/**
 * grammar-fix.ts — Grammar fixer for the pi message editor.
 *
 * Press `ctrl+g` while typing a message to fix its grammar in place,
 * using a secondary model from pi's own model registry (does not consume
 * the main agent's turn). The corrected text replaces the editor content,
 * so you review it before pressing enter.
 *
 * Model selection (priority order):
 *   1. `--grammar-model provider/modelId` CLI flag
 *   2. `/grammar-model provider/modelId` command (no arg = searchable picker)
 *   3. the session's current model
 *
 * Language selection (priority order):
 *   1. `--grammar-language <code>` CLI flag
 *   2. `/grammar-language <code>` command (no arg = pick from list)
 *   3. "auto" (preserve the text's language)
 *
 * Install:
 *   pi install git:github.com/al4xdev/pi-grammar-fix
 *   # or copy this file to ~/.pi/agent/extensions/ (global) or .pi/extensions/ (project)
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync, unlinkSync } from "node:fs";
import { dirname } from "node:path";
import { homedir } from "node:os";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { Model } from "@earendil-works/pi-ai";
import { Container, Input, Key, SelectList, Spacer, Text } from "@earendil-works/pi-tui";
import type { KeybindingsManager, SelectItem, Theme, TUI } from "@earendil-works/pi-tui";

const STATUS_KEY = "grammar-fix";
const CONFIG_PATH = `${homedir()}/.pi/agent/grammar-fix.json`;
const LOCK_PATH = `${homedir()}/.pi/agent/grammar-fix.lock`;
const LOCK_TIMEOUT_MS = 30_000;

const ICONS = [
	"✍️", "✏️", "📝", "📄", "🖊️", "🖋️", "🖌️", "✒️", "📌", "📎",
	"🗒️", "📑", "📚", "📖", "🔍", "🔎", "💡", "✨", "⭐", "🌟",
	"🎯", "🚀", "⚡", "🔥", "🧠", "💬", "💭", "🗨️", "✅", "✔️",
	"☑️", "✓", "⚠️", "❌", "🔄", "⏳", "⌛", "📏", "📐", "✂️",
	"🧹", "🪄", "🔧", "🛠️", "🧩", "📂", "🗂️", "🏆", "🎉", "👏",
	"💪",
];

function randomIcon(): string {
	return ICONS[Math.floor(Math.random() * ICONS.length)];
}

const LANGUAGES: Record<string, string> = {
	auto: "preserve the original language",
	pt: "Brazilian Portuguese",
	ptpt: "European Portuguese",
	en: "English",
	es: "Spanish",
	fr: "French",
	de: "German",
	it: "Italian",
	ja: "Japanese",
	ko: "Korean",
	zh: "Chinese",
	ru: "Russian",
	nl: "Dutch",
	pl: "Polish",
	sv: "Swedish",
	da: "Danish",
	fi: "Finnish",
	no: "Norwegian",
	tr: "Turkish",
	ar: "Arabic",
	hi: "Hindi",
	uk: "Ukrainian",
};

const LANGUAGE_LABELS: Record<string, string> = {
	auto: "Auto (keep original language)",
	pt: "Português (Brasil)",
	ptpt: "Português (Portugal)",
	en: "English",
	es: "Español",
	fr: "Français",
	de: "Deutsch",
	it: "Italiano",
	ja: "日本語",
	ko: "한국어",
	zh: "中文",
	ru: "Русский",
	nl: "Nederlands",
	pl: "Polski",
	sv: "Svenska",
	da: "Dansk",
	fi: "Suomi",
	no: "Norsk",
	tr: "Türkçe",
	ar: "العربية",
	hi: "हिन्दी",
	uk: "Українська",
};

function buildSystemPrompt(language: string): string {
	const langRule = LANGUAGES[language] ?? LANGUAGES.auto;
	return [
		"You are a grammar fixer for a coding-agent message input.",
		"Fix ONLY grammar, spelling, punctuation, typos, and capitalization errors.",
		"Rules:",
		`- Corrected text language: ${langRule}.`,
		"- Do NOT translate technical terms (code, commands, git terms like commit/branch/merge/staging, framework names, APIs, jargon, file paths, URLs, identifiers, quoted strings) — keep them in their technical form even when the surrounding text is in another language.",
		"- Do not change code, commands, file paths, URLs, identifiers, or quoted strings.",
		"- Do not rewrite style, add, or remove content.",
		"- Keep line breaks and overall structure.",
		"- Reply with ONLY the corrected text. No explanations, no quotes, no preamble.",
	].join("\n");
}

const GRAMMAR_JOKES = [
	"Teaching Oxford commas to your AI...",
	"Debugging English syntax errors...",
	"Polishing your typos until they shine...",
	"Replacing 'irregardless' with actual English...",
	"Making your message sound like a Senior Dev...",
	"Untangling subject-verb agreements...",
	"Consulting the ancient grammar wizards...",
	"Fixing typos before your team sees them...",
	"Adding missing semicolons and commas...",
	"Translating dev-slang into proper English...",
	"Hunting down rogue apostrophes...",
	"Turning 'u' into 'you' since 2026...",
	"Eliminating double negatives in parallel...",
	"Refactoring english.txt...",
];

interface ThemeTrail {
	walker: string;
	dirty: string;
	clean: string;
}

const TRAIL_THEMES: ThemeTrail[] = [
	{ walker: "✍️ ", dirty: "❌", clean: "✨" },
	{ walker: "🪄 ", dirty: "🐛", clean: "🦋" },
	{ walker: "🧹 ", dirty: "💩", clean: "🧼" },
	{ walker: "🔍 ", dirty: "❓", clean: "✅" },
	{ walker: "🚀 ", dirty: "🐌", clean: "⚡" },
];

function startAnimatedLoading(ctx: ExtensionContext, language: string, modelId: string): () => void {
	const joke = GRAMMAR_JOKES[Math.floor(Math.random() * GRAMMAR_JOKES.length)];
	const theme = TRAIL_THEMES[Math.floor(Math.random() * TRAIL_THEMES.length)];
	const langLabel = LANGUAGE_LABELS[language] ?? language;

	const TRAIL_LEN = 8;
	let step = 0;
	let direction = 1;

	const update = () => {
		const trail: string[] = [];
		for (let i = 0; i < TRAIL_LEN; i++) {
			if (i < step) trail.push(theme.clean);
			else if (i === step) trail.push(theme.walker);
			else trail.push(theme.dirty);
		}
		const trailStr = trail.join(" ");

		ctx.ui.setStatus(STATUS_KEY, `${theme.walker} ${joke}`);
		ctx.ui.setWidget(STATUS_KEY, [`${trailStr} (${langLabel} · ${modelId})`, `💬 ${joke}`]);

		step += direction;
		if (step >= TRAIL_LEN) {
			step = TRAIL_LEN - 1;
			direction = -1;
		} else if (step < 0) {
			step = 0;
			direction = 1;
		}
	};

	update();
	const timer = setInterval(update, 150);

	return () => {
		clearInterval(timer);
		ctx.ui.setStatus(STATUS_KEY, undefined);
		ctx.ui.setWidget(STATUS_KEY, undefined);
	};
}

interface GrammarFixConfig {
	model?: string;
	language?: string;
}

interface LockData {
	timestamp: number;
	pid: number;
}

function tryAcquireLock(ctx: ExtensionContext): boolean {
	try {
		if (existsSync(LOCK_PATH)) {
			try {
				const raw = readFileSync(LOCK_PATH, "utf8");
				const data = JSON.parse(raw) as LockData;
				const age = Date.now() - (data.timestamp ?? 0);
				if (age < LOCK_TIMEOUT_MS) {
					ctx.ui.notify("Grammar fix is already in progress…", "warning");
					return false;
				}
			} catch {
				// Lock file corrupted or unreadable, treat as stale lock
			}
			// Lock is stale / ghost lock, remove it
			releaseLock();
		}
		mkdirSync(dirname(LOCK_PATH), { recursive: true });
		const lockContent: LockData = { timestamp: Date.now(), pid: process.pid };
		writeFileSync(LOCK_PATH, JSON.stringify(lockContent), "utf8");
		return true;
	} catch (err) {
		console.error(`[grammar-fix] failed to acquire lock: ${(err as Error).message}`);
		return true;
	}
}

function releaseLock(): void {
	try {
		if (existsSync(LOCK_PATH)) {
			unlinkSync(LOCK_PATH);
		}
	} catch {
		// Ignore cleanup errors
	}
}

function loadConfig(): GrammarFixConfig {
	try {
		return JSON.parse(readFileSync(CONFIG_PATH, "utf8")) as GrammarFixConfig;
	} catch {
		return {};
	}
}

function saveConfig(config: GrammarFixConfig): void {
	try {
		mkdirSync(dirname(CONFIG_PATH), { recursive: true });
		writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
	} catch (err) {
		console.error(`[grammar-fix] failed to save config: ${(err as Error).message}`);
	}
}

function parseModelSpec(spec: string): { provider: string; modelId: string } | undefined {
	const idx = spec.indexOf("/");
	if (idx <= 0 || idx === spec.length - 1) return undefined;
	return { provider: spec.slice(0, idx), modelId: spec.slice(idx + 1) };
}

function findModel(ctx: ExtensionContext, spec: string): Model<any> | undefined {
	const parsed = parseModelSpec(spec);
	if (!parsed) return undefined;
	return ctx.modelRegistry.find(parsed.provider, parsed.modelId);
}

/* ------------------------------------------------------------------ */
/* Searchable model picker (mirrors the built-in /model selector UX)  */
/* ------------------------------------------------------------------ */

function selectListTheme(theme: Theme) {
	return {
		selectedPrefix: (text: string) => theme.fg("accent", text),
		selectedText: (text: string) => theme.fg("accent", text),
		description: (text: string) => theme.fg("muted", text),
		scrollInfo: (text: string) => theme.fg("dim", text),
		noMatch: (text: string) => theme.fg("warning", text),
	};
}

class ModelPicker extends Container {
	private readonly tui: TUI;
	private readonly keybindings: KeybindingsManager;
	private readonly theme: Theme;
	private readonly allItems: SelectItem[];
	private readonly onDone: (value: string | undefined) => void;
	private readonly hint = new Text("", 1, 0);
	private readonly input = new Input();
	private list: SelectList;
	private query = "";

	constructor(tui: TUI, theme: Theme, keybindings: KeybindingsManager, allItems: SelectItem[], onDone: (value: string | undefined) => void) {
		super();
		this.tui = tui;
		this.theme = theme;
		this.keybindings = keybindings;
		this.allItems = allItems;
		this.onDone = onDone;
		this.input.focused = true;
		this.rebuild();
	}

	private buildList(items: SelectItem[]): SelectList {
		const list = new SelectList(items, 12, selectListTheme(this.theme));
		list.onSelect = (item) => this.onDone(item.value);
		list.onCancel = () => this.onDone(undefined);
		return list;
	}

	private filterItems(): SelectItem[] {
		const q = this.query.toLowerCase();
		if (!q) return this.allItems;
		return this.allItems.filter((item) => item.value.toLowerCase().includes(q));
	}

	private rebuild(): void {
		const filtered = this.filterItems();
		this.clear();
		this.hint.setText(filtered.length === this.allItems.length ? "Type to filter models" : `${filtered.length} of ${this.allItems.length} models`);
		this.addChild(this.hint);
		this.addChild(this.input);
		this.addChild(new Spacer(1));
		this.list = this.buildList(filtered);
		this.addChild(this.list);
		this.addChild(new Text(filtered.length === 0 ? this.theme.fg("warning", "No models found — press enter to clear, escape to cancel") : this.theme.fg("dim", "↑↓ navigate · enter select · escape cancel"), 1, 0));
		this.tui.requestRender();
	}

	handleInput(data: string): void {
		if (this.keybindings.matches(data, "tui.select.up") || this.keybindings.matches(data, "tui.select.down") || this.keybindings.matches(data, "tui.select.confirm") || this.keybindings.matches(data, "tui.select.cancel")) {
			this.list.handleInput(data);
			return;
		}
		this.input.handleInput(data);
		const query = this.input.getValue();
		if (query === this.query) return;
		this.query = query;
		this.rebuild();
	}
}

async function pickModel(ctx: ExtensionContext): Promise<string | undefined> {
	const available = ctx.modelRegistry.getAvailable();
	if (available.length === 0) {
		ctx.ui.notify("No models available.", "error");
		return undefined;
	}
	const items: SelectItem[] = available.map((m) => ({ value: `${m.provider}/${m.id}`, label: `${m.provider}/${m.id}` }));
	return ctx.ui.custom<string | undefined>((tui, theme, keybindings, done) => new ModelPicker(tui, theme, keybindings, items, done));
}

/* ------------------------------------------------------------------ */
/* Core: fix the editor text with the secondary model                 */
/* ------------------------------------------------------------------ */

async function fixGrammar(pi: ExtensionAPI, ctx: ExtensionContext): Promise<void> {
	if (!ctx.hasUI) return;

	if (!tryAcquireLock(ctx)) return;

	try {
		const text = ctx.ui.getEditorText();
		const trimmed = text.trim();
		if (!trimmed) {
			ctx.ui.notify("Editor is empty — nothing to fix.", "info");
			return;
		}
		if (trimmed.startsWith("/")) {
			ctx.ui.notify("This looks like a command — skipping.", "info");
			return;
		}

		const config = loadConfig();
		const spec = (pi.getFlag("grammar-model") as string | undefined) ?? config.model;
		const language = (pi.getFlag("grammar-language") as string | undefined) ?? config.language ?? "auto";

		let model: Model<any> | undefined;
		if (spec) {
			model = findModel(ctx, spec);
			if (!model) {
				ctx.ui.notify(`Configured model not found: ${spec} — using session model.`, "warning");
			}
		}
		model ??= ctx.model;

		if (!model) {
			ctx.ui.notify("No model available. Configure one with /grammar-model <provider/modelId>.", "error");
			return;
		}

		const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
		if (!auth.ok) {
			ctx.ui.notify(`No credentials for ${model.provider}: ${auth.error}`, "error");
			return;
		}

		const provider = ctx.modelRegistry.getProvider(model.provider);
		if (!provider) {
			ctx.ui.notify(`Provider ${model.provider} not found.`, "error");
			return;
		}

		// Loading UI: animated walking trail + witty grammar joke
		const stopLoading = startAnimatedLoading(ctx, language, model.id);

		try {
			const stream = provider.streamSimple(
				model,
				{
					systemPrompt: buildSystemPrompt(language),
					messages: [{ role: "user", content: [{ type: "text", text: trimmed }] }],
				},
				{
					apiKey: auth.apiKey,
					headers: auth.headers,
					env: auth.env,
					signal: ctx.signal,
					temperature: 0,
				},
			);

			let corrected = "";
			for await (const event of stream) {
				if (event.type === "text_delta") corrected += event.delta;
				if (event.type === "error") throw new Error(event.partial?.errorMessage ?? "stream error");
			}
			const result = corrected.trim();

			if (!result) {
				ctx.ui.notify("The model returned no text.", "error");
				return;
			}

			ctx.ui.setEditorText(result);
			if (result === trimmed) {
				ctx.ui.notify(`${randomIcon()} No changes — the text is already OK.`, "info");
			} else {
				ctx.ui.notify(`${randomIcon()} Grammar fixed. Review and send!`, "info");
			}
		} catch (err) {
			ctx.ui.notify(`❌ Fix failed: ${(err as Error).message}`, "error");
		} finally {
			stopLoading();
		}
	} finally {
		releaseLock();
	}
}

export default function (pi: ExtensionAPI): void {
	pi.registerFlag("grammar-model", {
		description: "Model used by the ctrl+g grammar fix (provider/modelId)",
		type: "string",
	});

	pi.registerFlag("grammar-language", {
		description: "Language for grammar fixes: auto | pt | en | ... (language code)",
		type: "string",
	});

	pi.registerShortcut(Key.ctrl("g"), {
		description: "Fix grammar of the current editor text in place",
		handler: (ctx) => fixGrammar(pi, ctx),
	});

	pi.registerCommand("grammar-model", {
		description: "Set the grammar-fix model (provider/modelId). Use 'reset' to clear. No arg = searchable picker.",
		handler: async (args, ctx) => {
			const spec = args?.trim();
			if (spec) {
				if (spec === "reset" || spec === "clear" || spec === "default") {
					const cfg = loadConfig();
					delete cfg.model;
					saveConfig(cfg);
					ctx.ui.notify("Grammar model reset to session default ✓", "info");
					return;
				}
				if (!findModel(ctx, spec)) {
					ctx.ui.notify(`Model not found (use provider/modelId): ${spec}`, "error");
					return;
				}
				saveConfig({ ...loadConfig(), model: spec });
				ctx.ui.notify(`Grammar model: ${spec} ✓`, "info");
				return;
			}

			const choice = await pickModel(ctx);
			if (!choice) return;
			saveConfig({ ...loadConfig(), model: choice });
			ctx.ui.notify(`Grammar model: ${choice} ✓`, "info");
		},
	});

	pi.registerCommand("grammar-language", {
		description: "Set the grammar-fix language (auto, pt, en, ...). Use 'reset' to clear. No arg = pick from list.",
		handler: async (args, ctx) => {
			const spec = args?.trim().toLowerCase();
			if (spec) {
				if (spec === "reset" || spec === "clear" || spec === "default") {
					const cfg = loadConfig();
					delete cfg.language;
					saveConfig(cfg);
					ctx.ui.notify("Grammar language reset to default (auto) ✓", "info");
					return;
				}
				if (!LANGUAGES[spec]) {
					ctx.ui.notify(`Invalid language. Use: ${Object.keys(LANGUAGES).join(" | ")}`, "error");
					return;
				}
				saveConfig({ ...loadConfig(), language: spec });
				ctx.ui.notify(`Grammar language: ${spec} (${LANGUAGE_LABELS[spec] ?? spec}) ✓`, "info");
				return;
			}

			const items: SelectItem[] = Object.keys(LANGUAGES).map((code) => ({
				value: code,
				label: `${code} — ${LANGUAGE_LABELS[code] ?? code}`,
			}));
			const options = items.map((i) => i.label);

			const choice = await ctx.ui.select("Grammar fix language:", options);
			if (!choice) return;
			const matched = items.find((i) => i.label === choice);
			if (!matched) return;
			saveConfig({ ...loadConfig(), language: matched.value });
			ctx.ui.notify(`Grammar language: ${matched.value} (${LANGUAGE_LABELS[matched.value] ?? matched.value}) ✓`, "info");
		},
	});
}
