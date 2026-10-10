class_name SettlementProp
extends Node2D
## A building block of a settlement (week 27): a tent, a shrine, a cistern.
## The origin is on the floor in the middle of the prop. Settlements lay
## props out side by side using `width`; residents work at props with
## `work_spot` on, standing at `work_offset` (x, from the origin).

## How much floor it takes up, in px.
@export var width := 48.0
## Residents can work here.
@export var work_spot := false
## Where a worker stands, relative to the origin (x).
@export var work_offset := 0.0
