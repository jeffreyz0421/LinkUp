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

type userInfo struct {
	Username    string `json:"username"`
	Email       string `json:"email"`
	Password    string `json:"password"`
	Name        string `json:"name"`
	PhoneNumber string `json:"phone_number"`
}

type signupResponse struct {
	Success  bool   `json:"success"`
	Error    string `json:"error"`
	UserID   string `json:"user_id"`
	Username string `json:"username"`
	JWTToken string `json:"jwt_token"`
}

type loginResponse struct {
	Success      string `json:"success"`
	ErrorMessage string `json:"error_message"`
	Username     string `json:"username"`
	JWTToken     string `json:"jwt_token"`
}

func LogInUser(c *gin.Context, db *pgxpool.Pool) {
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	user := userInfo{
		Username:    "jawaaddd",
		Email:       "tanvirja@buffalo.edu",
		Password:    "Abc123!",
		Name:        "jawad",
		PhoneNumber: "1234567890",
	}

	var query string

	if user.Username != "" {
		query = `
			SELECT password_hash FROM users WHERE username = $1;
		`
		_, err := db.Exec(ctx, query, user.Username)
		if err != nil {

		}
	}

	response := loginResponse{}

	_, err := db.Exec(ctx, query, user.Username, user.Email, user.Password, user.Name, user.PhoneNumber)
	if err != nil {
		fmt.Println("Login test failed...")
	}

	c.IndentedJSON(http.StatusAccepted, response)
}

func main() {

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

	// TestDuplicateUsername(dbConnection)

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

	db := c.MustGet("db").(*pgxpool.Pool)

	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	var user userInfo

	err := c.ShouldBindJSON(&user)

	// TODO --- Validate input

	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Bad Request"})
	}

	query := `
		INSERT INTO users (username, email, password_hash, name, phone_number)
		VALUES ($1, $2, crypt($3, gen_salt('bf', 12)), $4, $5) RETURNING user_id;
	`
	_, err = db.Exec(ctx, query, user.Username, user.Email, user.Password, user.Name, user.PhoneNumber)

	if err != nil {
		// log.Fatalf("Failed to add user to database: %v\n", err)
		failed := signupResponse{
			Username: user.Username,
			Success:  true,
			UserID:   "testUUID",
			JWTToken: "testJWT",
			Error:    "Username taken :(",
		}
		c.IndentedJSON(http.StatusNotAcceptable, failed)
		c.Next()
	}

	success := signupResponse{
		Username: user.Username,
		Success:  true,
		UserID:   "testUUID",
		JWTToken: "testJWT",
	}

	c.IndentedJSON(http.StatusCreated, success)
}
