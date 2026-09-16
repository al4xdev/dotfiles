---
name: home-assistant-local
description: Access and control Alexsandro's local Home Assistant through its REST API. Use when asked to inspect home entities or states, operate lights, switches, irrigation valves or the gate, view the doorbell camera, check water information, or otherwise interact with the smart home.
---

# Home Assistant Local

Use `scripts/ha.fish` for the local REST API. It reads the bearer token from the Fish universal variable `home_assistant`; never print or copy that value into commands, logs, responses, or skill files.

## Workflow

1. For a known device, query its state before acting.
2. If the entity is unknown or a known ID fails, search by its Portuguese and English names.
3. For a physical action, use an explicit service such as `turn_on`, `turn_off`, `open_cover`, or `close_cover`. Never use `toggle`.
4. Verify and report the resulting state. If a device is already in the requested state, do not actuate it again.
5. Treat an entity's `on` state as the commanded switch state, not proof of physical flow or motion unless a separate sensor confirms it.

## Commands

Run from this skill directory:

```fish
scripts/ha.fish ping
scripts/ha.fish search escritorio
scripts/ha.fish state switch.escr_l1
scripts/ha.fish service switch turn_on switch.escr_l1
scripts/ha.fish service cover close_cover cover.portao_porta
scripts/ha.fish snapshot camera.campainha /tmp/campainha.jpg
```

`search` accepts a case-insensitive regular expression. `service` posts the action, waits briefly, and returns the entity's resulting state.

## Known entities

- Office main light: `switch.escr_l1`
- Office side light: `switch.escr_l2`
- Gate: `cover.portao_porta`
- Doorbell camera: `camera.campainha`
- Doorbell event: `event.campainha_doorbell_message`
- Garden hose valve: `switch.valvulajardim_interruptor_1`
- Pool hose valve: `switch.valvulajardim_interruptor_2`
- Irrigation controller battery: `sensor.valvulajardim_bateria`
- Water level: `sensor.nivel_de_agua`
- Water-level device connectivity: `binary_sensor.nivel_da_caixa_ping`

These IDs are conveniences, not permanent truth. Search again when an entity is unavailable, missing, or inconsistent with the user's description.

## Interpretation

- The irrigation controller exposes two switch states and battery percentage, but no flow or pressure measurement. Do not claim water is physically flowing from switch state alone.
- The water-level sensor is separate from the irrigation valves.
- A camera snapshot may be inspected only when the user asks to see or assess that camera.
