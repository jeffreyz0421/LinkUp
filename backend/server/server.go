package main

import (
	"context"
	"fmt"
	"log"

	"server/api"
	auth "server/api/userauth"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	connectionURL := "postgres://app:AnnArbor914@localhost:5432/linkup_data"

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

	// Group endpoints with corresponding middleware
	publicRoutes := router.Group("/api")
	{
		userRoutes := publicRoutes.Group("/user")
		{
			userRoutes.POST("/signup", auth.SignupUser)
			userRoutes.POST("/login", auth.LoginUser)
		}
	}

	protectedRoutes := router.Group("/api")
	protectedRoutes.Use(auth.AuthMiddleware())
	{
		meetupRoutes := protectedRoutes.Group("/meetups")
		{
			meetupRoutes.POST("", api.CreateMeetup)
			meetupRoutes.GET("", api.GetUserMeetups)
		}
		userRoutes := protectedRoutes.Group("/users")
		{
			userRoutes.GET("", api.GetUserProfile)
			userRoutes.PUT("", api.UpdateProfile)
		}
	}

	router.Run("0.0.0.0:8080")
}
