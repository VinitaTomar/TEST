global with sharing class SkyDeCommitChangesFromJira {
    private static List<HTTPResponse> copadoResponse;
    private static final String SEARCH_CRITERIA='search?jql=issuetype=Sub-task%20and%20status!=Closed%20and%20status!=Resolved%20andparent=';
    
    private static Change_Management_Integration_Credential__c getCredentials(copado__User_Story__c userStory){
        List<copado__Project__c> cred = [select Change_Management_Integration__r.Id,Change_Management_Integration__r.name,
                                         Change_Management_Integration__r.Endpoint__c, Change_Management_Integration__r.External_System__c, 
                                         Change_Management_Integration__r.Username__c, Change_Management_Integration__r.Password__c
                                         from copado__Project__c
                                         where Id=:userStory.copado__Project__c];
        return (Change_Management_Integration_Credential__c) (cred.get(0).Change_Management_Integration__r);
    }
    private static String getAuthorization(Change_Management_Integration_Credential__c credential){
        Blob headerValue = Blob.valueOf(credential.Username__c + ':' + EncodingUtil.base64Decode(credential.Password__c).toString());
        return 'Basic ' + EncodingUtil.base64Encode(headerValue);
    }
    private static String getURL(copado__User_Story__c userStory,String endPoint){
        return endPoint+ SEARCH_CRITERIA+userStory.External_Id__c;   	
    }
    
    private static List<Object> getJiraSubTask(copado__User_Story__c userStory){
        Change_Management_Integration_Credential__c cred = getCredentials(userStory);
        String authorizationHeader = getAuthorization(cred);
        String url = getURL(userStory,cred.Endpoint__c);
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setHeader('Authorization', authorizationHeader);
        req.setHeader('Content-Type', 'application/json');
        Http http = new Http();
        HTTPResponse res = http.send(req);
        Map<String, Object> deserialized = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> c = (List<Object>)deserialized.get('issues'); 
        return c;
    }
    private static String getCopadoUrl(String userStoryName){
        SkyDeJiraCopadoIntegration__mdt meta =[select Key__c,URL__c from SkyDeJiraCopadoIntegration__mdt where MasterLabel='Copado Data'];
        return meta.URL__c+'/json/v1/webhook/commitFiles/'+userStoryName+'?api_key='+meta.Key__c+'&commitMessage='+userStoryName;
    }    
    private static String parseDesscription(String description){
        String[] pair =description.split('\\n');
        JSONGenerator gen = JSON.createGenerator(true); 
        for(Integer i=0;i<pair.size();i++){
            String[] typeName = pair[i].split(',');
            if(typeName.size()==2){
                gen.writeStartObject();
                gen.writeStringField('n',typeName[1].trim());
                gen.writeStringField('r','true');
                gen.writeStringField('t',typeName[0].trim());
                gen.writeEndObject();
            }
        }
        return gen.getAsString();
    }
    private static List<HTTPResponse> invokeCopadoHeroku(String userStoryName,List<String> jsonBodies){
        HttpRequest req = new HttpRequest();
        String copado =getCopadoUrl(userStoryName);
        req.setEndpoint(getCopadoUrl(userStoryName));
        req.setMethod('POST');
        List<HTTPResponse> responseList = new  List<HTTPResponse>();
        for(String s: jsonBodies ){
            req.setbody(s);
            Http http = new Http();
            HTTPResponse response = http.send(req);
            responseList.add(response);
        }
        return responseList;
    }
    public static List<HTTPResponse> getCopadoResponse(){
        return copadoResponse;
    }
    webservice static void createCommitChange(copado__User_Story__c userStory){
        List<Object> jiraSubTasks=getJiraSubTask(userStory);
        List<String> jsonBodies = new List<String>();
        for(Object myJiraTask : jiraSubTasks) {
            Map<String,Object> i = (Map<String, Object>)myJiraTask;
            String description=(string)i.get('description');
            jsonBodies.add(parseDesscription(description));            
            copadoResponse= invokeCopadoHeroku(userStory.Name,jsonBodies);            
        }
    }
    }