global class FirstFilingRequestEmailHandler implements Messaging.InboundEmailHandler {
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        String emailBody = email.plainTextBody.replace('*','');
        system.debug('emailBody'+emailBody);
        if (emailBody == null) {
            result.success = false;
            return result;
        }
        Set<String> keySetToExtract = new Set<String>{'Should anyone be copied on patent correspondence?','Licensing Officer','Title','Case Number','Inventors','Agreements','Institutions','Has a prior art search been completed?','Would you like to have a prior art search conducted?','Attorney','Law Firm','What type of Application','Complexity of Application','Bar Date','Is there an agreement that includes industrial rights','Additional Information/Comments','Sponsor'};
        
        Map<String, Object> parsedValues = parseEmailBody(keySetToExtract,emailBody);
        System.debug('parsedValues--'+parsedValues);
        
        //getting email address
        String fromEmailAddress = envelope.fromAddress;
        
        //getting values from json
        String attorneyName = (String)parsedValues.get('Attorney');
        String caseNumber =  (String)parsedValues.get('Case Number');
        String  includesIndRights =  (String)parsedValues.get('Is there an agreement that includes industrial rights');
        String title =  (String)parsedValues.get('Title');
        String licensingOfficer =  (String)parsedValues.get('Licensing Officer');
        String sponsor = parsedValues.get('Sponsor') !=null? (String)parsedValues.get('Sponsor'):'sponsorNotPresent';
        List<String> inventors = parsedValues.get('Inventors')!=null? String.valueOf(parsedValues.get('Inventors')).split(';'):null;
        String barDate =  (String)parsedValues.get('Bar Date');
        List<String> piList =  parsedValues.get('PI') !=null? String.valueof(parsedValues.get('PI')).split(';'):null;
        
        List<String> JointInstitutions = parsedValues.get('Institutions')!=null? String.valueOf(parsedValues.get('Institutions')).split(';'):null;
        List<String> agreements = parsedValues.get('Agreements')!=null? String.valueOf(parsedValues.get('Agreements')).split(';'):null;
        
        List<String> comments =  parsedValues.get('Additional Information/Comments')!=null? String.valueOf(parsedValues.get('Additional Information/Comments')).split(';'):null;
        String isPriorArtSearchCompleted = ((String)parsedValues.get('Has a prior art search been completed?')).toUpperCase();
        String wantPriorArtSearch = ((String)parsedValues.get('Would you like to have a prior art search conducted?')).toUpperCase();
        String lawFirmName =  parsedValues.get('Law Firm')!=null?String.valueOf(parsedValues.get('Law Firm')):'';
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
        
        
        // Entity Size Determination Logic :
        
        String entitySizeStep1='';
        String entitySizeStep2='';
        String entitySizeStep3='';
        String entitySizeStep4='';
        
        String entitySize='';
        if(caseNumber!=null){
            Boolean isJointOwnership = caseNumber.contains('J');
            // Step 1: Special Case Check
            if (caseNumber.endsWith('T') || caseNumber.endsWith('TE') || caseNumber.endsWith('X')) {
                entitySizeStep1='Large';
            }
            
            // Step 2: Ownership Evaluation
            if(isJointOwnership){
                if (jointInstitutions==null || jointInstitutions.isEmpty()) {
                    entitySizeStep2= 'Unknown';
                } else {
                    entitySizeStep2= 'Large';
                }
            }
            else if (jointInstitutions!=null &&  jointInstitutions.size()!=0) {
                
                entitySizeStep2='Unknown';
                
            }
            
        }
        
        
        
        
        //step 3 Agreement Evaluation
        /* If any agreement is with a for-profit → Large
        If no agreements or not disqualifying → go to Step 4*/
            
        //step 4 Sponsor Evaluation
        if(includesIndRights==null){
            entitySizeStep4='Unknown';
        }
        else if(includesIndRights.toLowerCase()=='yes'){
            entitySizeStep4='Large';
        }
        else if(includesIndRights.toLowerCase()=='no'){
            List<String> govtSponsors = new List<String>{'Draper', 'KFUPM', 'Masdar', 'SMART', 'Arch Therapeutics', 'Mitre Corporation', 'Tata Limited' };
            
            if(govtSponsors.contains(sponsor)){
                entitySizeStep4='Large';
            }
            
        }
        
        //step 5 : final Evaluation
        if(entitySizeStep1 == 'Large'|| entitySizeStep2 == 'Large' || entitySizeStep3 == 'Large' || entitySizeStep4 == 'Large'){
            entitySize='Large';
        }else if(entitySizeStep1 == 'Unknown'|| entitySizeStep2 == 'Unknown' || entitySizeStep3 == 'Unknown' || entitySizeStep4 == 'Unknown'){
            entitySize='Unknown';
        }
        else if(entitySizeStep1 == '' && entitySizeStep2 == '' && entitySizeStep3 == '' && entitySizeStep4 == ''){
            entitySize='Small';
        }
        
        
        //Agreement Language :
        
        String agreementLangRes = '';
        
        if(agreements==null || agreements.size()==0){
            if(JointInstitutions!=null && JointInstitutions.size()!=0){
                agreementLangRes= 'Currently there are no licensing agreements and there are joint ownership agreements pertaining to this case. We will communicate to you directly if subsequent to this communication a license or joint-ownership is activated or terminated.';
            }
            else{
                agreementLangRes= 'Currently there are no licensing agreements and no joint ownership agreements pertaining to this case. We will communicate to you directly if subsequent to this communication a license or joint-ownership is activated or terminated.';
            }
        }
        else{
            if(JointInstitutions==null || JointInstitutions.size()==0){
                agreementLangRes= 'Currently there are licensing agreements and there are no joint ownership agreements pertaining to this case. We will communicate to you directly if subsequent to this communication a license or joint-ownership is activated or terminated.';
            }
            else{
                agreementLangRes='Currently there are licensing agreements and there are joint ownership agreements pertaining to this case. We will communicate to you directly if subsequent to this communication a license or joint-ownership is activated or terminated.';
            }
        }
        
        //Assignment Language (currently All Not Confirmed):
        
        Boolean allConfirmed = false;
        Boolean allNotConfirmed = true;
        String assignmentLangRes='';
        if(allConfirmed){
            assignmentLangRes='Inventor assignment obligations have been confirmed and are contained in the chart above. Please draft and collect assignments from the above listed inventors. Please send digital copies of these collected assignments to the TLO Patent Administration Group (tlo-atto@mit.edu).';
        }
        else if(allNotConfirmed){
            assignmentLangRes='Inventor assignment obligations have not been confirmed. We will we follow up with assignment obligations once they are available. Once provided, please draft and collect assignments from the above listed inventors as necessary. Please send digital copies of these collected assignments to the TLO Patent Administration Group (tlo-atto@mit.edu).';
        }
        else{
            assignmentLangRes=  'Inventor assignment obligations have not all been confirmed. We will we follow up with assignment obligations once they are available. Once provided, please draft and collect assignments from the above listed inventors as necessary. Please send digital copies of these collected assignments to the TLO Patent Administration Group (tlo-atto@mit.edu).';
        }
        
        //prepare email using extracted values and send it to fromAddress
        sendFirstFilingEmail(fromEmailAddress,attorneyName,caseNumber,title,licensingOfficer,inventors,barDate,comments,priorArtLanguageResult,agreementLangRes,entitySize,lawFirmName,assignmentLangRes,piList);
        
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
    String priorArtLanguage,
    String agreementLangRes,
    String entitySize,
    String lawFirmName,
    String assignmentLangRes,
    List<String> piList
    ) {
        String htmlBody = '';
        htmlBody += '<p>Dear Attorney ' + attorneyName + ',</p>';
        htmlBody += '<p>Attached please find the names of the documents as attached assigned to MIT case number ' + caseNumber + '.</p>';
        htmlBody += '<p>Additionally, please review the table denoted below as it cites all relevant information pertaining to the requested filing. Please send digital copies of these collected assignments to the TLO Patent Administration Group (tlo-atto@mit.edu).</p>';
        htmlBody += '<p><b>Comments :</b> ' + String.join(comments,',') + '</p>';
        htmlBody += '<p>Please confirm receipt of this request. Prior to accepting, if applicable please run a conflict check.</p>';
        htmlBody += '<p>If you have any questions regarding the administrative process, please do not hesitate to contact me.</p>';
        htmlBody += '<p>Thank you.</p>';
        htmlBody += '<p>Love Rob</p>';
        
        // Begin Combined Table
        htmlBody += '<table border="1" cellpadding="6" cellspacing="0" style="border-collapse: collapse; font-family: Arial, sans-serif; font-size: 14px;">';
        
        
        // Filing Info
        htmlBody += '<tr><td><strong>M.I.T. Case No.</strong></td><td colspan="2">' + caseNumber + '</td></tr>';
        htmlBody += '<tr><td><strong>Licensing Officer/Associate</strong></td><td colspan="2" >' + licensingOfficer + '</td></tr>';
        htmlBody += '<tr><td><strong>Title</strong></td><td colspan="2">' + title + '</td></tr>';
        
        // Inventive Entity
        htmlBody += '<tr><td><strong>Inventive Entity</strong></td><td colspan="2">Please note that the inventors associated with this case/disclosure are listed below.  If a change occurs to the inventive entity from this original list of inventors for any patent filing subsequent to this filing, it is required of counsel to officially report this change so that we may maintain the integrity of our database and allocate respective royalties accurately.  Your support of this effort is greatly appreciated.  If applicable, please report an inventive entity change in compliance with our standard reporting protocol and via our general e-mail address (<a href="mailto:tlo-comp@mit.edu">tlo-atto@mit.edu</a>). </td></tr>';
        
        
        // Inventor Table
        
        htmlBody +=  '<tr><th  style="text-align: left;">Assignments</th><th>Inventor Name:</th><th>Inventor is Assigning to:</th></tr>';
        if(inventors!=null){
            for (String inventor : inventors) {
                List<String> vals=  inventor.split(',');
                String invName= vals.size()>0 ?vals[0]:'';
                String invAssignment= vals.size()>1 ?vals[1]:'';
                
                if(piList!=null && piList.contains(invName)){
                    htmlBody += '<tr><td><strong>'+'(*Lead Inventor) '+invAssignment+'</strong></td><td>' + invName + '</td><td>Not Confirmed</td></tr>';
                }
                else{
                    htmlBody += '<tr><td><strong>'+invAssignment+'</strong></td><td>' + invName + '</td><td>Not Confirmed</td></tr>';
                }
                
            }
        }
        
        
        // Remaining Rows
        htmlBody += '<tr><td><strong>Inventor Assignments</strong></td><td colspan="2">Per TLO Guidelines, Law Firms are responsible for obtaining all assignments from inventors within 60 days. Please contact <a href="mailto:tlo-atto@mit.edu">tlo-atto@mit.edu</a> to confirm assignment obligations if you have not received a notice.<br>'+assignmentLangRes+'Please send digital copies of these collected assignments to the TLO Patent Administration Group.</td></tr>';
        htmlBody += '<tr><td><strong>Conflict Check</strong></td><td colspan="2">In compliance with MIT’s protocol, please conduct a conflict check to ensure that you have no conflicts in representing MIT in this matter. If a conflict is identified, please follow up directly with the Licensing Officer indicated above.</td></tr>';
        htmlBody += '<tr><td><strong>Type of Filing</strong></td><td colspan="2">Moderate</td></tr>';
        htmlBody += '<tr><td><strong>Filing Deadline</strong></td><td colspan="2">' + barDate + '</td></tr>';
        htmlBody += '<tr><td><strong>Prior Art</strong></td><td colspan="2">' + priorArtLanguage + '</td></tr>';
        htmlBody += '<tr><td><strong>Cost</strong></td><td colspan="2">' + lawFirmName + ' effectively subscribes to a fixed fee schedule.  </td></tr>';
        
        
        
        
        //FOR Sponsorship
        
        htmlBody += '<tr><td><strong>Sponsorship</strong></td><td colspan="2">In the case of federal sponsorship, the following language MUST be used precisely:<br/><br/>' +
            '“This invention was made with government support under (insert grant/contract number*) awarded by (identify the Federal agency). The government has certain rights in the invention.”<br/>' +
            '*Use grant/contract number only (e.g. “X123” not “Contract/Grant X123”)<br/>' +
            'Please confirm the sponsorship with <a href="mailto:tlo-comp@mit.edu">tlo-comp@mit.edu</a> PRIOR to filing any patent application.<u>If applicable,  please ensure the Statement of Government Support is included in this patent application and ALL future related patent applications both foreign and domestic.</u></td></tr>';
        
        htmlBody += '<tr><td><strong>Entity Size</strong></td><td colspan="2">MIT Case No.'+caseNumber+' qualifies as ' + entitySize + ' entity at this time.Please consider that MIT intentionally asserts large entity for any case wherein there is an active license; joint-ownership with a for-profit</td></tr>';
        htmlBody += '<tr><td><strong>Licensing/Joint Ownership</strong></td><td colspan="2">'+ agreementLangRes +'<br> We will communicate to you directly if subsequent to this communication a license or joint-ownership is activated or terminated.</td></tr>';
        htmlBody += '<tr><td><strong>Reporting</strong></td><td colspan="2">All patent reporting must route via <a href="mailto:tlo-atto@mit.edu">tlo-atto@mit.edu</a>. Please do not cc individual TLO members when this address is used.</td></tr>';
        htmlBody += '<tr><td><strong>Prosecution Strategy</strong></td><td colspan="2">Please follow up directly with the assigned Licensing Officer for this case.</td></tr>';
        
        htmlBody += '</table>';
        
        // Send Email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { toAddress });
        email.setSubject('Filing Case Request MIT Case Number ' + caseNumber);
        email.setHtmlBody(htmlBody);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }
}