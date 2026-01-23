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
  summary: "[TITLE]"
  start_time: "YYYY-MM-DDTHH:MM:SS"
  end_time: "YYYY-MM-DDTHH:MM:SS"
  timezone: "[IANA_TIMEZONE]"
  attendees: ["[EMAIL]"]
```

## Critical Rules

### 1. PATCH/UPDATE Requires Both Times

**Always send both `start_time` AND `end_time` when patching.** Single-field patches cause timezone interpretation bugs.

```
GOOGLECALENDAR_PATCH_EVENT
  event_id: "[EVENT_ID]"
  calendar_id: "primary"
  start_time: "YYYY-MM-DDTHH:MM:SS"   # Always include
  end_time: "YYYY-MM-DDTHH:MM:SS"     # Always include
  timezone: "[IANA_TIMEZONE]"          # Always include
```

### 2. Always Specify Timezone

**Never omit the `timezone` parameter.** Without it, times are interpreted as UTC, causing events to land at wrong times.

### 3. Reuse IDs from Prior Tool Calls

**Never fabricate IDs.** Always use exact values returned from previous tool calls:
- `connectionId` - from `search_connections` result
- `event_id` - from `GOOGLECALENDAR_FIND_EVENT` result
- `toolName` - exact spelling from connection's tool list (e.g., `GOOGLECALENDAR_UPDATE_EVENT`, not `GOOGLE_CALENDAR_UPDATE_EVENT`)

### 4. Verify Day-of-Week Matches Date

When scheduling involves a day name (e.g., "next Monday", "this Friday"):
1. Calculate the target date from the day name
2. **Verify the calculated date's day-of-week matches what user requested**
3. State both day AND date when confirming with user (e.g., "Monday, January 27")

## Timezone Reference

### Common Abbreviations to IANA Names

| Abbrev | Name | UTC Offset | IANA Timezone |
|--------|------|------------|---------------|
| **US** |
| EST | Eastern Standard | UTC-5 | America/New_York |
| EDT | Eastern Daylight | UTC-4 | America/New_York |
| CST | Central Standard | UTC-6 | America/Chicago |
| CDT | Central Daylight | UTC-5 | America/Chicago |
| MST | Mountain Standard | UTC-7 | America/Denver |
| MDT | Mountain Daylight | UTC-6 | America/Denver |
| PST | Pacific Standard | UTC-8 | America/Los_Angeles |
| PDT | Pacific Daylight | UTC-7 | America/Los_Angeles |
| AKST | Alaska Standard | UTC-9 | America/Anchorage |
| AKDT | Alaska Daylight | UTC-8 | America/Anchorage |
| HST | Hawaii Standard | UTC-10 | Pacific/Honolulu |
| **Europe** |
| GMT | Greenwich Mean | UTC+0 | Europe/London |
| BST | British Summer | UTC+1 | Europe/London |
| CET | Central European | UTC+1 | Europe/Paris |
| CEST | Central European Summer | UTC+2 | Europe/Paris |
| EET | Eastern European | UTC+2 | Europe/Helsinki |
| EEST | Eastern European Summer | UTC+3 | Europe/Helsinki |
| **Asia/Pacific** |
| IST | India Standard | UTC+5:30 | Asia/Kolkata |
| SGT | Singapore | UTC+8 | Asia/Singapore |
| CST | China Standard | UTC+8 | Asia/Shanghai |
| JST | Japan Standard | UTC+9 | Asia/Tokyo |
| KST | Korea Standard | UTC+9 | Asia/Seoul |
| AEST | Australian Eastern Std | UTC+10 | Australia/Sydney |
| AEDT | Australian Eastern Dst | UTC+11 | Australia/Sydney |
| NZST | New Zealand Standard | UTC+12 | Pacific/Auckland |
| NZDT | New Zealand Daylight | UTC+13 | Pacific/Auckland |
| **Other** |
| UTC | Coordinated Universal | UTC+0 | UTC |
| AST | Atlantic Standard | UTC-4 | America/Halifax |
| ADT | Atlantic Daylight | UTC-3 | America/Halifax |

### Timezone Conversion

**To convert between timezones:**

1. Find UTC offset for source timezone (from table above)
2. Find UTC offset for target timezone
3. Calculate difference: `target_offset - source_offset`
4. Add difference to the time

**Examples:**

| Convert | Calculation | Result |
|---------|-------------|--------|
| 4 PM EST to PST | PST(-8) - EST(-5) = -3 hours | 1 PM PST |
| 4 PM EST to HST | HST(-10) - EST(-5) = -5 hours | 11 AM HST |
| 9 AM PST to JST | JST(+9) - PST(-8) = +17 hours | 2 AM next day JST |
| 3 PM CET to EST | EST(-5) - CET(+1) = -6 hours | 9 AM EST |

**Quick mental model:**
- Negative offset = behind UTC (Americas)
- Positive offset = ahead of UTC (Europe, Asia, Pacific)
- Moving east (toward positive) = add hours
- Moving west (toward negative) = subtract hours

## Situational Handling

### Change duration ("make it 30 minutes")

1. Get current event if needed: `GOOGLECALENDAR_FIND_EVENT`
2. Patch with BOTH times:
   - `start_time`: keep original
   - `end_time`: calculate new (start + new duration)
   - `timezone`: user's timezone (IANA format)

### Reschedule to new time

1. If day name given, verify day-of-week matches calculated date
2. Convert requested time to user's timezone if cross-timezone
3. Patch with BOTH times:
   - `start_time`: new time
   - `end_time`: new time + original duration
   - `timezone`: user's timezone (IANA format)

### Create for Zoom meeting

```
GOOGLECALENDAR_CREATE_EVENT
  summary: "[ZOOM_TOPIC]"
  start_time: "YYYY-MM-DDTHH:MM:SS"
  end_time: "YYYY-MM-DDTHH:MM:SS"
  timezone: "[IANA_TIMEZONE]"
  attendees: ["[EMAIL]"]
  location: "[ZOOM_JOIN_URL]"
  description: "Join Zoom: [ZOOM_JOIN_URL]"
