package api

import (
	urllib "net/url"

	"github.com/gin-gonic/gin"
)

func UpdateLastLocationMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		lastLocation := c.GetHeader("Location")
		if lastLocation != "" {
			c.Set("last_location", lastLocation)
		}
		c.Next()
	}
}

func addURLParameter(url string, parameters map[string]string) string {
	url = url + "?"
	for parameter, value := range parameters {
		url += urllib.QueryEscape(parameter) + "=" + urllib.QueryEscape(value) + "&"
	}
	return url[:len(url)-1]
}
