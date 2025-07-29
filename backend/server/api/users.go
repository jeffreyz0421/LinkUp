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

type UserProfile struct {
	Bio                    string      `json:"bio"`
	Hobbies                []string    `json:"hobbies"`
	Birthdate              time.Time   `json:"birthdate"`
	LastActiveTime         time.Time   `json:"last_active"`
	LastActiveLocation     Coordinates `json:"last_active_location"`
	NumOfFunctionsAttended int         `json:"functions_attended"`
	Rating                 int         `json:"rating"`
}

func UpdateProfile(c *gin.Context) {
	userIDString := c.MustGet("user_id").(string)
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	var userProfile UserProfile

	err = c.MustBindWith(&userProfile, binding.JSON)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	query := `
		UPDATE user_profiles
		SET
			bio = $2,
			birthdate = $3,
			hobbies = $4
		WHERE user_id = $1 RETURNING user_id;
	`

	err = db.QueryRow(ctx, query, userID, userProfile.Bio, userProfile.Birthdate, userProfile.Hobbies).Scan(&userID)

	if err != nil {
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	c.IndentedJSON(http.StatusAccepted, nil)
}

func GetUserProfile(c *gin.Context) {
	userIDString := c.MustGet("user_id").(string)
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	query := `
		SELECT bio, birthdate, hobbies, last_active, last_active_location, functions_attended, rating FROM user_profiles WHERE user_id = $1;
	`

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	var userProfile UserProfile

	row := db.QueryRow(ctx, query, userID)

	err = row.Scan(&userProfile.Bio, &userProfile.Birthdate, &userProfile.Hobbies, &userProfile.LastActiveTime, &userProfile.LastActiveLocation, &userProfile.NumOfFunctionsAttended, &userProfile.Rating)

	if err != nil {
		fmt.Println("Error scanning rows: " + err.Error())
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	c.IndentedJSON(http.StatusFound, userProfile)
}
