package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

type userSignup struct {
	Username    string `json:"username"`
	Email       string `json:"email"`
	Password    string `json:"password"`
	Name        string `json:"name"`
	PhoneNumber string `json:"phone_number"`
}

func main() {

	// Set up connection to PostgreSQL database

	connectionURL := os.Getenv("DATABASE_URL")

	fmt.Println(connectionURL)

	if connectionURL == "" {
		log.Fatal("Unable to retrieve database URL...")
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

	fmt.Println("Connected to SQL Database")

	// Set up the router for the HTTP requests

	router := gin.Default()

	router.Use(func(c *gin.Context) {
		c.Set("db", dbConnection)
		c.Next()
	})

	router.POST("/usersignup", SignupUser)

	router.Run("localhost:8080")

}

func SignupUser(c *gin.Context) {

	db := c.MustGet("db").(*pgxpool.Conn)

	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	var user userSignup

	err := c.ShouldBindJSON(&user)

	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Bad Request"})
	}

	query := `
		INSERT INTO users (username, email, password_hash, name, phone_number)
		VALUES ($1, $2, crypt($3, gen_salt('bf', 12)), $4, $5);
	`

	_, err = db.Exec(ctx, query, user.Username, user.Email, user.Password, user.Name, user.PhoneNumber)

	if err != nil {
		log.Fatalf("INSERT query failed: %v\n", err)
	}

	c.IndentedJSON(http.StatusCreated, user)
}
