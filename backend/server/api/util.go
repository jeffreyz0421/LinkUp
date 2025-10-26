package api

import (
	"context"
	"fmt"
	urllib "net/url"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type LocationCoordinates struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

func UpdateLastLocationMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// First, continue processing the request
		c.Next()
		
		// Then update location (after auth middleware has set user_id)
		lastLocationHeader := c.GetHeader("Location")
		if lastLocationHeader == "" {
			return
		}

		// Parse location header (format: "latitude,longitude")
		coords := strings.Split(lastLocationHeader, ",")
		if len(coords) != 2 {
			return
		}

		var latitude, longitude float64
		if _, err := fmt.Sscanf(strings.TrimSpace(coords[0])+","+strings.TrimSpace(coords[1]), "%f,%f", &latitude, &longitude); err != nil {
			return
		}

		// Validate coordinates
		if latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180 {
			return
		}

		// Get user ID from context (set by AuthMiddleware)
		userIDString, exists := c.Get("user_id")
		if !exists {
			return
		}

		userID, err := uuid.Parse(userIDString.(string))
		if err != nil {
			return
		}

		// Update database
		db := c.MustGet("db").(*pgxpool.Pool)
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		// Update both last_active_location and last_active timestamp
		query := `
			UPDATE user_profiles 
			SET last_active_location = ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography,
				last_active = CURRENT_TIMESTAMP
			WHERE user_id = $1;
		`

		_, err = db.Exec(ctx, query, userID, longitude, latitude)
		if err != nil {
			fmt.Printf("Error updating last location: %v\n", err)
		}
	}
}

func addURLParameter(url string, parameters map[string]string) string {
	url = url + "?"
	for parameter, value := range parameters {
		url += urllib.QueryEscape(parameter) + "=" + urllib.QueryEscape(value) + "&"
	}
	return url[:len(url)-1]
}
