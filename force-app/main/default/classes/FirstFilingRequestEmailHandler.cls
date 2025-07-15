global class FirstFilingRequestEmailHandler implements Messaging.InboundEmailHandler {
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        String emailBody = email.plainTextBody.replace('*','');
        system.debug('emailBody'+emailBody);
        if (emailBody == null) {
            result.success = false;
            return result;
        }
        Set<String> keySetToExtract = new Set<String>{'Should anyone be copied on patent correspondence?','Licensing Officer','Title','Case Number','Inventors','Agreements','Institutions','Has a prior art search been completed?','Would you like to have a prior art search conducted?','Attorney','Law Firm','What type of Application','Complexity of Application','Bar Date','Is there an agreement that includes industrial rights','Additional Information/Comments'};
            
            Map<String, Object> parsedValues = parseEmailBody(keySetToExtract,emailBody);
        System.debug('parsedValues--'+parsedValues);
        
        //getting email address
        String fromEmailAddress = envelope.fromAddress;
        
        //getting values from json
        String attorneyName = (String)parsedValues.get('Attorney'); 
        String caseNumber =  (String)parsedValues.get('Case Number');
        String title =  (String)parsedValues.get('Title');
        String licensingOfficer =  (String)parsedValues.get('Licensing Officer');
        List<String> inventors =  String.valueOf(parsedValues.get('Inventors')).split(';');
        String barDate =  (String)parsedValues.get('Bar Date');
        List<String> comments =  String.valueOf(parsedValues.get('Additional Information/Comments')).split(';');
        String isPriorArtSearchCompleted = ((String)parsedValues.get('Has a prior art search been completed?')).toUpperCase();
        String wantPriorArtSearch = ((String)parsedValues.get('Would you like to have a prior art search conducted?')).toUpperCase();
        
        String priorArtLanguage = 'A prior art search has {0} been completed and one is {1} requested at this time.';
        String priorArtLanguageResult='';
        
        if(isPriorArtSearchCompleted=='NO' && wantPriorArtSearch=='NO'){
            priorArtLanguageResult = String.format(priorArtLanguage,new List<String>{'not','not'});
        }
        else if(isPriorArtSearchCompleted=='NO' && wantPriorArtSearch=='YES'){
            priorArtLanguageResult =String.format(priorArtLanguage,new List<String>{'not',''});
        }
        else if(isPriorArtSearchCompleted=='YES' && wantPriorArtSearch=='YES'){
            priorArtLanguageResult =String.format(priorArtLanguage,new List<String>{'',''});
        }
        else if(isPriorArtSearchCompleted=='YES' && wantPriorArtSearch=='NO'){
            priorArtLanguageResult =String.format(priorArtLanguage,new List<String>{'','not'});
        }
        //prepare email using extracted values and send it to fromAddress
        sendFirstFilingEmail(fromEmailAddress,attorneyName,caseNumber,title,licensingOfficer,inventors,barDate,comments,priorArtLanguageResult);
        
        result.success = true;
        return result;
    }
    
    private Map<String, Object> parseEmailBody(Set<String> keys,String body) {
        String formattedbody  = extractDataFromEmail(keys, body);
        String cleanJson = formattedBody.replace('```json', '').replace('```', '').trim();
        Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(cleanJson);
        return jsonMap;
    }
    
    
    
    public static String extractDataFromEmail(Set<String> keys,String emailText ) {
        FirstFiling_Email_Data__c emailDataRecord = new FirstFiling_Email_Data__c(Keys__c=String.join(keys,';'),EmailText__c=emailText);
        
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
                'First_Filing_Email_Generator',
                executeTemplateInput
            );
            ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
            System.debug('response.text--'+response.text);
            return response.text;
        } catch (Exception e) {
            System.debug(e.getMessage());
            throw e;
        }
    }
    
    //prepare and send first filing email
    public static void sendFirstFilingEmail(
        String toAddress,
        String attorneyName,
        String caseNumber,
        String title,
        String licensingOfficer,
        List<String> inventors,
        String barDate,
        List<String> comments,
        String priorArtLanguage
    ) {
        String htmlBody = '';
        htmlBody += '<p>Dear Attorney ' + attorneyName + ',</p>';
        htmlBody += '<p>Attached please find the names of the documents as attached assigned to MIT case number ' + caseNumber + '.</p>';
        htmlBody += '<p>Additionally, please review the table denoted below as it cites all relevant information pertaining to the requested filing. Please send digital copies of these collected assignments to the TLO Patent Administration Group (tlo-atto@mit.edu).</p>';
        htmlBody += '<p><b>Comments :</b> ' + String.join(comments,',') + '</p>';
        htmlBody += '<p>Please confirm receipt of this request. Prior to accepting, if applicable please run a conflict check.</p>';
        htmlBody += '<p>If you have any questions regarding the administrative process, please do not hesitate to contact me.</p>';
        htmlBody += '<p>Thank you.</p>';
        
        // Begin Combined Table
        htmlBody += '<table border="1" cellpadding="6" cellspacing="0" style="border-collapse: collapse; font-family: Arial, sans-serif; font-size: 14px;">';
        htmlBody += '<tr><th style="background:#f2f2f2;">Section</th><th style="background:#f2f2f2;">Value</th></tr>';
        
        // Filing Info
        htmlBody += '<tr><td>M.I.T. Case No.</td><td>' + caseNumber + '</td></tr>';
        htmlBody += '<tr><td>Licensing Officer/Associate</td><td>' + licensingOfficer + '</td></tr>';
        htmlBody += '<tr><td>Title</td><td>' + title + '</td></tr>';
        
        // Inventor Table
        for (String inventor : inventors) {
            htmlBody += '<tr><td>*Lead Inventor</td><td>' + inventor + ' – Confirmed/Not Confirmed</td></tr>';
        }
        
        // Remaining Rows
        htmlBody += '<tr><td>Inventor Assignments</td><td>Per TLO Guidelines, Law Firms are responsible for obtaining all assignments from inventors within 60 days. Please contact <a href="mailto:tlo-atto@mit.edu">tlo-atto@mit.edu</a> to confirm assignment obligations if you have not received a notice. Please send digital copies of these collected assignments to the TLO Patent Administration Group.</td></tr>';
        
        htmlBody += '<tr><td>Conflict Check</td><td>In compliance with MIT’s protocol, please conduct a conflict check to ensure that you have no conflicts in representing MIT in this matter. If a conflict is identified, please follow up directly with the Licensing Officer indicated above.</td></tr>';
        
        htmlBody += '<tr><td>Filing Deadline</td><td>' + barDate + '</td></tr>';
        htmlBody += '<tr><td>Prior Art</td><td>' + priorArtLanguage + '</td></tr>';
        
       /* 
            FOR Sponsorship

            htmlBody += '<tr><td>Sponsorship</td><td>In the case of federal sponsorship, the following language MUST be used precisely:<br/><br/>' +
            '“This invention was made with government support under (insert grant/contract number*) awarded by (identify the Federal agency). The government has certain rights in the invention.”<br/>' +
            '*Use grant/contract number only (e.g. “X123” not “Contract/Grant X123”)<br/>' +
            'Please confirm the sponsorship with <a href="mailto:tlo-comp@mit.edu">tlo-comp@mit.edu</a> PRIOR to filing any patent application.</td></tr>';*/
        
        htmlBody += '<tr><td>Reporting</td><td>All patent reporting must route via <a href="mailto:tlo-atto@mit.edu">tlo-atto@mit.edu</a>. Please do not cc individual TLO members when this address is used.</td></tr>';
        
        htmlBody += '<tr><td>Prosecution Strategy</td><td>Please follow up directly with the assigned Licensing Officer for this case.</td></tr>';
        
        htmlBody += '</table>';
        
        // Send Email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { toAddress });
        email.setSubject('Filing Case Request MIT Case Number ' + caseNumber);
        email.setHtmlBody(htmlBody);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }
}