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
	Friends                []uuid.UUID `json:"friend_ids"`
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

	// query := `
	// 	SELECT bio, birthdate, hobbies, last_active, last_active_location, functions_attended, rating FROM user_profiles WHERE user_id = $1;
	// `

	// Debug query while I implement last active locations and other features
	query := `
		SELECT bio, hobbies, last_active, functions_attended, rating FROM user_profiles WHERE user_id = $1;
	`

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	var userProfile UserProfile

	row := db.QueryRow(ctx, query, userID)

	// err = row.Scan(&userProfile.Bio, &userProfile.Birthdate, &userProfile.Hobbies, &userProfile.LastActiveTime, &userProfile.LastActiveLocation, &userProfile.NumOfFunctionsAttended, &userProfile.Rating)

	// Same debug thing above
	err = row.Scan(&userProfile.Bio, &userProfile.Hobbies, &userProfile.LastActiveTime, &userProfile.NumOfFunctionsAttended, &userProfile.Rating)

	if err != nil {
		fmt.Println("Error scanning rows: " + err.Error())
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	c.IndentedJSON(http.StatusFound, userProfile)
}

func SendFriendRequest(c *gin.Context) {
	userIDString := c.MustGet("user_id").(string)
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	type RequestInfo = struct {
		FriendID uuid.UUID `json:"friend_id"`
	}

	var friendRequest RequestInfo

	err = c.ShouldBindJSON(&friendRequest)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	query := `
		INSERT INTO friendships (user_id1, user_id2, friendship_status)
		VALUES (LEAST($1, $2), GREATEST($1, $2))
		RETURNING user_id2;
	`

	err = db.QueryRow(ctx, query, userID, friendRequest.FriendID, "requested").Scan(&userID)

	if err != nil || userID.String() != friendRequest.FriendID.String() {
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	c.IndentedJSON(http.StatusCreated, nil)
}

func AcceptFriendRequest(c *gin.Context) {
	userIDString := c.MustGet("user_id").(string)
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	type RequestInfo = struct {
		FriendID uuid.UUID `json:"friend_id"`
	}

	var friendRequest RequestInfo

	err = c.ShouldBindJSON(&friendRequest)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	query := `
		SELECT * FROM friendships
		WHERE user_id1 = LEAST($1, $2) AND user_id2 = GREATEST($1, $2) RETURNING friendship_status;
	`

	var friendshipStatus string

	err = db.QueryRow(ctx, query, userID, friendRequest.FriendID).Scan(&friendshipStatus)

	if err != nil || userID.String() != friendRequest.FriendID.String() {
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	if friendshipStatus == "requested" {
		query = `
			UPDATE friendships
			SET friendship_status = 'accepted'
			WHERE user_id1 = LEAST($1, $2) AND user_id2 = GREATEST($1, $2)
			RETURNING friendship_status;
		`

		err = db.QueryRow(ctx, query, userID, friendRequest.FriendID).Scan(&friendshipStatus)

		if err != nil || friendshipStatus != "accepted" {
			c.IndentedJSON(http.StatusInternalServerError, nil)
			return
		}
	}

	c.IndentedJSON(http.StatusCreated, nil)
}
