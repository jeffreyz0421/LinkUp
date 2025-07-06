package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/mail"
	"os"
	"regexp"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type UserInfo struct {
	Username    string `json:"username"`
	Email       string `json:"email"`
	Password    string `json:"password"`
	Name        string `json:"name"`
	PhoneNumber string `json:"phone_number"`
	UserID      string `json:"user_id"`
}

type AuthResponse struct {
	Success     bool   `json:"success"`
	Error       string `json:"error"`
	UserID      string `json:"user_id"`
	Username    string `json:"username"`
	AccessToken string `json:"access_token"`
	// RefreshToken string `json:"refresh_token"`
}

type JWTSecret struct {
	Secret  string
	Created jwt.NumericDate
}

type Claims struct {
	UserID   string `json:"user_id"`
	Username string `json:"username"`
	jwt.RegisteredClaims
}

// Development refresh token
func getJWTSecret() string {
	return "nGcKdoMsxUeoVICLQYGX4CG2S4rs2e1QRasxo29yPbM="
}

func ValidateUserInput(userInfo UserInfo) (bool, error) {
	// Emails
	if userInfo.Email == "" && userInfo.PhoneNumber == "" && userInfo.Username == "" {
		return false, errors.New("no identifier provided")
	}
	if userInfo.Email != "" {
		userInfo.Email = strings.TrimSpace(userInfo.Email)

		if len(userInfo.Email) > 254 {
			return false, errors.New("email too long")
		}
		_, err := mail.ParseAddress(userInfo.Email)
		if err != nil {
			return false, errors.New("invalid email")
		}
	}

	// Phone numbers
	if userInfo.PhoneNumber != "" {
		cleaned := strings.ReplaceAll(userInfo.PhoneNumber, " ", "")
		cleaned = strings.ReplaceAll(cleaned, "-", "")
		cleaned = strings.ReplaceAll(cleaned, "(", "")
		cleaned = strings.ReplaceAll(cleaned, ")", "")
		cleaned = strings.ReplaceAll(cleaned, ".", "")
		cleaned = strings.TrimPrefix(cleaned, "+")

		digitPattern := regexp.MustCompile(`^\d+$`)
		if !digitPattern.MatchString(cleaned) {
			return false, errors.New("invalid phone number")
		}
	}

	// Username
	if userInfo.Username != "" && len(userInfo.Username) > 50 {
		return false, errors.New("invalid username")
	}

	// Password
	if userInfo.Password == "" || (len(userInfo.Password) < 8 && len(userInfo.Password) > 25) {
		return false, errors.New("password not provided")
	}

	return true, nil
}

func GenerateJWT(user UserInfo) (string, error) {
	claims := &Claims{
		UserID:   user.UserID,
		Username: user.Username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
		},
	}

	// Create the token with claims and sign it with our secret
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(getJWTSecret())
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

func validateJWT(tokenString string) (*Claims, error) {
	// Parse the token and validate the signature
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		// Make sure the signing method is what we expect
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return getJWTSecret(), nil
	})

	if err != nil {
		return nil, err
	}

	// Extract claims if token is valid
	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("invalid token")
}

func HashPassword(password string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), 12)
	if err != nil {
		return "", err
	}
	return string(hash), nil
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

	// Set up the router for the HTTP requests
	router := gin.Default()

	router.Use(func(c *gin.Context) {
		c.Set("db", dbConnection)
		c.Next()
	})

	router.POST("/usersignup", SignupUser)
	router.GET("/userlogin", LoginUser)

	protected := router.Group("/api")

	protected.Use(AuthMiddleware())

	router.Run("localhost:8080")
}

