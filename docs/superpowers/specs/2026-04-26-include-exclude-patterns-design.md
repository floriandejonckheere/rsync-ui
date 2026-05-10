# Include/Exclude Patterns Design

**Date:** 2026-04-26

## Overview

Add include and exclude pattern lists to the jobs form. These map to rsync's `--include` and `--exclude` flags and let users control which files are transferred or skipped.

## Database

New migration adds two text array columns to `jobs`:

```ruby
t.text :opt_include, array: true, default: []
t.text :opt_exclude, array: true, default: []
```

Both columns are non-null with an empty array default. Null values are coerced to `[]` before save.

## Command Service (`Rsync::CommandService`)

After the existing boolean flags, append pattern flags in this order:

1. `--include=PATTERN` for each entry in `opt_include`
2. `--exclude=PATTERN` for each entry in `opt_exclude`

Order within each list is preserved as stored. All includes always precede all excludes in the generated command.

## Controller (`JobsController`)

- `job_params` permits `opt_include: []` and `opt_exclude: []`
- Coerce `nil` values to `[]` before passing to the model (same pattern as `permitted_repository_id`)

## UI

A collapsible card using the same `<details class="card group py-0">` pattern as the basic/advanced/custom option cards. Placed on the right column, between the preview card and the basic options card.

Inside: two sections ("Include patterns" / "Exclude patterns"), each with:
- A list of text input rows, one per saved pattern
- A remove button (trash icon) on each row
- An "Add pattern" button at the bottom of the list

No server round-trips for add/remove — purely DOM manipulation via a Stimulus controller. Values are submitted as `job[opt_include][]` and `job[opt_exclude][]` arrays on form submit.

## Stimulus Controller (`pattern-list`)

New controller at `app/javascript/controllers/pattern_list_controller.js`.

Targets:
- `list` — the container element holding pattern rows
- `template` — a hidden `<template>` element containing the markup for a new pattern row

Actions:
- `add()` — clones the template, appends to `list`
- `remove(event)` — removes the closest pattern row from the DOM

Instantiated independently for include and exclude sections (no shared state).

## i18n

New keys under `en.jobs.form`:

```yaml
include_exclude_patterns: Include/exclude patterns
include_patterns: Include patterns
exclude_patterns: Exclude patterns
add_pattern: Add pattern
pattern_placeholder: "e.g. *.log"
```
