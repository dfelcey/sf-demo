/**
 * AgentGetStorefrontsByAccountActions
 *
 * Lists storefronts for a given Account__c. Intended to be used after identity verification
 * (Get_Customer_Profile) has provided a trusted accountId.
 */
public with sharing class AgentGetStorefrontsByAccountActions {
    public class Request {
        @InvocableVariable(
            label='Account Id'
            description='The Account Id that owns the storefronts. Required for security validation. Get this from Get_Customer_Profile (email verification).'
            required=true
        )
        public Id accountId;
    }

    public class StorefrontSummary {
        @InvocableVariable(label='Storefront Id' description='The Storefront__c record Id.')
        public Id id;

        @InvocableVariable(label='Name' description='The storefront name (Storefront__c.Name).')
        public String name;

        @InvocableVariable(label='Account Id' description='Owning Account Id (Storefront__c.Account__c).')
        public Id accountId;

        @InvocableVariable(label='Description' description='Storefront description (Storefront__c.Description__c).')
        public String description;

        @InvocableVariable(label='Cuisine' description='Cuisine type (Storefront__c.Cuisine__c).')
        public String cuisine;

        @InvocableVariable(label='Average Review Score' description='Average review score (Storefront__c.Average_Review_Score__c).')
        public Decimal averageReviewScore;
    }

    public class Response {
        @InvocableVariable(
            label='Success'
            description='True when the action executed successfully. False when inputs are missing/invalid or an unexpected error occurred.'
        )
        public Boolean success;

        @InvocableVariable(
            label='Message'
            description='User-readable status message. On errors, explains what was missing or what failed.'
        )
        public String message;

        @InvocableVariable(
            label='Storefronts'
            description='A list of storefront summaries for the provided accountId.'
        )
        public List<StorefrontSummary> storefronts;

        @InvocableVariable(
            label='Storefronts JSON'
            description='JSON-serialized version of storefronts for clients that prefer to parse JSON.'
        )
        public String storefrontsJson;
    }

    @InvocableMethod(
        label='Get Storefronts By Account'
        description='Lists Storefront__c records for a given Account__c and returns results as Apex-defined DTOs for reliable serialization.'
    )
    public static List<Response> invoke(List<Request> requests) {
        Response out = new Response();
        out.storefronts = new List<StorefrontSummary>();
        out.success = false;
        out.message = null;

        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;
        Id accountId = (req == null) ? null : req.accountId;

        try {
            if (accountId == null) {
                out.message = 'accountId is required.';
                out.storefrontsJson = JSON.serialize(out.storefronts);
                return new List<Response>{ out };
            }

            List<Storefront__c> storefronts = [
                SELECT Id, Name, Account__c, Description__c, Cuisine__c, Average_Review_Score__c
                FROM Storefront__c
                WHERE Account__c = :accountId
                ORDER BY Name ASC
                LIMIT 200
            ];

            for (Storefront__c sf : storefronts) {
                StorefrontSummary s = new StorefrontSummary();
                s.id = sf.Id;
                s.name = sf.Name;
                s.accountId = sf.Account__c;
                s.description = sf.Description__c;
                s.cuisine = sf.Cuisine__c;
                s.averageReviewScore = sf.Average_Review_Score__c;
                out.storefronts.add(s);
            }

            out.success = true;
            out.message = 'OK';
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }

        out.storefrontsJson = JSON.serialize(out.storefronts);
        return new List<Response>{ out };
    }
}