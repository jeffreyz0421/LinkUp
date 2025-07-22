package api

import (
	urllib "net/url"
)

func addURLParameter(url string, parameters map[string]string) string {
	url = url + "?"
	for parameter, value := range parameters {
		url += urllib.QueryEscape(parameter) + "=" + urllib.QueryEscape(value) + "&"
	}
	return url[:len(url)-1]
}
