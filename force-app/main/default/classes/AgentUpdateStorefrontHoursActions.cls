/**
 * AgentUpdateStorefrontHoursActions
 *
 * Updates operating hours for a storefront on a specific day of the week.
 * Requires accountId for security validation.
 *
 * Bulk model:
 * This is intentionally a "singleton" action: we only consider requests[0] and return
 * a single Response row.
 */
public with sharing class AgentUpdateStorefrontHoursActions {
    public class Request {
        @InvocableVariable(
            label='Account Id'
            description='The Account Id that owns the storefront. Required for security validation.'
            required=true
        )
        public Id accountId;

        @InvocableVariable(
            label='Storefront Id'
            description='The Storefront__c record Id whose hours should be updated.'
            required=true
        )
        public Id storefrontId;

        @InvocableVariable(
            label='Day of Week'
            description='The day to update (e.g., Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday).'
            required=true
        )
        public String dayOfWeek;

        @InvocableVariable(
            label='Opening Time'
            description='Opening time in HH:MM format (24-hour), e.g., "09:00".'
            required=false
        )
        public String openingTime;

        @InvocableVariable(
            label='Closing Time'
            description='Closing time in HH:MM format (24-hour), e.g., "21:00".'
            required=false
        )
        public String closingTime;

        @InvocableVariable(
            label='Notes'
            description='Optional notes for this day (e.g., "Closed for lunch 2-3pm").'
            required=false
        )
        public String notes;
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
            label='Hours Record Id'
            description='The Storefront_Hours_of_Operation__c record Id that was updated or created.'
        )
        public Id hoursRecordId;

        @InvocableVariable(
            label='Day of Week'
            description='Echo of the day that was updated.'
        )
        public String dayOfWeek;
    }

    @InvocableMethod(
        label='Update Storefront Hours'
        description='Updates or creates operating hours for a storefront on a specific day of the week. Requires accountId for security.'
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
            if (String.isBlank(req.dayOfWeek)) {
                out.message = 'dayOfWeek is required.';
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

            // Normalize day of week
            String normalizedDay = req.dayOfWeek.trim().toLowerCase();
            normalizedDay = normalizedDay.substring(0, 1).toUpperCase() + normalizedDay.substring(1);

            // Find existing hours record for this storefront + day
            List<Storefront_Hours_of_Operation__c> existingHours = [
                SELECT Id, Day_of_Week__c, Opening_Time__c, Closing_Time__c, Notes__c
                FROM Storefront_Hours_of_Operation__c
                WHERE Storefront__c = :req.storefrontId
                AND Day_of_Week__c = :normalizedDay
                LIMIT 1
            ];

            Storefront_Hours_of_Operation__c hours;
            Boolean isNew = existingHours.isEmpty();

            if (isNew) {
                hours = new Storefront_Hours_of_Operation__c();
                hours.Storefront__c = req.storefrontId;
                hours.Day_of_Week__c = normalizedDay;
            } else {
                hours = existingHours[0];
            }

            // Update fields if provided
            if (req.openingTime != null) {
                hours.Opening_Time__c = req.openingTime;
            }
            if (req.closingTime != null) {
                hours.Closing_Time__c = req.closingTime;
            }
            if (req.notes != null) {
                hours.Notes__c = req.notes;
            }

            if (isNew) {
                insert hours;
                out.message = 'Hours created for ' + normalizedDay + '.';
            } else {
                update hours;
                out.message = 'Hours updated for ' + normalizedDay + '.';
            }

            out.success = true;
            out.hoursRecordId = hours.Id;
            out.dayOfWeek = normalizedDay;
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }

        return new List<Response>{ out };
    }
}