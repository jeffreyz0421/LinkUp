package api

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type UserProfile struct {
	Bio       string    `json:"bio"`
	Hobbies   []string  `json:"hobbies"`
	Birthdate time.Time `json:"birthdate"`
}

func UpdateProfile(c *gin.Context) {
	userIDString := c.MustGet("user_id").(string)
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	var userProfile UserProfile

	err = c.ShouldBindJSON(&userProfile)

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
		SELECT * FROM user_profiles WHERE user_id = $1;
	`

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()
}