```

## Date/Time Format

Use ISO 8601 WITHOUT offset. Let `timezone` param handle it:

```json
{
  "start_time": "YYYY-MM-DDTHH:MM:SS",
  "end_time": "YYYY-MM-DDTHH:MM:SS",
  "timezone": "[IANA_TIMEZONE]"
}
```

Never use `Z` suffix or offset like `-10:00` in the time string.

## Error Recovery

| Error | Cause | Fix |
|-------|-------|-----|
| "time range is empty" | Only `end_time` provided | Send both `start_time` and `end_time` |
| "Invalid start_time" | Timezone in time string | Use plain ISO 8601, set `timezone` separately |
| "CONNECTION_NOT_FOUND" | Wrong connection ID | Use ID from `search_connections`, not fabricated |
| "Invalid request data" | Wrong parameter names | Use `start_time`/`end_time`, not `start_datetime`/`end_datetime` |

### Example: The "time range is empty" Bug

**Wrong** (only end_time):
```json
{
  "end_time": "YYYY-MM-DDTHH:MM:SS",
  "timezone": "[IANA_TIMEZONE]"
}
```
API interprets end as UTC while start stays in local time. End appears before start.

**Right** (both times):
```json
{
  "start_time": "YYYY-MM-DDTHH:MM:SS",
  "end_time": "YYYY-MM-DDTHH:MM:SS",
  "timezone": "[IANA_TIMEZONE]"
}
```

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| Patch only `end_time` | Send both times |
| `"YYYY-MM-DDTHH:MM:SSZ"` | `"YYYY-MM-DDTHH:MM:SS"` + timezone param |
| Guess event_id | Use FIND_EVENT result |
| Fabricate connection ID | Use search_connections result |
| `start_datetime` parameter | `start_time` parameter |
| Day name without verifying date | Confirm day-of-week matches date |
| Skip timezone param | Always include timezone |
