/**
 * @description       :
 * @author            :
 * @group             :
 * @last modified on  : 03-20-2025
 * @last modified by  :
 **/

global class LawFirmEmailHandler implements Messaging.InboundEmailHandler {
    
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

        List<String> tasks = new List<String>();

        // Extract Email Body
        String emailBody = email.plainTextBody.replace('*','');
        if (emailBody == null) {
            result.success = false;
            return result;
        }
        
        // Retrieve Field Mapping from Custom Metadata
        Map<String, List<String>> fieldMapping = new Map<String, List<String>>();
        for (Field_Mapping__mdt mapping : [SELECT Email__c, Object_Field__c,Object_Name__c FROM Field_Mapping__mdt]) {
            fieldMapping.put(mapping.Email__c, new List<String>{mapping.Object_Name__c,mapping.Object_Field__c});
        }
        
        Map<String, Object> parsedValues = parseEmailBody(fieldMapping,emailBody);
        List<law_firm_request__c> recordList=new List<law_firm_request__c>();
        law_firm_request__c record;
        
        if ((parsedValues.containsKey('Reference Number')) && (parsedValues.get('Reference Number') != null)){
            String refNo = String.valueOf(parsedValues.get('Reference Number'));
            recordList = [SELECT Id FROM law_firm_request__c WHERE Reference_Number__c = :refNo LIMIT 1];
        }
        
        if (recordList.size()==0) {
            record = new law_firm_request__c();   
        }
        else
        {
            record = recordList[0];
        }
        
        Map<String,sObject> recordsMappingToBeInserted = new Map<String,sObject>();
        Boolean anyValuePresent = false;

        for (String emailField : parsedValues.keySet()) {
            if(!anyValuePresent){
                anyValuePresent=  parsedValues.get(emailField)!=null?true:false;
            }
            
            if(!fieldMapping.containsKey(emailField)) {
                if (parsedValues.get(emailField)!=null && parsedValues.get(emailField) instanceof List<Object>) {
                    for(Object task : (List<Object>)parsedValues.get(emailField)){
                        tasks.add(String.valueOf(task));
                    }
                }
            }
            else{
                String salesforceField = fieldMapping.get(emailField)[1];
                String salesforceObject = fieldMapping.get(emailField)[0];

                if(salesforceObject!='law_firm_request__c'){
                    Type objType = Type.forName('Schema.' + salesforceObject);
                    sObject obj;

                    if(recordsMappingToBeInserted.containsKey(salesforceObject)){
                        obj = recordsMappingToBeInserted.get(salesforceObject);
                    }
                    else{
                        obj = (sObject) objType.newInstance();
                    }
                    
                    Schema.SObjectType objectType = Schema.getGlobalDescribe().get(salesforceObject);
                    Map<String, Schema.SObjectField> sObjectFieldMap = objectType.getDescribe().fields.getMap();
                    Schema.DescribeFieldResult sObjectfieldDescribe = sObjectfieldMap.get(salesforceField).getDescribe();
                    
                    if (sObjectfieldDescribe.getType() == Schema.DisplayType.Date) {
                        if(parsedValues.get(emailField)!=null){
                            String dateStr = (String)parsedValues.get(emailField);
                            Date convertedDate = Date.valueOf(dateStr);
                            obj.put(salesforceField, convertedDate);
                        }  
                    }
                    else if(sObjectfieldDescribe.getType() == Schema.DisplayType.Picklist){
                        
                        List<Schema.PicklistEntry> picklistValues = sObjectfieldDescribe.getPicklistValues();
                        Set<String> picklistValueSet = new  Set<String>();
                        for (Schema.PicklistEntry picklistEntry : picklistValues) {
                            picklistValueSet.add(picklistEntry.getValue());
                        }
                        if(picklistValueSet.contains(String.valueOf(parsedValues.get(emailField)))){
                            obj.put(salesforceField, String.valueOf(parsedValues.get(emailField)));
                        }
                        else{
                            obj.put(salesforceField, null);
                        }
                    }
                    else {
                        obj.put(salesforceField, String.valueOf(parsedValues.get(emailField)));
                    }  
                    recordsMappingToBeInserted.put(salesforceObject,obj);
                }
                else{
                    Schema.DescribeSObjectResult objectDescribe = law_firm_request__c.SObjectType.getDescribe();
                    Map<String, Schema.SObjectField> fieldMap = objectDescribe.fields.getMap();
                    if (salesforceField != null && fieldMap.containsKey(salesforceField)) {
                        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(salesforceField).getDescribe();
                        if (fieldDescribe.getType() == Schema.DisplayType.Date) {
                            if(parsedValues.get(emailField)!=null){
                                String dateStr = (String)parsedValues.get(emailField);
                                Date convertedDate = Date.valueOf(dateStr);
                                record.put(salesforceField, convertedDate);
                            }
                        } else if(fieldDescribe.getType() == Schema.DisplayType.Picklist){
                            
                            List<Schema.PicklistEntry> picklistValues = fieldDescribe.getPicklistValues();
                            Set<String> picklistValueSet = new  Set<String>();
                            for (Schema.PicklistEntry picklistEntry : picklistValues) {
                                picklistValueSet.add(picklistEntry.getValue());
                            }
                            if(picklistValueSet.contains(String.valueOf(parsedValues.get(emailField)))){
                                record.put(salesforceField, String.valueOf(parsedValues.get(emailField)));
                            }
                            else{
                                record.put(salesforceField, null);
                            }
                        }
                        else
                        {
                            record.put(salesforceField, String.valueOf(parsedValues.get(emailField)));
                        }
                    }
                }
            }
        }

        if(anyValuePresent){
            if(record.Id == null){
                insert record;
            }
            else
            {
                update record;
            }

            List<Task> taskList = new List<Task>();

            for(String task : tasks){
                taskList.add(new Task(
                    Subject = task,
                WhatId = record.Id,
                Status = 'Not Started',
                Priority = 'Normal'
                    )
                    );
            }
            insert recordsMappingToBeInserted.values();
            insert taskList;   
        }

        result.success = true;
        return result;
    }
    
    private Map<String, Object> parseEmailBody(Map<String, List<String>> fieldMapping,String body) {
        Map<String, String> extractedValues = new Map<String, String>();
        Map<String, String> fieldPatterns = new Map<String, String>();
        String formattedbody  = extractDataFromEmail(fieldMapping.keySet(), body);
        String cleanJson = formattedBody.replace('```json', '').replace('```', '').trim();
        Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(cleanJson);
        return jsonMap;
    }

    // extractDataFromEmail : it returns json string by extracting data from email using keys list
    
    public static String extractDataFromEmail(Set<String> keys,String emailText ) {

        Email_Data__c emailDataRecord = new Email_Data__c(Keys__c=String.join(keys,';'),EmailText__c=emailText);      
        insert emailDataRecord;
        Map<String, String> experienceSession = new Map<String, String>();
        
        experienceSession.put('id', emailDataRecord.Id);
        ConnectApi.WrappedValue experienceSessionValue = new ConnectApi.WrappedValue();
        experienceSessionValue.value = experienceSession;
        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
        inputParams.put('Input:EmailData', experienceSessionValue);
        
        // Configure invocation parameters
        ConnectApi.EinsteinPromptTemplateGenerationsInput executeTemplateInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        executeTemplateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        executeTemplateInput.additionalConfig.applicationName = 'PromptBuilderPreview';
        executeTemplateInput.isPreview = false;
        executeTemplateInput.inputParams = inputParams;
        
        try {
            // Call the service
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                'Email_Prompt_Template',
            executeTemplateInput
                );
            ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
            return response.text;

        } catch (Exception e) {
            System.debug(e.getMessage());
            throw e;
        }
    }
    
    public static String extractContent(String jsonString) {
        try {
            // Parse the JSON string to a map
            Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);

            if (jsonMap.containsKey('choices')) {
                List<Object> choices = (List<Object>) jsonMap.get('choices');

                if (!choices.isEmpty()) {                   
                    Map<String, Object> firstChoice = (Map<String, Object>) choices[0];

                    if (firstChoice.containsKey('message')) {
                        
                        Map<String, Object> message = (Map<String, Object>) firstChoice.get('message');

                        if (message.containsKey('content')) {
                            return String.valueOf(message.get('content'));
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error parsing JSON: ' + e.getMessage());
        }
        return null; // Return null if content is not found
    }
    
}