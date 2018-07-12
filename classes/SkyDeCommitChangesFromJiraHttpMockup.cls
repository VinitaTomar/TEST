@IsTest
global class SkyDeCommitChangesFromJiraHttpMockup implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        if(req.getEndpoint().contains('jira'))
            res.setBody('{"issues": [{"description": "CustomField,Account.Name\\nCustomField,Account.Name"}]}');
        else 
            res.setBody('{"ok": "Webhook accepted","status": "Queued","copadoJobId": "1c291f11-d0e8-46a9-bb7a-5132988ae4Ab"}');
        res.setStatusCode(200);
        return res;               
    }
}