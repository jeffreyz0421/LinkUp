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
MEETUP ENDPOINTS
=====================

Meetups are multi-person events where the host can invite specific users.
*/

/*
====================
CreateMeetup

Purpose: Create a new meetup event. After creation, the host can invite users.

Endpoint: POST /api/meetups
Authorization: Bearer token required

Frontend Request:
	Headers:
		- Authorization: Bearer {access_token}
		- Content-Type: application/json

	Body (JSON):
		{
			"name": "Saturday Night Get Together",
			"location_name": "Blue House Pizza",
			"location_coordinates": {
				"latitude": 42.2808,
				"longitude": -83.7430
			},
			"start_time": "2024-11-02T19:00:00Z",
			"end_time": "2024-11-02T22:00:00Z",  // Optional
			"vibe": "casual"
		}

Response:
	- Success: 201 Created
		{
			"function_id": "uuid-of-created-meetup"
		}
	- Bad Request: 400 (missing required fields)
	- Server Error: 500
*/
func CreateMeetup(c *gin.Context) {
	var userID uuid.UUID
	userIDString := c.MustGet("user_id").(string)
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		fmt.Println("Invalid user_id returned :( " + userIDString)
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	var newMeetup FunctionData

	err = c.MustBindWith(&newMeetup, binding.JSON)

	if err != nil {
		fmt.Println("Create Meetup Binding Error: " + err.Error())
	}

	newMeetup.Host = userID

	fmt.Println(newMeetup.LocationName)

	placeID := GetPlaceID(newMeetup.LocationName, newMeetup.LocationCoordinates)

	query := `
		INSERT INTO functions (host, function_type, place_id, function_name, starts_at, vibe) VALUES ($1, $6, $2, $3, $4, $5) RETURNING function_id;
	`

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)

	defer cancel()

	var functionID string
	err = db.QueryRow(ctx, query, newMeetup.Host, placeID, newMeetup.Name, newMeetup.StartTime, newMeetup.Vibe, "meetup").Scan(&functionID)

	if err != nil {
		fmt.Println("Create Meetup Query Execution Error: " + err.Error())
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	type Response struct {
		FunctionID string `json:"function_id"`
	}

	response := Response{
		FunctionID: functionID,
	}

	// TODO -- Invite all the users selected by the host

	c.IndentedJSON(http.StatusCreated, response)
}

/*
====================
GetUserMeetups

Purpose: Get all meetups for the authenticated user (both hosted and attended).

Endpoint: GET /api/meetups
Authorization: Bearer token required

Frontend Request:
	Headers:
		- Authorization: Bearer {access_token}

	Query Params:
		- None (uses authenticated user from token)

Response:
	- Success: 200 OK
		{
			"functions": [
				{
					"function_id": "uuid",
					"host": "uuid",
					"name": "Saturday Night Get Together",
					"function_type": "meetup",
					"place_id": "ChIJ...",
					"start_time": "2024-11-02T19:00:00Z",
					"end_time": "2024-11-02T22:00:00Z",
					"vibe": "casual"
				},
				...
			]
		}
	- Bad Request: 400 (invalid user ID)
	- Server Error: 500

Notes:
	- Returns meetups where user is the host OR is an attendee
	- Empty array if user has no meetups
*/
func GetUserMeetups(c *gin.Context) {
	var userID uuid.UUID
	userIDString := c.MustGet("user_id").(string)
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		fmt.Println("Invalid user_id returned :( " + userIDString)
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	db := c.MustGet("db").(*pgxpool.Pool)

	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	query := `
		SELECT DISTINCT f.*
		FROM functions f
		WHERE f.function_type = 'meetup'
		AND (
			f.host = $1
			
			OR 
			
			EXISTS (
			SELECT 1 
			FROM function_attendees fa 
			WHERE fa.function_id = f.function_id
				AND fa.user_id = $1
			)
		);
	`

	rows, err := db.Query(ctx, query, userID)

	if err != nil {
		fmt.Println("Error getting meetups :(")
	}

	meetups := FunctionDataList{
		Functions: []FunctionData{},
	}

	var meetup FunctionData

	for rows.Next() {
		meetup = FunctionData{
			FunctionType: "meetup",
		}
		rows.Scan(&meetup.FunctionID, &meetup.Host, nil, nil, &meetup.PlaceID, &meetup.Name, &meetup.StartTime, &meetup.EndTime, &meetup.Vibe)
		meetups.Functions = append(meetups.Functions, meetup)
	}

	c.IndentedJSON(http.StatusOK, meetups)
}

