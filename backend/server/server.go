package main

import (
	"context"
	"fmt"
	"log"
	"os"

	auth "server/api/userauth"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {

	// Test Coordinates for the Domino's across the street
	// testCoords := api.Coordinates{
	// 	Latitude:  42.270401963473326,
	// 	Longitude: -83.74030060729785,
	// }
	// fmt.Println(api.GetPlaceID("Domino's", testCoords))

	// Set up connection to PostgreSQL database
	connectionURL := os.Getenv("DATABASE_URL")

	if connectionURL == "" {
		log.Fatal("Unable to retrieve database URL")
	}

	dbConnection, err := pgxpool.New(context.Background(), connectionURL)

	if err != nil {
		log.Fatalf("Failed to connect to database: %v\n", err)
	}

	defer dbConnection.Close()

	err = dbConnection.Ping(context.Background())
	if err != nil {
		log.Fatalf("Failed to verify database connection: %v", err)
	}

	fmt.Println("Successfully connected to SQL Database")

	// Set up the router for the HTTP requests
	router := gin.Default()

	router.Use(func(c *gin.Context) {
		c.Set("db", dbConnection)
		c.Next()
	})

	// router.POsT("/api/")

	router.POST("/user/signup", auth.SignupUser)
	router.POST("/user/login", auth.LoginUser)
	// router.POST("/user/profile")

	protected := router.Group("/api")

	protected.Use(auth.AuthMiddleware())

	router.Run("0.0.0.0:8080")
}