func CheckPassword(password string, hash string) bool {
	newHash, err := HashPassword(password)

	if err != nil {
		log.Printf("Failed to hash password: %v", err)
		return false
	}

	if newHash == hash {
		return true
	}
	return false
}

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get the Authorization header
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
			c.Abort() // Stop processing this request
			return
		}

		// Check if it starts with "Bearer "
		if !strings.HasPrefix(authHeader, "Bearer ") {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid authorization format"})
			c.Abort()
			return
		}

		// Extract the token part (remove "Bearer " prefix)
		tokenString := strings.TrimPrefix(authHeader, "Bearer ")

		// Validate the token
		claims, err := validateJWT(tokenString)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}

		// Store user info in context for use in handlers
		c.Set("user_id", claims.UserID)
		c.Set("username", claims.Username)

		// Continue to the next handler
		c.Next()
	}
}

func LoginUser(c *gin.Context) {
	db := c.MustGet("db").(*pgxpool.Pool)

	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	var user UserInfo
	err := c.ShouldBindJSON(&user)

	failed := AuthResponse{
		Username:    "",
		Success:     false,
		UserID:      "",
		AccessToken: "",
		Error:       "",
	}

	if err != nil {
		failed.Error = "unable to retrieve user input"
		c.IndentedJSON(http.StatusInternalServerError, failed)
		return
	}

	var query string

	validInp, err := ValidateUserInput(user)

	if !validInp {
		failed.Error = err.Error()
		c.IndentedJSON(http.StatusBadRequest, failed)
		return
	}

	var id string

	var passwordHash string

	if user.Username != "" {
		query = `
			SELECT user_id, password_hash FROM users WHERE username == $1
		`

	} else if user.Email != "" {
		query = `
			SELECT user_id, username, password_hash FROM users WHERE email == $1
		`
	} else {
		query = `
			SELECT user_id, username, password_hash FROM users WHERE phone_number == $1
		`
	}

	success := AuthResponse{
		Success: true,
		Error:   "",
	}

	err = db.QueryRow(ctx, query, id).Scan(&success.UserID, &success.Username, &passwordHash)

	if err != nil {
		if err == pgx.ErrNoRows {
			failed.Error = "user not found"
			c.IndentedJSON(http.StatusNotFound, failed)
			return
		}
	}

	if !CheckPassword(user.Password, passwordHash) {
		failed.Error = "wrong password"
		c.IndentedJSON(http.StatusUnauthorized, failed)
		return
	}

	success.AccessToken, err = GenerateJWT(user)

	if err != nil {
		failed.Error = "failed to generate login token"
		c.IndentedJSON(http.StatusInternalServerError, failed)
		return
	}

	c.IndentedJSON(http.StatusAccepted, success)
}

func SignupUser(c *gin.Context) {
	db := c.MustGet("db").(*pgxpool.Pool)

	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	var user UserInfo
	err := c.ShouldBindJSON(&user)

	failed := AuthResponse{
		Username:    "",
		Success:     false,
		UserID:      "",
		AccessToken: "",
		Error:       "",
	}

	if err != nil {
		failed.Error = "unable to retrieve user input"
		c.IndentedJSON(http.StatusInternalServerError, failed)
		return
	}

	validInp, err := ValidateUserInput(user)

	if !validInp {
		failed.Error = err.Error()
		c.IndentedJSON(http.StatusBadRequest, failed)
		return
	}

	passwordHash, err := HashPassword(user.Password)

	if err != nil {
		failed.Error = "password hashing failed"
		c.IndentedJSON(http.StatusInternalServerError, failed)
		return
	}

	query := `
		INSERT INTO users (username, email, password_hash, name, phone_number)
		VALUES ($1, $2, $3, $4, $5) RETURNING user_id;
	`

	_, err = db.Exec(ctx, query, user.Username, user.Email, passwordHash, user.Name, user.PhoneNumber)

	if err != nil {
		failed.Error = "unable to signup user"
		c.IndentedJSON(http.StatusNotAcceptable, failed)
	}

	success := AuthResponse{
		Username:    user.Username,
		Success:     true,
		UserID:      "testUUID",
		AccessToken: "testJWT",
	}

	success.AccessToken, err = GenerateJWT(user)

	if err != nil {
		failed.Error = "failed to generate access token"
		c.IndentedJSON(http.StatusInternalServerError, failed)
		return
	}

	c.IndentedJSON(http.StatusCreated, success)
}
