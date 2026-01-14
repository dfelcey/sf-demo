/**
 * AgentUpdateMenuItemActions
 *
 * Updates descriptive menu item fields (description, availability, calories, image URL).
 * Explicitly does NOT update price - use AgentUpdateMenuItemPriceActions for that.
 * Requires accountId for security validation.
 *
 * Bulk model:
 * This is intentionally a "singleton" action: we only consider requests[0] and return
 * a single Response row.
 */
public with sharing class AgentUpdateMenuItemActions {
    public class Request {
        @InvocableVariable(
            label='Account Id'
            description='The Account Id that owns the storefront. Required for security validation.'
            required=true
        )
        public Id accountId;

        @InvocableVariable(
            label='Menu Item Id'
            description='The Menu_Item__c record Id to update.'
            required=true
        )
        public Id menuItemId;

        @InvocableVariable(
            label='Description'
            description='New description for the menu item (Menu_Item__c.Description__c). Leave blank to skip.'
            required=false
        )
        public String description;

        @InvocableVariable(
            label='Available'
            description='Set availability status (Menu_Item__c.Available__c). Leave null to skip.'
            required=false
        )
        public Boolean available;

        @InvocableVariable(
            label='Calories'
            description='New calorie count (Menu_Item__c.Calories__c). Leave null to skip.'
            required=false
        )
        public Decimal calories;

        @InvocableVariable(
            label='Image URL'
            description='New image URL (Menu_Item__c.Image_URL__c). Leave blank to skip.'
            required=false
        )
        public String imageUrl;
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
            label='Menu Item Id'
            description='Echo of the updated Menu_Item__c Id.'
        )
        public Id menuItemId;

        @InvocableVariable(
            label='Menu Item Name'
            description='Name of the updated menu item.'
        )
        public String menuItemName;
    }

    @InvocableMethod(
        label='Update Menu Item'
        description='Updates descriptive menu item fields such as description, availability, calories, and image URL. Does NOT update price. Requires accountId for security.'
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
            if (req.menuItemId == null) {
                out.message = 'menuItemId is required.';
                return new List<Response>{ out };
            }

            // Fetch menu item and validate ownership through Menu -> Storefront -> Account
            List<Menu_Item__c> items = [
                SELECT Id, Name, Description__c, Available__c, Calories__c, Image_URL__c,
                       Menu__r.Storefront__r.Account__c
                FROM Menu_Item__c
                WHERE Id = :req.menuItemId
                LIMIT 1
            ];

            if (items.isEmpty()) {
                out.message = 'No menu item found with the provided Id.';
                return new List<Response>{ out };
            }

            Menu_Item__c item = items[0];

            // Validate ownership
            if (item.Menu__r.Storefront__r.Account__c != req.accountId) {
                out.message = 'Access denied. This menu item does not belong to the specified account.';
                return new List<Response>{ out };
            }

            Boolean hasUpdates = false;

            if (req.description != null) {
                item.Description__c = req.description;
                hasUpdates = true;
            }
            if (req.available != null) {
                item.Available__c = req.available;
                hasUpdates = true;
            }
            if (req.calories != null) {
                item.Calories__c = req.calories;
                hasUpdates = true;
            }
            if (req.imageUrl != null) {
                item.Image_URL__c = req.imageUrl;
                hasUpdates = true;
            }

            if (!hasUpdates) {
                out.success = true;
                out.message = 'No fields provided to update.';
                out.menuItemId = item.Id;
                out.menuItemName = item.Name;
                return new List<Response>{ out };
            }

            update item;

            out.success = true;
            out.message = 'Menu item updated successfully.';
            out.menuItemId = item.Id;
            out.menuItemName = item.Name;
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }

        return new List<Response>{ out };
    }
}