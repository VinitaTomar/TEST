/*------------------------------------------------------------
Author: Stefano Pramparo
Company: Sky Deutschland
Description: test case class to verify copado/jira integration
1 - deserializeTest() deserialize description field from jira
2- jiraIntegrationTest simulate integration with jira
History
20180717 PRAM01 Initial creation
------------------------------------------------------------*/
@isTest
private class SkyDeCommitChangesFromJiraTest {    
    static copado__User_Story__c buildData(){
        Change_Management_Integration_Credential__c credential = new Change_Management_Integration_Credential__c(
            Authentication_Method__c='Basic Authentication',
            Endpoint__c='https://jira.sky.de/rest/api/2/',
            Name='JIRA',
            Password__c='A',
            Username__c='B'
        );
        insert credential;
        copado__Project__c project = new copado__Project__c(
            External_Id__c='A',
            Name='A',         
            Change_Management_Integration__c=credential.Id
        );
        insert project;        
        copado__User_Story__c userStory = new copado__User_Story__c(
            External_Id__c='99253',
            copado__Project__c=project.Id
        ); 
        insert userStory; 
        return userStory;
    }
    @isTest
    static void deserializeTest(){
        Map<String,Object> myMap = (Map<String, Object>) JSON.deserializeUntyped('{"issues": [{"description": "CustomField,Account.Name\\nCustomField,Account.Name"}]}');
        System.assert(!((List<Object>)myMap.get('issues')).isEmpty());
        List<Object> issueList = (List<Object>)myMap.get('issues');
        for(Object issue : issueList){
            Map<String,Object> i = (Map<String, Object>)issue;
            String description=(String)i.get('description');
            System.assertNotEquals(0, description.length());
        }
    }
    @isTest
    static void jiraIntegrationTest() {                
        copado__User_Story__c userStory= buildData();
        Test.startTest();
        Test.setMock(HttpCalloutMock.class,new SkyDeCommitChangesFromJiraHttpMockup());
        SkyDeCommitChangesFromJira.createCommitChange(userStory.Id);
        HTTPResponse response =SkyDeCommitChangesFromJira.getCopadoResponse();
        System.assertEquals(200,response.getStatusCode());
        Test.stopTest();
    }
}