/**
 * AgentUpdateMenuItemPriceActions
 *
 * Updates the Price__c field on a menu item.
 * This action respects field-level security and will fail gracefully if the
 * running user lacks access to the Price__c field.
 * Requires accountId for security validation.
 *
 * Bulk model:
 * This is intentionally a "singleton" action: we only consider requests[0] and return
 * a single Response row.
 */
public with sharing class AgentUpdateMenuItemPriceActions {
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
            label='Price'
            description='New price for the menu item (Menu_Item__c.Price__c).'
            required=true
        )
        public Decimal price;
    }

    public class Response {
        @InvocableVariable(
            label='Success'
            description='True when the price update executed successfully.'
        )
        public Boolean success;

        @InvocableVariable(
            label='Message'
            description='User-readable status message. On errors, explains what failed (including permission issues).'
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

        @InvocableVariable(
            label='Previous Price'
            description='The price before the update.'
        )
        public Decimal previousPrice;

        @InvocableVariable(
            label='New Price'
            description='The new price after the update.'
        )
        public Decimal newPrice;
    }

    @InvocableMethod(
        label='Update Menu Item Price'
        description='Updates the Price__c field on a menu item. Respects field-level security. Requires accountId for security.'
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
            if (req.price == null) {
                out.message = 'price is required.';
                return new List<Response>{ out };
            }

            // Check field-level security for Price__c
            Schema.DescribeFieldResult priceField = Menu_Item__c.Price__c.getDescribe();
            if (!priceField.isUpdateable()) {
                out.message = 'You do not have permission to update menu item prices. Please contact your administrator.';
                return new List<Response>{ out };
            }

            // Fetch menu item and validate ownership through Menu -> Storefront -> Account
            List<Menu_Item__c> items = [
                SELECT Id, Name, Price__c, Menu__r.Storefront__r.Account__c
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

            out.previousPrice = item.Price__c;
            out.menuItemId = item.Id;
            out.menuItemName = item.Name;

            item.Price__c = req.price;
            update item;

            out.success = true;
            out.newPrice = req.price;
            out.message = 'Price updated from ' + (out.previousPrice != null ? '$' + out.previousPrice : 'not set') + ' to $' + req.price + '.';
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }

        return new List<Response>{ out };
    }
}