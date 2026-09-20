extends Node
## Signal bus shared between sim/ and presentation/. Registered as the `SimEvents`
## project autoload. See specs/01-simulation-clock-and-commands.md's Components
## introduced section for why this is the one place allowed to extend a Node type
## outside sim/'s dip-direction restriction: it carries no domain logic, only signal
## declarations, and a Godot autoload must be Node-derived to be globally addressable.

signal tick_advanced(tick_number: int)
signal command_committed(command: Variant)
signal node_captured(node_index: int)
signal combat_resolved(node_index: int, outcome: Dictionary)
