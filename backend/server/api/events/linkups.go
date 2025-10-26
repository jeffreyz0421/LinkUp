package events

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gin-gonic/gin/binding"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

/*
=====================
LINKUP ENDPOINTS
=====================

Linkups are two-person location-based events. When created, the system
automatically broadcasts invites to nearby users. The first person to
accept joins the linkup.
*/

/*
====================
CreateLinkup

Purpose: Create a new linkup and automatically invite nearby users within the search radius.

Endpoint: POST /api/linkups
Authorization: Bearer token required

Frontend Request:
	Headers:
		- Authorization: Bearer {access_token}
		- Content-Type: application/json

	Body (JSON):
		{
			"vibe": "casual",
			"message": "Want to grab coffee?",
			"search_radius": 500,  // meters (optional, default: 500)
			"location": {
				"latitude": 42.2808,
				"longitude": -83.7430
			}
		}

Response:
	- Success: 201 Created
		{
			"linkup_id": "uuid-of-created-linkup",
			"message": "Linkup created successfully"
		}
	- Bad Request: 400 (missing required fields, invalid coordinates or radius > 5000m)
	- Server Error: 500

Notes:
	- Max search radius: 5000 meters (5 km)
	- Default search radius: 500 meters
	- Automatically invites up to 50 nearby users
*/

type LinkupData struct {
	LinkupID          uuid.UUID   `json:"linkup_id"`
	InitiatorID       uuid.UUID   `json:"initiator_id"`
	InitiatorLocation Coordinates `json:"initiator_location"`
	Status            string      `json:"status"` // "searching", "confirmed"
	SearchRadius      float64     `json:"search_radius"` // meters
	Vibe              string      `json:"vibe"`
	Message           string      `json:"message"`
	CreatedAt         time.Time   `json:"created_at"`
	ConfirmedAt       *time.Time  `json:"confirmed_at,omitempty"`
	OtherUserID       *uuid.UUID  `json:"other_user_id,omitempty"`
}

type CreateLinkupRequest struct {
	Vibe         string      `json:"vibe" binding:"required"`
	Message      string      `json:"message"`
	SearchRadius float64     `json:"search_radius"` // meters, default 500m
	Location     Coordinates `json:"location" binding:"required"`
}

type NearbyLinkup struct {
	LinkupID        uuid.UUID   `json:"linkup_id"`
	InitiatorID     uuid.UUID   `json:"initiator_id"`
	InitiatorName   string      `json:"initiator_name"`
	InitiatorRating int         `json:"initiator_rating"`
	Distance        float64     `json:"distance"` // meters
	Vibe            string      `json:"vibe"`
	Message         string      `json:"message"`
	CreatedAt       time.Time   `json:"created_at"`
}

func CreateLinkup(c *gin.Context) {
	userIDString := c.MustGet("user_id").(string)
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	var request CreateLinkupRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data"})
		return
	}

	// Validate location
	if request.Location.Latitude < -90 || request.Location.Latitude > 90 ||
		request.Location.Longitude < -180 || request.Location.Longitude > 180 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid coordinates"})
		return
	}

	// Validate search radius (max 5km)
	if request.SearchRadius <= 0 || request.SearchRadius > 5000 {
		request.SearchRadius = 500 // default 500m
	}

	// Get place ID for the initiator's location
	placeID := GetPlaceID("Current Location", request.Location)
	if placeID == "" {
		placeID = "manual"
	}

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Insert linkup into functions table
	query := `
		INSERT INTO functions (host, function_type, place_id, function_name, starts_at, vibe)
		VALUES ($1, $2, $3, $4, NOW(), $5)
		RETURNING function_id;
	`

	var linkupID string
	err = db.QueryRow(ctx, query, userID, "linkup", placeID, request.Message, request.Vibe).Scan(&linkupID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create linkup"})
		return
	}

	// Get nearby users and broadcast invites
	// This query finds users within the search radius
	broadcastQuery := `
		SELECT profile.user_id, 
		       ST_Distance(
		           profile.last_active_location,
		           ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography
		       ) as distance
		FROM user_profiles profile
		WHERE profile.last_active_location IS NOT NULL
		  AND profile.user_id != $1
		  AND ST_Distance(
		      profile.last_active_location,
		      ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography
		  ) <= $4
		  AND profile.active = true
		ORDER BY distance
		LIMIT 50;
	`

	rows, err := db.Query(ctx, broadcastQuery, userID, request.Location.Longitude, request.Location.Latitude, request.SearchRadius)

	if err != nil {
		// Even if broadcast fails, the linkup is created
		fmt.Printf("Error broadcasting linkup: %v\n", err)
	}

	// Create invites for nearby users
	if rows != nil {
		var nearbyUserID uuid.UUID
		var distance float64

		inviteQuery := `
			INSERT INTO function_attendees (user_id, function_id, attendance_status)
			VALUES ($1, $2, 'invited')
			ON CONFLICT (user_id, function_id) DO NOTHING;
		`

		for rows.Next() {
			if err := rows.Scan(&nearbyUserID, &distance); err != nil {
				continue
			}

			_, err := db.Exec(ctx, inviteQuery, nearbyUserID, linkupID)
			if err != nil {
				// Continue with other invites even if one fails
				fmt.Printf("Error sending invite: %v\n", err)
			}
		}
		rows.Close()
	}

	c.JSON(http.StatusCreated, gin.H{
		"linkup_id": linkupID,
		"message":   "Linkup created successfully",
	})
}

