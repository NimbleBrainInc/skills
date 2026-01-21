---
name: googlecalendar
description: Manages Google Calendar events with proper timezone handling. Use when scheduling, updating, or patching calendar events. Triggers include "schedule meeting", "update event", "change meeting time", "reschedule", "make it 30 minutes".
metadata:
  version: 1.1.0
  category: operations
  tags:
    - calendar
    - scheduling
    - events
    - meetings
    - mcp
  author:
    name: NimbleBrain
    url: https://www.nimblebrain.ai
---

# Google Calendar Integration

## Quick Start: Create Event

```
GOOGLECALENDAR_CREATE_EVENT
  summary: "Meeting Title"
  start_time: "2026-01-22T09:00:00"
  end_time: "2026-01-22T10:00:00"
  timezone: "Pacific/Honolulu"
  attendees: ["alice@example.com"]
```

## Critical Rule: PATCH Requires Both Times

**Always send both `start_time` AND `end_time` when patching.** Single-field patches cause timezone interpretation bugs.

```
GOOGLECALENDAR_PATCH_EVENT
  event_id: "abc123"
  calendar_id: "primary"
  start_time: "2026-01-22T09:00:00"   # Always include
  end_time: "2026-01-22T09:30:00"     # Always include
  timezone: "Pacific/Honolulu"
```

## Situational Handling

### Change duration ("make it 30 minutes")

1. Get current event if needed: `GOOGLECALENDAR_FIND_EVENT`
2. Patch with BOTH times:
   - `start_time`: keep original
   - `end_time`: calculate new (start + new duration)
   - `timezone`: user's timezone

### Reschedule ("move to 3pm")

Patch with BOTH times:
- `start_time`: new time
- `end_time`: new time + original duration
- `timezone`: user's timezone

### Create for Zoom meeting

```
GOOGLECALENDAR_CREATE_EVENT
  summary: [Zoom topic]
  start_time: [Zoom start]
  end_time: [start + Zoom duration]
  timezone: [user's timezone]
  attendees: [emails]
  location: [join_url]
  description: "Join Zoom: [join_url]"
```

## Date/Time Format

Use ISO 8601 WITHOUT offset. Let `timezone` param handle it:

```json
{
  "start_time": "2026-01-22T09:00:00",
  "end_time": "2026-01-22T10:00:00",
  "timezone": "Pacific/Honolulu"
}
```

Never use `Z` suffix or offset like `-10:00`.

## Error Recovery

| Error | Cause | Fix |
|-------|-------|-----|
| "time range is empty" | Only `end_time` provided | Send both `start_time` and `end_time` |
| "Invalid start_time" | Timezone in time string | Use plain ISO 8601, set `timezone` separately |

### Example: The "time range is empty" Bug

**Wrong** (only end_time):
```json
{
  "end_time": "2026-01-22T09:30:00",
  "timezone": "Pacific/Honolulu"
}
```
API interprets end as UTC (09:30Z = 23:30 HST) while start stays in local time. End appears before start.

**Right** (both times):
```json
{
  "start_time": "2026-01-22T09:00:00",
  "end_time": "2026-01-22T09:30:00",
  "timezone": "Pacific/Honolulu"
}
```

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| Patch only `end_time` | Send both times |
| `"2026-01-22T09:00:00Z"` | `"2026-01-22T09:00:00"` + timezone param |
| Guess event_id | Use FIND_EVENT if unsure |
