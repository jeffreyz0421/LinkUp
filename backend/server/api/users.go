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
	Name                   string      `json:"name"`
	Username               string      `json:"username"`
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
	userIDString, exists := c.GetQuery("user_id")
	if !exists {
		userIDString = c.MustGet("user_id").(string)
	}
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	// var incomingRequest struct {
	// 	UserID uuid.UUID `json:"user_id"`
	// }

	// err = c.BindJSON(&incomingRequest)

	// if err != nil {
	// 	c.IndentedJSON(http.StatusBadRequest, nil)
	// 	return
	// } else {
	// 	if incomingRequest.UserID != uuid.Nil {
	// 		userID = incomingRequest.UserID
	// 	}
	// }

	// query := `
	// 	SELECT bio, birthdate, hobbies, last_active, last_active_location, functions_attended, rating FROM user_profiles WHERE user_id = $1;
	// `

	// Debug query 1 while I implement last active locations and other features
	// query := `
	// 	SELECT bio, hobbies, last_active, functions_attended, rating FROM user_profiles WHERE user_id = $1;
	// `

	// Debug query 2
	query := `
		SELECT
			info.name, info.username,
			profile.bio, profile.hobbies, profile.last_active, profile.functions_attended, profile.rating
		FROM user_profiles profile
		JOIN users info ON profile.user_id = info.user_id
		WHERE info.user_id = $1;
	`

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	var userProfile UserProfile

	row := db.QueryRow(ctx, query, userID)

	// err = row.Scan(&userProfile.Bio, &userProfile.Birthdate, &userProfile.Hobbies, &userProfile.LastActiveTime, &userProfile.LastActiveLocation, &userProfile.NumOfFunctionsAttended, &userProfile.Rating)

	// Same debug thing above
	err = row.Scan(&userProfile.Name, &userProfile.Username, &userProfile.Bio, &userProfile.Hobbies, &userProfile.LastActiveTime, &userProfile.NumOfFunctionsAttended, &userProfile.Rating)

	if err != nil {
		fmt.Println("Error scanning rows: " + err.Error())
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	c.IndentedJSON(http.StatusAccepted, userProfile)
}