/*
====================
GetNearbyLinkups

Purpose: Get all available linkups within a geographic radius where the user has been invited.

Endpoint: GET /api/linkups/nearby
Authorization: Bearer token required

Frontend Request:
	Headers:
		- Authorization: Bearer {access_token}

	Query Params:
		- latitude: float (required)
		- longitude: float (required)
		- max_radius: float (optional, default: 5000 meters)

	Example:
		/api/linkups/nearby?latitude=42.2808&longitude=-83.7430&max_radius=1000

Response:
	- Success: 200 OK
		{
			"linkups": [
				{
					"linkup_id": "uuid",
					"initiator_id": "uuid",
					"initiator_name": "John Doe",
					"initiator_rating": 4.5,
					"distance": 150.5,  // meters
					"vibe": "casual",
					"message": "Want to grab coffee?",
					"created_at": "2024-11-02T15:00:00Z"
				},
				...
			]
		}
	- Bad Request: 400 (missing coordinates or invalid format)
	- Server Error: 500

Notes:
	- Only returns linkups where user has been invited (status = 'invited')
	- Results ordered by distance (closest first)
	- Distance is in meters
*/
func GetNearbyLinkups(c *gin.Context) {
	userIDString := c.MustGet("user_id").(string)
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Get location from query params
	latitudeStr := c.Query("latitude")
	longitudeStr := c.Query("longitude")
	maxRadiusStr := c.Query("max_radius")

	if latitudeStr == "" || longitudeStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "location coordinates required"})
		return
	}

	var latitude, longitude, maxRadius float64
	if _, err := fmt.Sscanf(latitudeStr, "%f", &latitude); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid latitude"})
		return
	}
	if _, err := fmt.Sscanf(longitudeStr, "%f", &longitude); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid longitude"})
		return
	}
	if maxRadiusStr != "" {
		if _, err := fmt.Sscanf(maxRadiusStr, "%f", &maxRadius); err != nil {
			maxRadius = 5000 // default 5km
		}
	} else {
		maxRadius = 5000
	}

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Get available linkups where user is invited
	query := `
		SELECT f.function_id,
		       f.host,
		       u.name as initiator_name,
		       profile.rating as initiator_rating,
		       ST_Distance(
		           profile.last_active_location,
		           ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography
		       ) as distance,
		       f.vibe,
		       f.function_name as message,
		       f.starts_at
		FROM functions f
		JOIN function_attendees fa ON f.function_id = fa.function_id
		JOIN user_profiles profile ON f.host = profile.user_id
		JOIN users u ON f.host = u.user_id
		WHERE f.function_type = 'linkup'
		  AND fa.user_id = $1
		  AND fa.attendance_status = 'invited'
		  AND profile.last_active_location IS NOT NULL
		  AND ST_Distance(
		      profile.last_active_location,
		      ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography
		  ) <= $4
		ORDER BY distance;
	`

	rows, err := db.Query(ctx, query, userID, longitude, latitude, maxRadius)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch linkups"})
		return
	}

	var linkups []NearbyLinkup
	for rows.Next() {
		var linkup NearbyLinkup
		err := rows.Scan(
			&linkup.LinkupID,
			&linkup.InitiatorID,
			&linkup.InitiatorName,
			&linkup.InitiatorRating,
			&linkup.Distance,
			&linkup.Vibe,
			&linkup.Message,
			&linkup.CreatedAt,
		)
		if err == nil {
			linkups = append(linkups, linkup)
		}
	}
	rows.Close()

	c.JSON(http.StatusOK, gin.H{"linkups": linkups})
}

