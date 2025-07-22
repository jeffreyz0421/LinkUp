package api

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gin-gonic/gin/binding"
	"github.com/jackc/pgx/v5/pgxpool"
)

type FunctionData struct {
	Name                string      `json:"name"`
	Host                string      `json:"host"`
	SecondHost          string      `json:"host1"`
	Vibe                string      `json:"vibe"`
	FunctionType        string      `json:"function_type"`
	LocationName        string      `json:"location_name"`
	LocationCoordinates Coordinates `json:"location_coordinates"`
	StartTime           time.Time   `json:"start_time"`
	EndTime             time.Time   `json:"end_time"`
}

func CreateMeetup(c *gin.Context) {
	var userID string
	var newMeetup FunctionData

	userID = c.MustGet("user_id").(string)
	err := c.MustBindWith(&newMeetup, binding.JSON)

	if err != nil {
		fmt.Println("Error: " + err.Error())
	}

	newMeetup.Host = userID

	placeID := GetPlaceID(newMeetup.LocationName, newMeetup.LocationCoordinates)

	query := `
		INSERT INTO functions (host, function_type, place_id, function_name, starts_at, vibe) VALUES ($1, "meetup", $2, $3, $4, $5) RETURNING function_id;
	`

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)

	defer cancel()

	var functionID string
	err = db.QueryRow(ctx, query, newMeetup.Host, placeID, newMeetup.Name, newMeetup.StartTime, newMeetup.Vibe).Scan(&functionID)

	if err != nil {
		fmt.Println("Error: " + err.Error())
	}

	type Response struct {
		FunctionID string `json:"function_id"`
	}

	response := Response{
		FunctionID: functionID,
	}

	c.IndentedJSON(http.StatusCreated, response)
}

func GetFunction(c *gin.Context) {
}

func GetAllFunctions(c *gin.Context) {
}
