/**
 * AgentUpdatePromotionStatusActions
 *
 * Updates the status of an existing promotion (e.g., activate, pause, end).
 * Requires accountId for security validation.
 *
 * Bulk model:
 * This is intentionally a "singleton" action: we only consider requests[0] and return
 * a single Response row.
 */
public with sharing class AgentUpdatePromotionStatusActions {
    public class Request {
        @InvocableVariable(
            label='Account Id'
            description='The Account Id that owns the storefront. Required for security validation.'
            required=true
        )
        public Id accountId;

        @InvocableVariable(
            label='Promotion Id'
            description='The Promotion__c record Id to update.'
            required=true
        )
        public Id promotionId;

        @InvocableVariable(
            label='Status'
            description='New status for the promotion (Promotion__c.Status__c). Common values: Draft, Active, Paused, Ended.'
            required=true
        )
        public String status;
    }

    public class Response {
        @InvocableVariable(
            label='Success'
            description='True when the status update executed successfully.'
        )
        public Boolean success;

        @InvocableVariable(
            label='Message'
            description='User-readable status message. On errors, explains what failed.'
        )
        public String message;

        @InvocableVariable(
            label='Promotion Id'
            description='Echo of the updated Promotion__c Id.'
        )
        public Id promotionId;

        @InvocableVariable(
            label='Promotion Name'
            description='Name of the updated promotion.'
        )
        public String promotionName;

        @InvocableVariable(
            label='Previous Status'
            description='The status before the update.'
        )
        public String previousStatus;

        @InvocableVariable(
            label='New Status'
            description='The new status after the update.'
        )
        public String newStatus;
    }

    @InvocableMethod(
        label='Update Promotion Status'
        description='Updates the status of an existing promotion (e.g., activate, pause, end). Requires accountId for security.'
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
            if (req.promotionId == null) {
                out.message = 'promotionId is required.';
                return new List<Response>{ out };
            }
            if (String.isBlank(req.status)) {
                out.message = 'status is required.';
                return new List<Response>{ out };
            }

            // Fetch promotion and validate ownership through Storefront -> Account
            List<Promotion__c> promotions = [
                SELECT Id, Name, Status__c, Storefront__r.Account__c
                FROM Promotion__c
                WHERE Id = :req.promotionId
                LIMIT 1
            ];

            if (promotions.isEmpty()) {
                out.message = 'No promotion found with the provided Id.';
                return new List<Response>{ out };
            }

            Promotion__c promo = promotions[0];

            // Validate ownership
            if (promo.Storefront__r.Account__c != req.accountId) {
                out.message = 'Access denied. This promotion does not belong to the specified account.';
                return new List<Response>{ out };
            }

            out.previousStatus = promo.Status__c;
            out.promotionId = promo.Id;
            out.promotionName = promo.Name;

            promo.Status__c = req.status;
            update promo;

            out.success = true;
            out.newStatus = req.status;
            out.message = 'Promotion status changed from "' + (out.previousStatus != null ? out.previousStatus : 'not set') + '" to "' + req.status + '".';
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }

        return new List<Response>{ out };
    }
}