/*
====================
JoinLinkup

Purpose: Join a linkup. This automatically cancels all other pending invites for this linkup.
Only works if the linkup is still searching (not yet filled).

Endpoint: POST /api/linkups/:id/join
Authorization: Bearer token required

Frontend Request:
	Headers:
		- Authorization: Bearer {access_token}

	URL Params:
		- :id: linkup UUID to join

	Body:
		- None

	Example:
		POST /api/linkups/550e8400-e29b-41d4-a716-446655440000/join

Response:
	- Success: 200 OK
		{
			"message": "Successfully joined linkup",
			"linkup_id": "uuid"
		}
	- Bad Request: 400 (invalid linkup ID, trying to join own linkup)
	- Not Found: 404 (linkup doesn't exist)
	- Conflict: 409 (linkup already full, someone else joined first)
	- Server Error: 500

Notes:
	- First-come-first-served: Only one person can join
	- Transactional: Atomically updates host1, cancels other invites, updates attendance
	- Cannot join your own linkup
*/
func JoinLinkup(c *gin.Context) {
	userIDString := c.MustGet("user_id").(string)
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	linkupID := c.Param("id")
	linkupUUID, err := uuid.Parse(linkupID)

	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid linkup ID"})
		return
	}

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Start transaction to ensure atomicity
	tx, err := db.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	// Check if linkup still has an available slot (status should still be "searching")
	checkQuery := `
		SELECT f.host, f.host1 
		FROM functions f
		WHERE f.function_id = $1
		  AND f.function_type = 'linkup';
	`

	var host, host1 uuid.UUID
	err = tx.QueryRow(ctx, checkQuery, linkupUUID).Scan(&host, &host1)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Linkup not found"})
		return
	}

	// Check if already full
	if host1 != uuid.Nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Linkup is already full"})
		return
	}

	// Check if user is the initiator
	if host == userID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot join your own linkup"})
		return
	}

	// Update function to add second participant
	updateQuery := `
		UPDATE functions
		SET host1 = $1
		WHERE function_id = $2
		  AND host1 IS NULL
		RETURNING function_id;
	`

	var confirmedID string
	err = tx.QueryRow(ctx, updateQuery, userID, linkupUUID).Scan(&confirmedID)

	if err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Linkup is no longer available"})
		return
	}

	// Cancel all other pending invites for this linkup
	cancelQuery := `
		DELETE FROM function_attendees
		WHERE function_id = $1
		  AND user_id != $2
		  AND attendance_status = 'invited';
	`

	_, err = tx.Exec(ctx, cancelQuery, linkupUUID, userID)
	if err != nil {
		fmt.Printf("Error cancelling other invites: %v\n", err)
	}

	// Update this user's attendance status to 'going'
	attendeeQuery := `
		UPDATE function_attendees
		SET attendance_status = 'going'
		WHERE user_id = $1 AND function_id = $2;
	`

	_, err = tx.Exec(ctx, attendeeQuery, userID, linkupUUID)
	if err != nil {
		fmt.Printf("Error updating attendee status: %v\n", err)
	}

	// Commit transaction
	err = tx.Commit(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to complete join"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":   "Successfully joined linkup",
		"linkup_id": linkupID,
	})
}

