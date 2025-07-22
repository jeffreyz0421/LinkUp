package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	urllib "net/url"
)

const APIToken = "pk.eyJ1IjoiamF3YWFkZGQiLCJhIjoiY21jeTNwazUwMDJjbDJzcTdiazlwMHVrcyJ9.hSajXJrSI6fgUeQi9z8nZQ"

func addURLParameter(url string, parameters map[string]string) string {
	url = url + "?"
	for parameter, value := range parameters {
		url += urllib.QueryEscape(parameter) + "=" + urllib.QueryEscape(value) + "&"
	}
	return url[:len(url)-1]
}

func printJSON(data []byte) {
	var prettyJSON bytes.Buffer
	err := json.Indent(&prettyJSON, data, "", "  ")
	if err != nil {
		fmt.Println("Error formatting JSON:", data)
		return
	}
	fmt.Println(prettyJSON.String())
}

func main() {
	// PrintCategories()
	// PrintPOIsByCategory("restaurant")

	GetPlaceDetails("ChIJtUuxMUiuPIgROs6lhMIGkLE")

	// GetPlaces()
}

type Center struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type Circle struct {
	Center Center  `json:"center"`
	Radius float64 `json:"radius"`
}

type LocationRestriction struct {
	Circle Circle `json:"circle"`
}

type GetPlaceRequest struct {
	MaxResultCount      int                 `json:"maxResultCount"`
	LocationRestriction LocationRestriction `json:"locationRestriction"`
	IncludedTypes       []string            `json:"includedTypes"`
}

func PrintPOIsByCategory(category string) {
	apiURL := "https://api.mapbox.com/search/searchbox/v1/category/" + category

	// category := "restaurant"
	userLocation := "-83.741235,42.272479"

	parameters := map[string]string{
		"access_token": APIToken,
		"proximity":    userLocation,
		"limit":        "5",
	}

	apiURL = addURLParameter(apiURL, parameters)

	fmt.Println(apiURL)

	resp, err := http.Get(apiURL)

	if err != nil {
		fmt.Println("Error: " + err.Error())
	}

	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)

	if err != nil {
		fmt.Println("Error: " + err.Error())
		return
	}

	printJSON(body)
}

func PrintCategories() {
	apiURL := "https://api.mapbox.com/search/searchbox/v1/list/category"

	parameters := map[string]string{
		"access_token": APIToken,
	}

	apiURL = addURLParameter(apiURL, parameters)

	resp, err := http.Get(apiURL)

	if err != nil {
		fmt.Println("Error: " + err.Error())
	}

	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)

	if err != nil {
		fmt.Println("Error: " + err.Error())
	}

	printJSON(body)
}

func GetPlaces() {
	apiURL := "https://places.googleapis.com/v1/places:searchNearby"

	// placeID := c.Request.URL.Query()["placeid"]

	body := GetPlaceRequest{
		LocationRestriction: LocationRestriction{
			Circle: Circle{
				Center: Center{
					Latitude:  42.270328,
					Longitude: -83.740981,
				},
				Radius: 500.0,
			},
		},
		MaxResultCount: 5,
		IncludedTypes:  []string{"restaurant"},
	}

	// apiURL = addURLParameter(apiURL, parameters)

	requestData, err := json.Marshal(&body)

	if err != nil {
		fmt.Print("Errror :(")
	}

	req, err := http.NewRequest("POST", apiURL, bytes.NewBuffer(requestData))

	if err != nil {
		fmt.Println(err.Error())
	}

	req.Header.Add("X-Goog-Api-Key", "AIzaSyAJc6D-3f-Y7GXrTmTW9nUXVbYWFkdR2vA")
	req.Header.Add("X-Goog-FieldMask", "places.id,places.displayName,places.shortFormattedAddress")

	resp, err := http.DefaultClient.Do(req)

	if err != nil {
		fmt.Println("Couldn't retrieve place details :(")

	}

	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)

	if err != nil {
		fmt.Println(err.Error())
	}

	fmt.Println(string(respBody))
}

func GetPlaceDetails(placeID string) {
	apiURL := "https://places.googleapis.com/v1/places/"

	apiURL += placeID

	req, err := http.NewRequest("GET", apiURL, nil)

	if err != nil {
		fmt.Println("Error getting place details: " + err.Error())
	}

	req.Header.Add("X-Goog-Api-Key", "AIzaSyClvQe_d7EannidrZ64K-Jn6W3cwIStJQk")
	req.Header.Add("X-Goog-FieldMask", "photos,displayName,rating,userRatingCount,shortFormattedAddress")

	resp, err := http.DefaultClient.Do(req)

	if err != nil {
		fmt.Println("Couldn't retrieve place details :(")

	}

	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)

	// var placeDetails PlaceDetails
	// json.Unmarshal(body, &placeDetails)

	fmt.Println(string(body))

}