func SearchUsers(c *gin.Context) {
	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	queryText := c.Query("username")
	if queryText == "" {
		c.IndentedJSON(http.StatusBadRequest, gin.H{"error": "missing username query"})
		return
	}

	// limit to 20 results for performance
	query := `
        SELECT u.user_id, u.username, u.name, COALESCE(up.bio, '') as bio
        FROM users u
        LEFT JOIN user_profiles up ON u.user_id = up.user_id
        WHERE LOWER(u.username) LIKE LOWER($1)
        ORDER BY u.username
        LIMIT 20;
    `

	rows, err := db.Query(ctx, query, queryText+"%")
	if err != nil {
		c.IndentedJSON(http.StatusInternalServerError, gin.H{"error": "query failed"})
		return
	}
	defer rows.Close()

	type PublicUser struct {
		ID       uuid.UUID `json:"id"`
		Name     string    `json:"name"`
		Username string    `json:"username"`
		Avatar   string    `json:"avatar_url"`
	}

	users := []PublicUser{}
	for rows.Next() {
		var u PublicUser
		u.Avatar = "" // you can extend later
		if err := rows.Scan(&u.ID, &u.Name, &u.Username); err != nil {
			c.IndentedJSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		users = append(users, u)
	}

	c.IndentedJSON(http.StatusOK, users)
}


type FriendData struct {
	FriendID uuid.UUID `json:"friend_id"`
	Status   string    `json:"status"`
}

func GetFriends(c *gin.Context) {
	userIDString := c.MustGet("user_id").(string)
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	query := `
		SELECT user_id1, user_id2, friendship_status FROM friendships
		WHERE user_id1 = $1 OR user_id2 = $1;
	`

	type Response struct {
		Friends []FriendData `json:"friends"`
	}

	rows, err := db.Query(ctx, query, userID)

	if err != nil {
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	var response Response
	var friend FriendData

	for rows.Next() {
		friend = FriendData{}
		var user1 uuid.UUID
		var user2 uuid.UUID
		rows.Scan(&user1, &user2, &friend.Status)
		if user1 == userID {
			friend.FriendID = user2
		} else {
			friend.FriendID = user1
		}
		response.Friends = append(response.Friends, friend)
	}

	c.IndentedJSON(http.StatusAccepted, response)
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
		VALUES (LEAST($1, $2)::UUID, GREATEST($1, $2)::UUID, $3)
		RETURNING user_id2;
	`

	err = db.QueryRow(ctx, query, userID, friendRequest.FriendID, "requested").Scan(&userID)

	if err != nil || userID.String() != friendRequest.FriendID.String() {
		c.IndentedJSON(http.StatusInternalServerError, err.Error())
		return
	}

	c.IndentedJSON(http.StatusCreated, nil)
}

func UpdateUserLocation(c *gin.Context) {
	userIDString := c.MustGet("user_id").(string)
	userID, err := uuid.Parse(userIDString)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	type LocationUpdate struct {
		Latitude  float64 `json:"latitude" binding:"required"`
		Longitude float64 `json:"longitude" binding:"required"`
	}

	var location LocationUpdate

	err = c.ShouldBindJSON(&location)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, gin.H{"error": "Invalid location data"})
		return
	}

	// Validate coordinates
	if location.Latitude < -90 || location.Latitude > 90 ||
		location.Longitude < -180 || location.Longitude > 180 {
		c.IndentedJSON(http.StatusBadRequest, gin.H{"error": "Invalid coordinates"})
		return
	}

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Update location and last_active timestamp
	query := `
		UPDATE user_profiles 
		SET last_active_location = ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography,
			last_active = CURRENT_TIMESTAMP
		WHERE user_id = $1;
	`

	_, err = db.Exec(ctx, query, userID, location.Longitude, location.Latitude)

	if err != nil {
		c.IndentedJSON(http.StatusInternalServerError, gin.H{"error": "Failed to update location"})
		return
	}

	c.IndentedJSON(http.StatusOK, gin.H{"message": "Location updated successfully"})
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
		Action   string    `json:"action"`
	}

	var request RequestInfo

	err = c.ShouldBindJSON(&request)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	query := `
		SELECT friendship_status FROM friendships
		WHERE user_id1 = LEAST($1, $2)::UUID AND user_id2 = GREATEST($1, $2)::UUID;
	`

	var friendshipStatus string

	err = db.QueryRow(ctx, query, userID, request.FriendID).Scan(&friendshipStatus)

	if err != nil || userID.String() == request.FriendID.String() {
		c.IndentedJSON(http.StatusInternalServerError, err.Error())
		return
	}

	if friendshipStatus == "requested" {
		switch request.Action {
		case "accept":
			query = `
				UPDATE friendships
				SET friendship_status = 'accepted'
				WHERE user_id1 = LEAST($1, $2)::UUID AND user_id2 = GREATEST($1, $2)::UUID
				RETURNING friendship_status;
			`

			err = db.QueryRow(ctx, query, userID, request.FriendID).Scan(&friendshipStatus)

			if err != nil {
				c.IndentedJSON(http.StatusInternalServerError, err.Error())
				return
			}
		case "decline":
			query = `
				DELETE FROM friendships
				WHERE user_id1 = LEAST($1, $2) AND user_id2 = GREATEST($1, $2)
				RETURNING friendship_status;
			`

			err = db.QueryRow(ctx, query, userID, request.FriendID).Scan(&friendshipStatus)

			if err != nil {
				c.IndentedJSON(http.StatusInternalServerError, nil)
				return
			}
		}
	}

	c.IndentedJSON(http.StatusCreated, nil)
}
