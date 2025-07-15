public class ApexAI {
 
    @InvocableMethod
    public static List<Response> getPrompt(List<Request> requests) {
        Request input = requests[0];
        List<Response> responses = new List<Response>();
        Response output = new Response();
        
   
       output.Prompt = 'generate a summary using the following info:';
 
        output.Prompt += '\nEmailText: ' + input.EmailData.EmailText__c +'\nList Of Keys: '+input.EmailData.keys__c;

     responses.add(output);
        return responses;
    }
 
    // Type and API Name of all variables must match the template
    public class Request {
        @InvocableVariable(required=true)
        public Email_Data__c EmailData;

    }

    public class Response {
        @InvocableVariable
        public String Prompt;
    }
}