/*
====================
GetUserLinkups

Purpose: Get all linkups for the authenticated user (both initiated and joined).

Endpoint: GET /api/linkups
Authorization: Bearer token required

Frontend Request:
	Headers:
		- Authorization: Bearer {access_token}

	Query Params:
		- None (uses authenticated user from token)

Response:
	- Success: 200 OK
		{
			"linkups": [
				{
					"linkup_id": "uuid",
					"status": "searching",  // or "confirmed"
					"partner_id": null,  // or UUID when confirmed
					"vibe": "casual",
					"message": "Want to grab coffee?",
					"created_at": "2024-11-02T15:00:00Z",
					"role": "initiator"  // or "joined"
				},
				{
					"linkup_id": "uuid",
					"status": "confirmed",
					"partner_id": "uuid-of-other-user",
					"vibe": "study",
					"message": "Study session at library",
					"created_at": "2024-11-02T14:00:00Z",
					"role": "joined"
				},
				...
			]
		}
	- Bad Request: 400 (invalid user ID)
	- Server Error: 500

Notes:
	- Returns linkups where user is initiator OR joined
	- Status: "searching" if host1 is null, "confirmed" if filled
	- partner_id is set when linkup is confirmed
	- role indicates if user is "initiator" or "joined"
*/
func GetUserLinkups(c *gin.Context) {
	userIDString := c.MustGet("user_id").(string)
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Get all linkups user is part of (initiated or joined)
	query := `
		SELECT f.function_id,
		       f.host,
		       f.host1,
		       f.vibe,
		       f.function_name as message,
		       f.starts_at,
		       CASE 
		           WHEN f.host = $1 THEN 'initiator'
		           ELSE 'joined'
		       END as role
		FROM functions f
		WHERE f.function_type = 'linkup'
		  AND (f.host = $1 OR f.host1 = $1)
		ORDER BY f.starts_at DESC;
	`

	rows, err := db.Query(ctx, query, userID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch linkups"})
		return
	}

	type UserLinkup struct {
		LinkupID   uuid.UUID  `json:"linkup_id"`
		Status     string     `json:"status"` // "searching" or "confirmed"
		PartnerID  *uuid.UUID `json:"partner_id"`
		Vibe       string     `json:"vibe"`
		Message    string     `json:"message"`
		CreatedAt  time.Time  `json:"created_at"`
		Role       string     `json:"role"` // "initiator" or "joined"
	}

	var linkups []UserLinkup
	for rows.Next() {
		var linkup UserLinkup
		var host, host1 uuid.UUID

		err := rows.Scan(&linkup.LinkupID, &host, &host1, &linkup.Vibe, &linkup.Message, &linkup.CreatedAt, &linkup.Role)
		if err != nil {
			continue
		}

		// Determine status based on whether host1 is set
		if host1 == uuid.Nil {
			linkup.Status = "searching"
		} else {
			linkup.Status = "confirmed"
			if host == userID {
				linkup.PartnerID = &host1
			} else {
				linkup.PartnerID = &host
			}
		}

		linkups = append(linkups, linkup)
	}
	rows.Close()

	c.JSON(http.StatusOK, gin.H{"linkups": linkups})
}

/*
====================
CancelLinkup

Purpose: Cancel a linkup that is still searching. Can only be done by the initiator.
Cannot cancel after someone has joined (linkup is confirmed).

Endpoint: DELETE /api/linkups/:id
Authorization: Bearer token required

Frontend Request:
	Headers:
		- Authorization: Bearer {access_token}

	URL Params:
		- :id: linkup UUID to cancel

	Example:
		DELETE /api/linkups/550e8400-e29b-41d4-a716-446655440000

Response:
	- Success: 200 OK
		{
			"message": "Linkup cancelled successfully"
		}
	- Bad Request: 400 (trying to cancel confirmed linkup)
	- Forbidden: 403 (not the initiator)
	- Not Found: 404 (linkup doesn't exist)
	- Server Error: 500

Notes:
	- Only the initiator can cancel
	- Can only cancel if status is still "searching" (no one has joined)
	- Automatically deletes all pending invites
	- Cannot cancel confirmed linkups
*/
func CancelLinkup(c *gin.Context) {
	userIDString := c.MustGet("user_id").(string)
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	linkupID := c.Param("id")
	linkupUUID, err := uuid.Parse(linkupID)

	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid linkup ID"})
		return
	}

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Check if user is the initiator
	checkQuery := `
		SELECT host, host1
		FROM functions
		WHERE function_id = $1 AND function_type = 'linkup';
	`

	var host, host1 uuid.UUID
	err = db.QueryRow(ctx, checkQuery, linkupUUID).Scan(&host, &host1)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Linkup not found"})
		return
	}

	if host != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Only the initiator can cancel"})
		return
	}

	// Only allow canceling if not yet confirmed
	if host1 != uuid.Nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot cancel confirmed linkup"})
		return
	}

	// Delete all attendees (invites)
	deleteAttendeesQuery := `
		DELETE FROM function_attendees WHERE function_id = $1;
	`

	_, err = db.Exec(ctx, deleteAttendeesQuery, linkupUUID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to cancel invites"})
		return
	}

	// Delete the linkup
	deleteLinkupQuery := `
		DELETE FROM functions WHERE function_id = $1;
	`

	_, err = db.Exec(ctx, deleteLinkupQuery, linkupUUID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to cancel linkup"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Linkup cancelled successfully"})
}

