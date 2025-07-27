package api

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/mail"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type UserInfo struct {
	Username    string    `json:"username"`
	Email       string    `json:"email"`
	Password    string    `json:"password"`
	Name        string    `json:"name"`
	PhoneNumber string    `json:"phone_number"`
	UserID      uuid.UUID `json:"user_id"`
}

type AuthResponse struct {
	UserID      uuid.UUID `json:"user_id"`
	Username    string    `json:"username"`
	AccessToken string    `json:"access_token"`
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

func ValidateUserInput(userInfo *UserInfo) (bool, error) {
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
		userInfo.PhoneNumber = cleaned
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
		UserID:   user.UserID.String(),
		Username: user.Username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(365 * 24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
		},
	}

	// Create the token with claims and sign it
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(getJWTSecret()))
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

func validateJWT(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return []byte(getJWTSecret()), nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("invalid token")
}

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
			c.Abort()
			return
		}

		if !strings.HasPrefix(authHeader, "Bearer ") {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid authorization format"})
			c.Abort()
			return
		}

		token := strings.TrimPrefix(authHeader, "Bearer ")

		claims, err := validateJWT(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}

		// Store user info in context
		c.Set("user_id", claims.UserID)
		c.Set("username", claims.Username)

		c.Next()
	}
}

func HashPassword(password string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), 12)
	if err != nil {
		return "", err
	}
	return string(hash), nil
}

func LoginUser(c *gin.Context) {
	var user UserInfo
	err := c.ShouldBindJSON(&user)

	db := c.MustGet("db").(*pgxpool.Pool)
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()

	if err != nil {
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	var query string

	_, err = ValidateUserInput(&user)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
		return
	}

	var id string
	var passwordHash string

	if user.Username != "" {
		id = strings.TrimSpace(user.Username)
		query = `
			SELECT user_id, username, password_hash FROM users WHERE LOWER(username) = LOWER($1);
		`
	} else if user.Email != "" {
		id = strings.TrimSpace(strings.ToLower(user.Email))
		query = `
			SELECT user_id, username, password_hash FROM users WHERE LOWER(email) = LOWER($1);
		`
	} else {
		id = strings.TrimSpace(user.PhoneNumber)
		query = `
			SELECT user_id, username, password_hash FROM users WHERE phone_number = $1;
		`
	}

	var success AuthResponse

	err = db.QueryRow(ctx, query, id).Scan(&success.UserID, &success.Username, &passwordHash)

	if err != nil {
		if err == pgx.ErrNoRows {
			c.IndentedJSON(http.StatusNotFound, nil)
			return
		}

		fmt.Printf("Database error: %v\n", err)
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	user.UserID = success.UserID
	user.Username = success.Username

	err = bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(user.Password))
	if err != nil {
		fmt.Println("Wrong Password!")
		c.IndentedJSON(http.StatusUnauthorized, nil)
		return
	}

	success.AccessToken, err = GenerateJWT(user)
	if err != nil {
		c.IndentedJSON(http.StatusInternalServerError, nil)
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

	if err != nil {
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	_, err = ValidateUserInput(&user)

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, nil)
	}

	passwordHash, err := HashPassword(user.Password)

	if err != nil {
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	query := `
		SELECT username FROM users WHERE username = $1 OR phone_number = $2 OR email = $3;
	`

	err = db.QueryRow(ctx, query, user.Username, user.PhoneNumber, user.Email).Scan()

	if err != nil && err != pgx.ErrNoRows {
		c.IndentedJSON(http.StatusConflict, nil)
		return
	}

	query = `
		INSERT INTO users (username, email, password_hash, name, phone_number)
		VALUES ($1, $2, $3, $4, $5) RETURNING user_id;
	`

	var userID uuid.UUID

	err = db.QueryRow(ctx, query, user.Username, user.Email, passwordHash, user.Name, user.PhoneNumber).Scan(&userID)

	if err != nil {
		c.IndentedJSON(http.StatusInternalServerError, err.Error())
		return
	}

	success := AuthResponse{
		Username: user.Username,
	}

	user.UserID = success.UserID
	user.Username = success.Username

	success.AccessToken, err = GenerateJWT(user)
	success.UserID = userID

	if err != nil {
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	c.IndentedJSON(http.StatusCreated, success)
}
