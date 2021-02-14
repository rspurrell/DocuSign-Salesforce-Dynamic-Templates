@isTest
global class MockHttpResponse implements HttpCalloutMock
{
    private Map<String, Map<String, MethodResponse>> endpointMethodResponses = null;

    global MockHttpResponse()
    {
        endpointMethodResponses = new Map<String, Map<String, MethodResponse>>();
    }

    global MockHttpResponse(String body)
    {
        this('application/json', body);
    }

    global MockHttpResponse(String contentType, String body)
    {
        this(200, contentType, body);
    }

    global MockHttpResponse(Integer statusCode, String contentType, String body)
    {
        this();
        AddEndpointMethodResponse('.', 'GET', statusCode, contentType, body);
    }

    // endpointUri and method are case sensitive
    global void AddEndpointMethodResponse(String endpointUri, String method, Integer statusCode, String contentType, String body)
    {
        System.debug('ADDING ENDPOINT METHOD RESPONSE. Endpoint URI: ' + endpointUri + ' - METHOD: ' + method + ' - Status Code: ' + statusCode + ' - Content Type: ' + contentType);
        if (!endpointMethodResponses.containsKey(endpointUri))
        {
            endpointMethodResponses.put(endpointUri, new Map<String, MethodResponse>());
        }
        Map<String, MethodResponse> er = endpointMethodResponses.get(endpointUri);
        er.put(method, new MethodResponse(statusCode, contentType, body));
    }

    // HttpCalloutMock interface method
    global HTTPResponse respond(HTTPRequest req)
    {
        String reqEndpoint = req.getEndpoint();
        String reqMethod = req.getMethod();
        if (req.getHeader('X-HTTP-Method-Override') != null)
        {
            reqMethod = req.getHeader('X-HTTP-Method-Override');
        }

        if (!endpointMethodResponses.containsKey(reqEndpoint) || !endpointMethodResponses.get(reqEndpoint).containsKey(reqMethod))
        {
            System.debug('MOCK ENDPOINT NOT FOUND: ' + reqMethod + ' ' + reqEndpoint);
            if (!endpointMethodResponses.containsKey('.') || !endpointMethodResponses.get('.').containsKey('GET'))
            {
                throw new CustomException('MOCK ENDPOINT NOT FOUND: ' + reqMethod + ' ' + reqEndpoint);
            }
            reqEndpoint = '.';
            reqMethod = 'GET';
        }
        MethodResponse mr = endpointMethodResponses.get(reqEndpoint).get(reqMethod);

        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', mr.ContentType);
        res.setStatusCode(mr.StatusCode);
        if (String.isNotEmpty(mr.Body))
        {
            res.setBody(mr.Body);
        }
        return res;
    }

    private class MethodResponse
    {
        public String Body { get; private set; }
        public String ContentType { get; private set; }
        public Integer StatusCode { get; private set; }

        public MethodResponse(Integer statusCode, String contentType, String body)
        {
            this.Body = body;
            this.ContentType = contentType;
            this.StatusCode = statusCode;
        }
    }
}