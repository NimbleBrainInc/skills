---
name: zoom
description: Handles Zoom meeting creation with proper invitation delivery. Use when scheduling Zoom meetings or when user mentions meeting participants. Triggers include "schedule zoom", "create meeting with", "zoom call with".
metadata:
  version: 1.0.0
  category: communication
  tags:
    - zoom
    - meetings
    - calendar
    - mcp
  author:
    name: NimbleBrain
    url: https://www.nimblebrain.ai
---

# Zoom Integration

## Quick Start: Meeting with Attendees

When user asks to create a meeting with participants:

```
1. ZOOM_CREATE_A_MEETING → get join_url
2. GOOGLECALENDAR_CREATE_EVENT with attendees + join_url as location
```

Attendees receive calendar invites with the Zoom link. Done.

## Critical Rule: Zoom Does NOT Send Invites

**NEVER rely on `meeting_invitees` to notify participants.** It does not send emails or calendar invites.

If you use only `ZOOM_CREATE_A_MEETING` with invitees, participants will NOT know the meeting exists.

## Situational Handling

### Situation: User wants meeting WITH specific people

Trigger phrases: "meeting with alice@...", "schedule call with the team", "set up zoom with..."

**Required action:** Chain Zoom + Google Calendar

```
Step 1: ZOOM_CREATE_A_MEETING
  - type: 2
  - topic: [from user or "Meeting"]
  - start_time: [ISO 8601]
  - timezone: [user's timezone]
  - userId: "me"

Step 2: GOOGLECALENDAR_CREATE_EVENT
  - summary: [same topic]
  - start: [same time]
  - end: [start + duration]
  - attendees: [email addresses from user request]
  - location: [join_url from step 1]
  - description: "Join Zoom: [join_url]\nMeeting ID: [id]"
```

**If Google Calendar is not connected:** Tell user to connect it first, OR explicitly state you can only provide the link for them to share manually.

### Situation: User wants meeting WITHOUT specific attendees

Trigger phrases: "create a zoom for tomorrow", "schedule a meeting", "set up a call"

**Action:** Create Zoom meeting only, return the join URL.

```
ZOOM_CREATE_A_MEETING
  - type: 2
  - topic: [from user or "Meeting"]
  - start_time: [ISO 8601]
  - timezone: [user's timezone]
  - userId: "me"

Response: "Meeting created. Join URL: [url]. Share this with your attendees."
```

### Situation: User mentions email but no calendar connected

**Action:** Do NOT create the meeting and claim invites were sent.

```
Response: "To send calendar invites to [email], I need Google Calendar connected.
Would you like to:
1. Connect Google Calendar first (recommended)
2. I create the meeting and give you the link to share manually"
```

Wait for user response before proceeding.

## Parameter Reference

### Required for all meetings

| Parameter | Value | Notes |
|-----------|-------|-------|
| `type` | `2` | Scheduled meeting (default) |
| `userId` | `"me"` | Always use "me" |
| `timezone` | User's IANA timezone | e.g., "Pacific/Honolulu" |
| `start_time` | ISO 8601 | e.g., "2026-01-30T14:00:00" |

### Date/Time Format

Always use: `YYYY-MM-DDTHH:MM:SS` with explicit timezone parameter.

```json
{
  "start_time": "2026-01-30T14:00:00",
  "timezone": "America/New_York"
}
```

Duration is in minutes. Default: 60.

## Error Recovery

| Error | Cause | Fix |
|-------|-------|-----|
| "Invalid start_time" | Wrong format or past date | Use ISO 8601, future date |
| "User not found" | Wrong userId | Use `"userId": "me"` |
| Meeting created but no one notified | Used `meeting_invitees` only | Chain with Google Calendar |

## Anti-Patterns

| Wrong | Right |
|-------|-------|
| Create meeting with `meeting_invitees`, say "invite sent" | Chain with Google Calendar |
| Offer multiple options for inviting | Prescribe the one correct approach |
| Assume timezone | Ask or use known user timezone |
| Create meeting then ask about calendar | Check calendar connection first if attendees mentioned |
