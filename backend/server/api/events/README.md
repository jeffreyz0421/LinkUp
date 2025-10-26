# Events Package

This package contains all event-related functionality for the LinkUp backend, including meetups and linkups.

## Package Structure

### `functions.go` - Shared Event Functions
- **FunctionData**: Generic event data structure used by both meetups and linkups
- **FunctionDataList**: List wrapper for events
- **Coordinates**: Geographic coordinate type
- **InviteUser**: Shared function to invite users to events
- **AcceptInvite**: Shared function to accept event invitations
- **GetPlaceID**: Helper function to get Google Places API place IDs

### `meetups.go` - Meetup-Specific Functions
- **CreateMeetup**: Creates a new meetup event
- **GetUserMeetups**: Retrieves all meetups for a user (hosted or attended)

### `linkups.go` - Linkup-Specific Functions
- **CreateLinkup**: Creates a new linkup and broadcasts invites to nearby users
- **GetNearbyLinkups**: Gets available linkups within a geographic radius
- **GetUserLinkups**: Retrieves all linkups for a user (initiated or joined)
- **JoinLinkup**: Joins a linkup (first-come-first-served, only 2 people max)
- **CancelLinkup**: Cancels a linkup (only initiator can cancel before confirmation)

## API Endpoints

### Meetups
- `POST /api/meetups` - Create a meetup
- `GET /api/meetups` - Get user's meetups

### Linkups
- `POST /api/linkups` - Create a linkup
- `GET /api/linkups/nearby` - Get nearby linkups (requires location params)
- `GET /api/linkups` - Get user's linkups
- `POST /api/linkups/:id/join` - Join a linkup
- `DELETE /api/linkups/:id` - Cancel a linkup

## Key Differences

### Meetups
- Multi-person events
- No automatic invitations
- Users must be explicitly invited
- Can have many attendees

### Linkups
- Two-person only (host + 1 other)
- Location-based automatic invitations
- First-come-first-served joining
- Broadcasts to nearby users automatically
- Cancels all other invites when someone joins

## Database Schema

Both meetups and linkups use the `functions` table:
- `host`: Event creator/initiator
- `host1`: Second participant (linkups only, null for meetups)
- `function_type`: 'meetup' or 'linkup'
- `place_id`: Google Places API ID
- `function_name`: Event name/message
- `starts_at`: Event start time
- `ends_at`: Event end time (optional)
- `vibe`: Event mood/atmosphere

## Shared Functions

Both meetups and linkups share:
- **InviteUser**: Add users to `function_attendees` table
- **AcceptInvite**: Update attendance status to 'going'
- **GetPlaceID**: Resolve location names to Google Places IDs

