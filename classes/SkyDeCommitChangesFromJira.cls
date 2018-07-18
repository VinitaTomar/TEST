/*------------------------------------------------------------
Author: Stefano Pramparo
Company: Sky Deutschland
Description: integrate Jira with Copado: 
 1. starting from a user story retrieve related Jira sub-task
 2. read from description field list of metadata do be deployed Metadata Type,Metadata Name i.e.
 	CustomApplication,Service_Console_with_LiveMessanger
 	RecordType,Contact.LiveMessage
 3. invoke Copado Heroku interface
 4. close Jira sub-task (change to stauts Done) and post Copado output
Inputs: "userStoryId" copado user story Id
Test Class: SkyDeCommitChangesFromJiraTest
History
20180717 PRAM01 Initial creation
------------------------------------------------------------*/
global with sharing class SkyDeCommitChangesFromJira {
    
    private static HTTPResponse copadoResponse;
    private static final String SEARCH_CRITERIA='search?jql=issuetype=Sub-task%20and%20status!=Done%20and%20status!=Resolved%20and%20parent=';
    private static Change_Management_Integration_Credential__c  jiraCredential;
    private static String  jiraAuthorizationHeader;
    
    /*------------------------------------------------------------ 
	Author: Stefano Pramparo
	Company: Sky Deutschland
    Description: retrieve Copado Change Management Integration related to the copado project
    Inputs: "userStory" current user story 
    Returns: Change_Management_Integration_Credential__c related to the project (Jira integration end point)
    History 
    20180717 PRAM01 Initial creation 
    ------------------------------------------------------------*/
    private static Change_Management_Integration_Credential__c getCredentials(copado__User_Story__c userStory){
        List<copado__Project__c> projects = [select Change_Management_Integration__r.Id,Change_Management_Integration__r.name,
                                             Change_Management_Integration__r.Endpoint__c, Change_Management_Integration__r.External_System__c, 
                                             Change_Management_Integration__r.Username__c, Change_Management_Integration__r.Password__c
                                             from copado__Project__c
                                             where Id=:userStory.copado__Project__c];
        return (Change_Management_Integration_Credential__c) (projects.get(0).Change_Management_Integration__r);
    }
    /*------------------------------------------------------------ 
	Author: Stefano Pramparo
	Company: Sky Deutschland
    Description: build Jira json Header for autheticate 
    Inputs: "credential" Change_Management_Integration_Credential__c with username and password 
    Returns: jira authorization String
    History 
    20180717 PRAM01 Initial creation 
    ------------------------------------------------------------*/
    private static String getAuthorization(Change_Management_Integration_Credential__c credential){
        Blob headerValue = Blob.valueOf(credential.Username__c + ':' + EncodingUtil.base64Decode(credential.Password__c).toString());
        return 'Basic ' + EncodingUtil.base64Encode(headerValue);
    }
     /*------------------------------------------------------------ 
	Author: Stefano Pramparo
	Company: Sky Deutschland
    Description: build Jira rl to retrieve sub-task related to use story  
    Inputs: "endPoint" jira address i.e. https://jira.sky.de/rest/api/2/
    "userStory"  copado user story containing Jira id
    Returns: jira jql search
    History 
    20180717 PRAM01 Initial creation 
    ------------------------------------------------------------*/
    private static String getURL(copado__User_Story__c userStory,String endPoint){
        return endPoint+ SEARCH_CRITERIA+userStory.External_Id__c;   	
    }
     /*------------------------------------------------------------ 
	Author: Stefano Pramparo
	Company: Sky Deutschland
    Description: retrieve sub-tasks related to use story from Jira  
    Inputs: "userStory"  copado user story
    Returns: sub-taks from Jira
    History 
    20180717 PRAM01 Initial creation 
    ------------------------------------------------------------*/
    private static List<Object> getJiraSubTask(copado__User_Story__c userStory){
        jiraCredential = getCredentials(userStory);
        jiraAuthorizationHeader = getAuthorization(jiraCredential);
        String url = getURL(userStory,jiraCredential.Endpoint__c);
        System.debug('url '+url);
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setHeader('Authorization',  jiraAuthorizationHeader);
        req.setHeader('Content-Type', 'application/json');
        Http http = new Http();
        HTTPResponse res = http.send(req);        
        String body = res.getBody();
        System.debug(body);        
        Map<String, Object> deserialized = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> c = (List<Object>)deserialized.get('issues'); 
        return c;
    }
    /*------------------------------------------------------------ 
	Author: Stefano Pramparo
	Company: Sky Deutschland
    Description: invoke Copado heroku interface to commit changes  see https://copado.docs.apiary.io/#
    Inputs: "userStoryName"  user story name
    Returns: url to be invoked i.e.
    https://copado.herokuapp.com/json/v1/webhook/commitFiles/user_story_id?api_key=user_api_key&commitMessage=commitMessage , where user_story_id=userStoryName
    History 
    20180717 PRAM01 Initial creation 
    ------------------------------------------------------------*/
    private static String getCopadoUrl(String userStoryName){
        SkyDeJiraCopadoIntegration__mdt meta =[select Key__c,URL__c from SkyDeJiraCopadoIntegration__mdt where MasterLabel='Copado Data'];
        return meta.URL__c+'/json/v1/webhook/commitFiles/'+userStoryName+'?api_key='+meta.Key__c+'&commitMessage='+userStoryName;
    }    
    /*------------------------------------------------------------ 
	Author: Stefano Pramparo
	Company: Sky Deutschland
    Description: parse jira descpriton field
    Inputs: "description" value of jira description field
    Returns: json arry of metada objects (see https://copado.docs.apiary.io/#)    
    	[
  			{
    			"n": "MyApexClass",
    			"r": false,
    			"t": "ApexClass"
  			},
  			{
    			"n": "SysAdmin",
				"r": false,
    			"t": "Profile"
  			}....
		]
		to commit
    History 
    20180717 PRAM01 Initial creation 
    ------------------------------------------------------------*/
    private static String parseDesscription(String description){
        String[] pair =description.split('\\n');
        JSONGenerator gen = JSON.createGenerator(true);         
        gen.writeStartArray();
        for(Integer i=0;i<pair.size();i++){
            String[] typeName = pair[i].split(',');
            if(typeName.size()==2){
                gen.writeStartObject();
                gen.writeStringField('n',typeName[1].trim());
                gen.writeStringField('r','false');
                gen.writeStringField('t',typeName[0].trim());    
                gen.writeEndObject();
            }
        }
        gen.writeEndArray();
        return gen.getAsString();
    }
      /*------------------------------------------------------------ 
	Author: Stefano Pramparo
	Company: Sky Deutschland
    Description: invoke Copado's heroku interface
    Inputs: "userStoryName" user story name 
    "jsonBodies" json arry of metada objects (see https://copado.docs.apiary.io/#)   
    Returns: copado response
    History 
    20180717 PRAM01 Initial creation 
    ------------------------------------------------------------*/
    private static HTTPResponse invokeCopadoHeroku(String userStoryName,String jsonBodies){
        HttpRequest req = new HttpRequest();
        String copado =getCopadoUrl(userStoryName);
        req.setEndpoint(getCopadoUrl(userStoryName));
        req.setMethod('POST');
        Http http = new Http();
        System.debug('body req: '+jsonBodies);
        req.setbody(jsonBodies);
        copadoResponse = http.send(req);            
        System.debug('Body resp: '+copadoResponse.getBody());               
        return copadoResponse;
    }
     /*------------------------------------------------------------ 
	Author: Stefano Pramparo
	Company: Sky Deutschland
    Description: return copado response, used for testing
    Inputs: n/a   
    Returns: copado response
    History 
    20180717 PRAM01 Initial creation 
    ------------------------------------------------------------*/
    public static HTTPResponse getCopadoResponse(){
        return copadoResponse;
    }
     /*------------------------------------------------------------ 
	Author: Stefano Pramparo
	Company: Sky Deutschland
    Description: create commit point from user story Id
    Inputs: "userStoryId"  user story Id
    Returns: 
    History 
    20180717 PRAM01 Initial creation 
    20180718 PRAM01 add return message
    ------------------------------------------------------------*/
    webservice  static String createCommitChange(Id userStoryId){
        System.debug('userstory id '+userStoryId);
        copado__User_Story__c userStory = [select Id,copado__Project__c,Name,External_Id__c from copado__User_Story__c where Id=:userStoryId];
        List<Object> jiraSubTasks=getJiraSubTask(userStory);        
        if(jiraSubTasks.isEmpty()){
            return 'No subtask found';
        }
        for(Object myJiraTask : jiraSubTasks) {
            Map<String,Object> i = (Map<String, Object>)myJiraTask;
            System.debug('myJiraTask '+myJiraTask);
            String description=(String)(( Map<String,Object>)i.get('fields')).get('description');            
            System.debug('description: '+description);
            if(description.length()==0){
                return 'description empty';                
            }
            copadoResponse= invokeCopadoHeroku(userStory.Name,parseDesscription(description));
            closeJiraIssue((String)i.get('key'), copadoResponse.getBody(),jiraAuthorizationHeader,jiraCredential.Endpoint__c);     
        }  
        return copadoResponse.getBody();   
    }
     /*------------------------------------------------------------ 
	Author: Stefano Pramparo
	Company: Sky Deutschland
    Description: update Jira issue changing status to Done and add as comment copado outcome 
    Inputs: "jiraId"  jira subtask Id
    "copadoResponse" outcome from Copado
    "jiraAuthorization" jira credential header
    "endPoint" jira end point
    Returns: n/a
    History 
    20180717 PRAM01 Initial creation 
    ------------------------------------------------------------*/
    @Future(callout=true)
    public static void closeJiraIssue(String jiraId,String copadoResponse,String jiraAuthorization,String endPoint){
        HttpRequest req = new HttpRequest();        
        req.setMethod('POST');
        req.setHeader('Authorization',  jiraAuthorization);
        req.setHeader('Content-Type', 'application/json');
        JSONGenerator gen = JSON.createGenerator(true);         
        gen.writeStartObject();
        gen.writeStringField('body',copadoResponse);
        gen.writeEndObject();
        String url = endPoint+'issue/'+jiraId+'/comment';
        System.debug('close jira url '+url);
        req.setEndpoint(url);
        req.setBody(gen.getAsString());
        Http http = new Http();
        HTTPResponse res = http.send(req);        
		url = endPoint+'issue/'+jiraId+'/transitions';
        System.debug('close jira url '+url);
        req.setEndpoint(url);
        req.setBody('{\"transition\":{\"id\":\"41\"}}');
        http.send(req);
        System.debug(res.getBody());
    }
}