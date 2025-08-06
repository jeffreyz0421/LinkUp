package api

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

type FunctionDataList struct {
	Functions []FunctionData `json:"functions"`
}

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
