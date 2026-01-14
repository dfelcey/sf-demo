public class CreateOpportunityInvocable {
    
    @InvocableMethod(label='Create Opportunity' 
                     description='Creates a new Opportunity for a specified Account'
                     category='Opportunity')
    public static List<CreateOpportunityResult> createOpportunity(List<CreateOpportunityRequest> requests) {
        List<CreateOpportunityResult> results = new List<CreateOpportunityResult>();
        
        for (CreateOpportunityRequest request : requests) {
            CreateOpportunityResult result = new CreateOpportunityResult();
            
            try {
                // Validate required fields
                if (String.isBlank(request.accountId) && String.isBlank(request.accountName)) {
                    result.isSuccess = false;
                    result.errorMessage = 'Either Account ID or Account Name is required';
                    results.add(result);
                    continue;
                }
                
                // If Account Name provided instead of ID, look it up
                String accountId = request.accountId;
                if (String.isBlank(accountId) && String.isNotBlank(request.accountName)) {
                    List<Account> accounts = [
                        SELECT Id, Name 
                        FROM Account 
                        WHERE Name LIKE :('%' + request.accountName + '%')
                        LIMIT 1
                    ];
                    
                    if (accounts.isEmpty()) {
                        result.isSuccess = false;
                        result.errorMessage = 'No Account found with name: ' + request.accountName;
                        results.add(result);
                        continue;
                    }
                    
                    accountId = accounts[0].Id;
                    result.accountName = accounts[0].Name;
                }
                
                // Set default values if not provided
                String oppName = String.isNotBlank(request.opportunityName)
                    ? request.opportunityName 
                    : 'New Opportunity - ' + System.today().format();
                
                Date closeDate = request.closeDate != null 
                    ? request.closeDate 
                    : System.today().addDays(30);
                
                String stageName = String.isNotBlank(request.stageName)
                    ? request.stageName 
                    : 'Prospecting';
                
                // Create the Opportunity
                Opportunity newOpp = new Opportunity(
                    AccountId = accountId,
                    Name = oppName,
                    StageName = stageName,
                    CloseDate = closeDate,
                    Amount = request.amount,
                    Description = request.description,
                    Type = request.opportunityType,
                    OwnerId = UserInfo.getUserId()
                );
                
                insert newOpp;
                
                // Populate success result
                result.isSuccess = true;
                result.opportunityId = newOpp.Id;
                result.opportunityName = newOpp.Name;
                result.successMessage = 'Opportunity "' + newOpp.Name + '" created successfully!';
                
            } catch (Exception e) {
                result.isSuccess = false;
                result.errorMessage = 'Error creating opportunity: ' + e.getMessage();
            }
            
            results.add(result);
        }
        
        return results;
    }
    
    // Input wrapper class
    public class CreateOpportunityRequest {
        @InvocableVariable(label='Account ID' description='The Salesforce ID of the Account' required=false)
        public String accountId;
        
        @InvocableVariable(label='Account Name' description='Name of the Account (used if Account ID not provided)' required=false)
        public String accountName;
        
        @InvocableVariable(label='Opportunity Name' description='Name for the new Opportunity' required=true)
        public String opportunityName;
        
        @InvocableVariable(label='Close Date' description='Expected close date (defaults to 30 days from today)' required=false)
        public Date closeDate;
        
        @InvocableVariable(label='Stage Name' description='Sales stage (defaults to Prospecting)' required=false)
        public String stageName;
        
        @InvocableVariable(label='Amount' description='Opportunity amount' required=false)
        public Decimal amount;
        
        @InvocableVariable(label='Description' description='Opportunity description' required=false)
        public String description;
        
        @InvocableVariable(label='Opportunity Type' description='Type of opportunity (e.g., New Business, Existing Customer)' required=false)
        public String opportunityType;
    }
    
    // Output wrapper class
    public class CreateOpportunityResult {
        @InvocableVariable(label='Success' description='Whether the operation was successful')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Opportunity ID' description='ID of the created Opportunity')
        public String opportunityId;
        
        @InvocableVariable(label='Opportunity Name' description='Name of the created Opportunity')
        public String opportunityName;
        
        @InvocableVariable(label='Account Name' description='Name of the associated Account')
        public String accountName;
        
        @InvocableVariable(label='Success Message' description='Success confirmation message')
        public String successMessage;
        
        @InvocableVariable(label='Error Message' description='Error message if operation failed')
        public String errorMessage;
    }
}