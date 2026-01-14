/**
 * AgentCreatePromotionActions
 *
 * Creates a new promotion or offer for a storefront.
 * Requires accountId for security validation.
 *
 * Bulk model:
 * This is intentionally a "singleton" action: we only consider requests[0] and return
 * a single Response row.
 */
public with sharing class AgentCreatePromotionActions {
    public class Request {
        @InvocableVariable(
            label='Account Id'
            description='The Account Id that owns the storefront. Required for security validation.'
            required=true
        )
        public Id accountId;

        @InvocableVariable(
            label='Storefront Id'
            description='The Storefront__c record Id to associate the promotion with.'
            required=true
        )
        public Id storefrontId;

        @InvocableVariable(
            label='Description'
            description='Description of the promotion (Promotion__c.Description__c).'
            required=true
        )
        public String description;

        @InvocableVariable(
            label='Discount Percentage'
            description='Discount percentage, e.g., 10 for 10% off (Promotion__c.Discount_Percentage__c).'
            required=false
        )
        public Decimal discountPercentage;

        @InvocableVariable(
            label='Start Date'
            description='Promotion start date (Promotion__c.Start_Date__c). Format: YYYY-MM-DD.'
            required=false
        )
        public Date startDate;

        @InvocableVariable(
            label='End Date'
            description='Promotion end date (Promotion__c.End_Date__c). Format: YYYY-MM-DD.'
            required=false
        )
        public Date endDate;

        @InvocableVariable(
            label='Promotion Code'
            description='Optional promo code customers can use (Promotion__c.Promotion_Code__c).'
            required=false
        )
        public String promotionCode;

        @InvocableVariable(
            label='Status'
            description='Initial status (Promotion__c.Status__c). Defaults to "Draft" if not provided.'
            required=false
        )
        public String status;
    }

    public class Response {
        @InvocableVariable(
            label='Success'
            description='True when the promotion was created successfully.'
        )
        public Boolean success;

        @InvocableVariable(
            label='Message'
            description='User-readable status message. On errors, explains what failed.'
        )
        public String message;

        @InvocableVariable(
            label='Promotion Id'
            description='The newly created Promotion__c record Id.'
        )
        public Id promotionId;

        @InvocableVariable(
            label='Promotion Name'
            description='Auto-generated name of the created promotion.'
        )
        public String promotionName;
    }

    @InvocableMethod(
        label='Create Promotion'
        description='Creates a new promotion or offer for a storefront with specified details. Requires accountId for security.'
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
            if (String.isBlank(req.description)) {
                out.message = 'description is required.';
                return new List<Response>{ out };
            }

            // Validate storefront belongs to the provided account
            List<Storefront__c> storefronts = [
                SELECT Id, Account__c
                FROM Storefront__c
                WHERE Id = :req.storefrontId
                LIMIT 1
            ];

            if (storefronts.isEmpty()) {
                out.message = 'No storefront found with the provided Id.';
                return new List<Response>{ out };
            }

            if (storefronts[0].Account__c != req.accountId) {
                out.message = 'Access denied. This storefront does not belong to the specified account.';
                return new List<Response>{ out };
            }

            Promotion__c promo = new Promotion__c();
            promo.Storefront__c = req.storefrontId;
            promo.Description__c = req.description;
            promo.Discount_Percentage__c = req.discountPercentage;
            promo.Start_Date__c = req.startDate;
            promo.End_Date__c = req.endDate;
            promo.Promotion_Code__c = req.promotionCode;
            promo.Status__c = String.isNotBlank(req.status) ? req.status : 'Draft';

            insert promo;

            // Re-query to get the auto-generated Name
            promo = [SELECT Id, Name FROM Promotion__c WHERE Id = :promo.Id LIMIT 1];

            out.success = true;
            out.promotionId = promo.Id;
            out.promotionName = promo.Name;
            out.message = 'Promotion created successfully.';
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }

        return new List<Response>{ out };
    }
}