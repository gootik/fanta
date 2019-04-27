const http = require('http')
const port = 3000

const requestHandler = (request, response) => {
      console.log(request.url)
      response.end('{"id": "SERVER1","bidid": "6b56744d","seatbid": [{"seat": "ad_agency_1","bid": [{"impid": "1","price": 0.5,"id": "793b7bff","adm": "{\"native\":{\"link\":{\"url\":\"http://i.am.a/URL\"},\"assets\":[{\"id\":1,\"required\":1,\"title\":{\"text\":\"Title\"}},{\"id\":3,\"required\":1,\"img\":{\"url\":\"http://adserver.com/image\"}},{\"id\":2,\"required\":1,\"img\":{\"url\":\"http://contentsource.net/image\"}},{\"id\":4,\"required\":1,\"data\":{\"value\":\"Description\"}},{\"id\":5,\"required\":1,\"data\":{\"value\":\"CTA Text.\"}}]}}","adomain": ["http://adserver.com"],"crid": "16969426","cid": "2445","iurl": "http://adserver.com/images/image.png","nurl": "http://adserver.com/winnotice/win"}]}]}');
}

const server = http.createServer(requestHandler)

server.listen(port, (err) => {
      if (err) {
              return console.log('something bad happened', err)
            }

      console.log(`server is listening on ${port}`)
})
