package events

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gin-gonic/gin/binding"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

/*
=====================
SHARED EVENT FUNCTIONS
=====================

These functions are used by both meetups and linkups.
*/

/*
====================
InviteUser

Purpose: Invite a user to join a meetup or linkup.

Endpoint: POST /api/events/invite
Authorization: Bearer token required

Frontend Request:
	Headers:
		- Authorization: Bearer {access_token}
		- Content-Type: application/json

	Body (JSON):
		{
			"invitee": "user-uuid-to-invite",
			"function_id": "function-uuid"
		}

Response:
	- Success: 201 Created (empty body)
	- Bad Request: 400 (invalid JSON or missing fields)
	- Server Error: 500
*/

// FunctionData represents a generic event (meetup or linkup)
type FunctionData struct {
	Name                string      `json:"name"`
	Host                uuid.UUID   `json:"host"`
	SecondHost          uuid.UUID   `json:"host1"`
	Vibe                string      `json:"vibe"`
	FunctionType        string      `json:"function_type"`
	LocationName        string      `json:"location_name"`
	LocationCoordinates Coordinates `json:"location_coordinates"`
	StartTime           time.Time   `json:"start_time"`
	EndTime             time.Time   `json:"end_time"`
	InviteStatus        string      `json:"invite_status"`
	PlaceID             string      `json:"place_id"`
	InvitedUsers        []string    `json:"invited_users"`
	FunctionID          uuid.UUID   `json:"function_id"`
}

// FunctionDataList represents a list of events
type FunctionDataList struct {
	Functions []FunctionData `json:"functions"`
}

// Coordinates represents geographic coordinates
type Coordinates struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

func InviteUser(c *gin.Context) {
	type InviteUserRequest struct {
		Invitee    uuid.UUID `json:"invitee"`
		FunctionID uuid.UUID `json:"function_id"`
	}

	var inviteRequest InviteUserRequest

	err := c.MustBindWith(&inviteRequest, binding.JSON)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	query := `
		INSERT INTO function_attendees (user_id, function_id, attendance_status) VALUES ($1, $2, $3) returning user_id;
	`

	var invitee uuid.UUID

	err = db.QueryRow(ctx, query, inviteRequest.Invitee, inviteRequest.FunctionID, "invited").Scan(&invitee)

	if err != nil {
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	c.IndentedJSON(http.StatusCreated, nil)
}

/*
====================
AcceptInvite

Purpose: Accept an invitation to a meetup or linkup.

Endpoint: POST /api/events/accept
Authorization: Bearer token required

Frontend Request:
	Headers:
		- Authorization: Bearer {access_token}
		- Content-Type: application/json

	Body (JSON):
		{
			"function_id": "function-uuid"
		}

Response:
	- Success: 201 Created (empty body)
	- Bad Request: 400 (invalid function_id or user_id)
	- Server Error: 500
*/
func AcceptInvite(c *gin.Context) {
	var userID uuid.UUID
	userIDString := c.MustGet("user_id").(string)
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	type AcceptInviteRequest struct {
		FunctionID uuid.UUID `json:"function_id"`
	}

	var request AcceptInviteRequest

	err = c.MustBindWith(&request, binding.JSON)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	query := `
		UPDATE function_attendees
		SET attendance_status = 'going'
		WHERE user_id = $1 AND function_id = $2
		RETURNING attendance_status;
	`

	var confirmation string

	err = db.QueryRow(ctx, query, userID, request.FunctionID).Scan(&confirmation)

	if err != nil || confirmation != "going" {
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	c.IndentedJSON(http.StatusCreated, nil)
}

/*
====================
GetPlaceID

Purpose: Helper function to convert a place name and coordinates to a Google Places API place ID.
This is called internally by CreateMeetup and CreateLinkup.

Note: This is not a user-facing endpoint, it's a shared helper function.
Returns empty string if API call fails or no place is found.
*/
func GetPlaceID(placeName string, coordinates Coordinates) string {
	apiURL := "https://places.googleapis.com/v1/places:searchText"

	bodyData := map[string]interface{}{
		"pageSize": 1,
		"locationBias": map[string]interface{}{
			"circle": map[string]interface{}{
				"center": coordinates,
				"radius": 200,
			},
		},
		"textQuery": placeName,
	}

	body, err := json.Marshal(bodyData)

	if err != nil {
		fmt.Println("GetPlaceID Error Binding data to request body: " + err.Error())
	}

	req, err := http.NewRequest("POST", apiURL, bytes.NewBuffer(body))

	if err != nil {
		return ""
	}

	req.Header.Add("X-Goog-Api-Key", "")
	req.Header.Add("X-Goog-FieldMask", "places.id")
	req.Header.Add("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)

	if err != nil {
		fmt.Println("Failed to retrieve a place's ID :(")
		return ""
	}

	defer resp.Body.Close()

	body, err = io.ReadAll(resp.Body)

	if err != nil {
		fmt.Println("Error: " + err.Error())
		return ""
	}

	var respData struct {
		Places []struct {
			PlaceID string `json:"id"`
		} `json:"places"`
	}
	err = json.Unmarshal(body, &respData)
	if err != nil {
		fmt.Println("Error: " + err.Error())
		return ""
	}

	if len(respData.Places) == 0 {
		return ""
	}

	return respData.Places[0].PlaceID
}

