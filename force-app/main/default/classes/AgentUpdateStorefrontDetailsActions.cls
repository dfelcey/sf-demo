/**
 * AgentUpdateStorefrontDetailsActions
 *
 * Updates non-sensitive storefront fields (description, phone, status, overview).
 * Requires accountId for security validation.
 *
 * Bulk model:
 * This is intentionally a "singleton" action: we only consider requests[0] and return
 * a single Response row.
 */
public with sharing class AgentUpdateStorefrontDetailsActions {
    public class Request {
        @InvocableVariable(
            label='Account Id'
            description='The Account Id that owns the storefront. Required for security validation.'
            required=true
        )
        public Id accountId;

        @InvocableVariable(
            label='Storefront Id'
            description='The Storefront__c record Id to update.'
            required=true
        )
        public Id storefrontId;

        @InvocableVariable(
            label='Description'
            description='New description for the storefront (Storefront__c.Description__c). Leave blank to skip.'
            required=false
        )
        public String description;

        @InvocableVariable(
            label='Phone'
            description='New phone number for the storefront (Storefront__c.Phone__c). Leave blank to skip.'
            required=false
        )
        public String phone;

        @InvocableVariable(
            label='Status'
            description='New status for the storefront (Storefront__c.Status__c). Leave blank to skip.'
            required=false
        )
        public String status;

        @InvocableVariable(
            label='Overview'
            description='New overview text for the storefront (Storefront__c.Storefront_Overview__c). Leave blank to skip.'
            required=false
        )
        public String overview;
    }

    public class Response {
        @InvocableVariable(
            label='Success'
            description='True when the update executed successfully.'
        )
        public Boolean success;

        @InvocableVariable(
            label='Message'
            description='User-readable status message. On errors, explains what failed.'
        )
        public String message;

        @InvocableVariable(
            label='Storefront Id'
            description='Echo of the updated Storefront__c Id.'
        )
        public Id storefrontId;

        @InvocableVariable(
            label='Storefront Name'
            description='Name of the updated storefront.'
        )
        public String storefrontName;
    }

    @InvocableMethod(
        label='Update Storefront Details'
        description='Updates non-sensitive storefront fields such as description, phone, status, and overview. Requires accountId for security.'
    )
    public static List<Response> invoke(List<Request> requests) {
        Response out = new Response();
        out.success = false;
        out.message = null;

        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;

        try {
            if (req == null || req.accountId == null) {
                out.message = 'accountId is required.';
                return new List<Response>{ out };
            }
            if (req.storefrontId == null) {
                out.message = 'storefrontId is required.';
                return new List<Response>{ out };
            }

            // Fetch the storefront and validate ownership
            List<Storefront__c> storefronts = [
                SELECT Id, Name, Account__c, Description__c, Phone__c, Status__c, Storefront_Overview__c
                FROM Storefront__c
                WHERE Id = :req.storefrontId
                LIMIT 1
            ];

            if (storefronts.isEmpty()) {
                out.message = 'No storefront found with the provided Id.';
                return new List<Response>{ out };
            }

            Storefront__c sf = storefronts[0];

            // Validate storefront belongs to the provided account
            if (sf.Account__c != req.accountId) {
                out.message = 'Access denied. This storefront does not belong to the specified account.';
                return new List<Response>{ out };
            }

            Boolean hasUpdates = false;

            // Only update fields that were provided
            if (req.description != null) {
                sf.Description__c = req.description;
                hasUpdates = true;
            }
            if (req.phone != null) {
                sf.Phone__c = req.phone;
                hasUpdates = true;
            }
            if (req.status != null) {
                sf.Status__c = req.status;
                hasUpdates = true;
            }
            if (req.overview != null) {
                sf.Storefront_Overview__c = req.overview;
                hasUpdates = true;
            }

            if (!hasUpdates) {
                out.success = true;
                out.message = 'No fields provided to update.';
                out.storefrontId = sf.Id;
                out.storefrontName = sf.Name;
                return new List<Response>{ out };
            }

            update sf;

            out.success = true;
            out.message = 'Storefront updated successfully.';
            out.storefrontId = sf.Id;
            out.storefrontName = sf.Name;
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }

        return new List<Response>{ out };
    }
}