package main

import (
	"context"
	"fmt"
	"log"

	"server/api"
	"server/api/events"
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
		userRoutes := publicRoutes.Group("/users")
		{
			userRoutes.POST("/signup", auth.SignupUser)
			userRoutes.POST("/login", auth.LoginUser)
		}
	}

	protectedRoutes := router.Group("/api")
	protectedRoutes.Use(auth.AuthMiddleware())
	protectedRoutes.Use(api.UpdateLastLocationMiddleware())
	{
		meetupRoutes := protectedRoutes.Group("/meetups")
		{
			meetupRoutes.POST("", events.CreateMeetup)
			meetupRoutes.GET("", events.GetUserMeetups)
		}
		linkupRoutes := protectedRoutes.Group("/linkups")
		{
			linkupRoutes.POST("", events.CreateLinkup)
			linkupRoutes.GET("/nearby", events.GetNearbyLinkups)
			linkupRoutes.GET("", events.GetUserLinkups)
			linkupRoutes.POST("/:id/join", events.JoinLinkup)
			linkupRoutes.DELETE("/:id", events.CancelLinkup)
		}
		userRoutes := protectedRoutes.Group("/users")
		{
			friendRoutes := userRoutes.Group("/friend")
			{
				friendRoutes.GET("", api.GetFriends)
				friendRoutes.POST("", api.SendFriendRequest)
				friendRoutes.PUT("", api.AcceptFriendRequest)
			}
			userRoutes.GET("", api.GetUserProfile)
			userRoutes.PUT("", api.UpdateProfile)
			userRoutes.PUT("/location", api.UpdateUserLocation)
		}
	}

	router.Run("localhost:8080")
}
