package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"regexp"
	"strings"

	"golang.org/x/crypto/bcrypt"
	_ "github.com/lib/pq" // PostgreSQL driver
)

type User struct {
	ID           string `json:"id,omitempty"`
	Username     string `json:"username"`
	Email        string `json:"email"`
	Password     string `json:"password,omitempty"`     // Only for input
	PasswordHash string `json:"-"`                      // Never send to frontend
	Name         string `json:"name"`
	PhoneNumber  string `json:"phone_number"`
}

type SignupRequest struct {
	Username    string `json:"username"`
	Email       string `json:"email"`
	Password    string `json:"password"`
	Name        string `json:"name"`
	PhoneNumber string `json:"phone_number"`
}

type SignupResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	UserID  string `json:"user_id,omitempty"`
}

type Server struct {
	db *sql.DB
}

func NewServer(db *sql.DB) *Server {
	return &Server{db: db}
}

// Validation helpers
func isValidEmail(email string) bool {
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	return emailRegex.MatchString(email)
}

func isValidPhoneNumber(phone string) bool {
	// Assuming US phone format: 10 digits
	phoneRegex := regexp.MustCompile(`^\d{10}$`)
	return phoneRegex.MatchString(phone)
}

func (s *Server) signupHandler(w http.ResponseWriter, r *http.Request) {
	// Set CORS headers (adjust origins as needed)
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	w.Header().Set("Content-Type", "application/json")

	// Handle preflight OPTIONS request
	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req SignupRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondWithError(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Validation
	if strings.TrimSpace(req.Username) == "" {
		respondWithError(w, "Username is required", http.StatusBadRequest)
		return
	}
	if len(req.Username) > 50 {
		respondWithError(w, "Username too long (max 50 characters)", http.StatusBadRequest)
		return
	}
	if !isValidEmail(req.Email) {
		respondWithError(w, "Invalid email format", http.StatusBadRequest)
		return
	}
	if len(req.Password) < 8 {
		respondWithError(w, "Password must be at least 8 characters", http.StatusBadRequest)
		return
	}
	if strings.TrimSpace(req.Name) == "" {
		respondWithError(w, "Name is required", http.StatusBadRequest)
		return
	}
	if !isValidPhoneNumber(req.PhoneNumber) {
		respondWithError(w, "Phone number must be 10 digits", http.StatusBadRequest)
		return
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("Error hashing password: %v", err)
		respondWithError(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	// Insert user into database
	var userID string
	query := `
		INSERT INTO users (username, email, password_hash, name, phone_number) 
		VALUES ($1, $2, $3, $4, $5) 
		RETURNING id`

	err = s.db.QueryRow(query, req.Username, req.Email, string(hashedPassword), req.Name, req.PhoneNumber).Scan(&userID)
	if err != nil {
		log.Printf("Error inserting user: %v", err)
		
		// Check for unique constraint violations
		if strings.Contains(err.Error(), "username") {
			respondWithError(w, "Username already exists", http.StatusConflict)
			return
		}
		if strings.Contains(err.Error(), "email") {
			respondWithError(w, "Email already exists", http.StatusConflict)
			return
		}
		if strings.Contains(err.Error(), "phone_number") {
			respondWithError(w, "Phone number already exists", http.StatusConflict)
			return
		}
		
		respondWithError(w, "Failed to create user", http.StatusInternalServerError)
		return
	}

	// Success response
	response := SignupResponse{
		Success: true,
		Message: "User created successfully",
		UserID:  userID,
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(response)
}

func respondWithError(w http.ResponseWriter, message string, statusCode int) {
	response := SignupResponse{
		Success: false,
		Message: message,
	}
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(response)
}

func main() {
	// Database connection
	dbURL := "postgres://username:password@localhost/dbname?sslmode=disable"
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer db.Close()

	// Test database connection
	if err := db.Ping(); err != nil {
		log.Fatal("Failed to ping database:", err)
	}

	server := NewServer(db)

	// Routes
	http.HandleFunc("/api/signup", server.signupHandler)

	// Health check endpoint
	http.HandleFunc("/api/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})

	fmt.Println("Server starting on :8080...")
	log.Fatal(http.ListenAndServe(":8080", nil))
}