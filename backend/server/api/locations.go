package api

import (
	"fmt"
	"io"
	"net/http"

	"bytes"
	"encoding/json"

	"github.com/gin-gonic/gin"
	// "github.com/google/uuid"
)

const (
	GoogleAPIKey = "AIzaSyClvQe_d7EannidrZ64K-Jn6W3cwIStJQk"
)

type PlaceDetails struct {
	PlaceID               string
	DisplayName           string
	ShortFormattedAddress string
	Rating                float32
	UserRatingCount       int
}

func GetPlaceDetails(c *gin.Context) {
	apiURL := "https://places.googleapis.com/v1/places/"

	if !c.Request.URL.Query().Has("placeid") {
		c.IndentedJSON(http.StatusBadRequest, nil)
	}

	placeID := c.Request.URL.Query()["placeid"]

	apiURL += placeID[0]

	req, err := http.NewRequest("GET", apiURL, nil)

	if err != nil {
		fmt.Println("Error: " + err.Error())
	}

	req.Header.Add("X-Goog-Api-Key", GoogleAPIKey)
	req.Header.Add("X-Goog-FieldMask", "displayName,rating,userRatingCount,shortFormattedAddress")

	// TODO -- Return list of images (URLS) of the place

	resp, err := http.DefaultClient.Do(req)

	if err != nil {
		fmt.Println("Error making the Google API call to retrieve place details... :(")
		c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	// resp, err = http.Get(apiURL)

	// if err != nil {
	// 	fmt.Println("Couldn't retrieve place details :(")

	// }

	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)

	if err != nil {
		fmt.Println("Error: " + err.Error())
	}

	var placeDetails PlaceDetails
	json.Unmarshal(body, &placeDetails)

	c.IndentedJSON(http.StatusOK, placeDetails)
}

func TestFeatureRetrieval() {
	apiURL := "https://places.googleapis.com/v1/places/"

	placeID := "ChIJtUuxMUiuPIgROs6lhMIGkLE"

	apiURL += placeID

	req, err := http.NewRequest("GET", apiURL, nil)

	if err != nil {
		fmt.Println("Error: " + err.Error())
	}

	req.Header.Add("X-Goog-Api-Key", GoogleAPIKey)
	req.Header.Add("X-Goog-FieldMask", "displayName,rating,userRatingCount,shortFormattedAddress,photos")

	// TODO -- Return list of images (URLS) of the place

	resp, err := http.DefaultClient.Do(req)

	if err != nil {
		fmt.Println("Error making the Google API call to retrieve place details... :(")
		// c.IndentedJSON(http.StatusInternalServerError, nil)
		return
	}

	// resp, err = http.Get(apiURL)

	// if err != nil {
	// 	fmt.Println("Couldn't retrieve place details :(")

	// }

	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)

	if err != nil {
		fmt.Println("Error: " + err.Error())
	}

	var placeDetails PlaceDetails

	json.Unmarshal(body, &placeDetails)

	fmt.Println(string(body))

	// c.IndentedJSON(http.StatusOK, placeDetails)
}

type Coordinates struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type Center = Coordinates

type Circle struct {
	Center Center  `json:"center"`
	Radius float64 `json:"radius"`
}

type LocationBias struct {
	Circle Circle `json:"circle"`
}

type NearbySearchBody struct {
	PageSize     int          `json:"pageSize"`
	LocationBias LocationBias `json:"locationBias"`
	TextQuery    string       `json:"textQuery"`
}

type Place struct {
	PlaceID string `json:"id"`
}

type PlaceList struct {
	Places []Place `json:"places"`
}

func GetPlaceID(placeName string, coordinates Center) string {
	apiURL := "https://places.googleapis.com/v1/places:searchText"

	bodyData := NearbySearchBody{
		PageSize: 1,
		LocationBias: LocationBias{
			Circle: Circle{
				Center: coordinates,
				Radius: 200,
			},
		},
		TextQuery: placeName,
	}

	body, err := json.Marshal(bodyData)

	if err != nil {
		fmt.Println("GetPlaceID Error Binding data to request body: " + err.Error())
	}

	req, err := http.NewRequest("POST", apiURL, bytes.NewBuffer(body))

	if err != nil {
		return ""
	}

	req.Header.Add("X-Goog-Api-Key", GoogleAPIKey)
	req.Header.Add("X-Goog-FieldMask", "places.id")
	req.Header.Add("Content-Type", "application/json")
	// req.Header.Add("textQuery", placeName)

	resp, err := http.DefaultClient.Do(req)

	if err != nil {
		fmt.Println("Failed to retrieve a place's ID :(")
		return ""
	}

	defer resp.Body.Close()

	body, err = io.ReadAll(resp.Body)

	if err != nil {
		fmt.Println("Error: " + err.Error())
		return ""
	}

	var respData PlaceList
	err = json.Unmarshal(body, &respData)
	if err != nil {
		fmt.Println("Error: " + err.Error())
	}

	return respData.Places[0].PlaceID
}
