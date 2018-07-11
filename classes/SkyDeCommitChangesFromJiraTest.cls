/**
* This class contains unit tests for validating the behavior of Apex classes
* and triggers.
*
* Unit tests are class methods that verify whether a particular piece
* of code is working properly. Unit test methods take no arguments,
* commit no data to the database, and are flagged with the testMethod
* keyword in the method definition.
*
* All test methods in an organization are executed whenever Apex code is deployed
* to a production organization to confirm correctness, ensure code
* coverage, and prevent regressions. All Apex classes are
* required to have at least 75% code coverage in order to be deployed
* to a production organization. In addition, all triggers must have some code coverage.
* 
* The @isTest class annotation indicates this class only contains test
* methods. Classes defined with the @isTest annotation do not count against
* the organization size limit for all Apex scripts.
*
* See the Apex Language Reference for more information about Testing and Code Coverage.
*/
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
        SkyDeCommitChangesFromJira.createCommitChange(userStory);
        List<HTTPResponse> responseList =SkyDeCommitChangesFromJira.getCopadoResponse();
        for(HTTPResponse response : responseList){
            System.assertEquals(200,response.getStatusCode());
        }
        Test.stopTest();
    }
}