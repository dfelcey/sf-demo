public with sharing class CreateOpportunityInvocable {
    
    @InvocableMethod(label='Create Opportunity' description='Creates a new Opportunity for a specified Account')
    public static List<Response> createOpportunity(List<Request> requests) {
        List<Response> responses = new List<Response>();
        
        for (Request req : requests) {
            Response res = new Response();
            try {
                Opportunity opp = new Opportunity();
                opp.Name = req.opportunityName != null ? req.opportunityName : 'New Opportunity';
                opp.AccountId = req.accountId;
                opp.StageName = req.stageName != null ? req.stageName : 'Prospecting';
                opp.CloseDate = req.closeDate != null ? req.closeDate : Date.today().addDays(30);
                opp.Amount = req.amount;
                
                if (req.type != null) {
                    opp.Type = req.type;
                }
                
                insert opp;
                
                res.success = true;
                res.opportunityId = opp.Id;
                res.message = 'Opportunity created successfully';
            } catch (Exception e) {
                res.success = false;
                res.message = 'Error: ' + e.getMessage();
            }
            responses.add(res);
        }
        
        return responses;
    }
    
    public class Request {
        @InvocableVariable(label='Account ID' description='The ID of the Account' required=true)
        public String accountId;
        
        @InvocableVariable(label='Opportunity Name' description='Name of the Opportunity')
        public String opportunityName;
        
        @InvocableVariable(label='Stage Name' description='Sales stage of the Opportunity')
        public String stageName;
        
        @InvocableVariable(label='Close Date' description='Expected close date')
        public Date closeDate;
        
        @InvocableVariable(label='Amount' description='Opportunity amount')
        public Decimal amount;
        
        @InvocableVariable(label='Type' description='Opportunity type')
        public String type;
    }
    
    public class Response {
        @InvocableVariable(label='Success' description='Whether the operation succeeded')
        public Boolean success;
        
        @InvocableVariable(label='Opportunity ID' description='ID of the created Opportunity')
        public String opportunityId;
        
        @InvocableVariable(label='Message' description='Result message')
        public String message;
    }
}

