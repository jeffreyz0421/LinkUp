package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
)

const APIToken = ""

func addURLParameter(url string, parameters map[string]string) string {
	for parameter, value := range parameters {
		url += "?" + parameter + "=" + value
	}
	return url
}

func main() {
	PrintCategories()
}

func PrintCategories() {
	apiURL := "https://api.mapbox.com/search/searchbox/v1/list/category"
	parameters := make(map[string]string)

	parameters["access_token"] = url.QueryEscape(APIToken)

	apiURL = addURLParameter(apiURL, parameters)

	resp, err := http.Get(apiURL)

	if err != nil {
		fmt.Println(err.Error())
	}

	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)

	if err != nil {
		fmt.Println("Error: " + err.Error())
	}

	var prettyJSON bytes.Buffer
	err = json.Indent(&prettyJSON, body, "", "  ")
	if err != nil {
		fmt.Println("Error formatting JSON:", err)
		return
	}
	fmt.Println(prettyJSON.String())
}
